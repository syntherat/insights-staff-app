import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'models.dart';

const _sessionKey = 'insights_staff_session';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

final authControllerProvider = StateNotifierProvider<AuthController, StaffSession?>((ref) {
  final controller = AuthController(ref.read(apiClientProvider));
  controller.hydrate();
  return controller;
});

class AuthController extends StateNotifier<StaffSession?> {
  final ApiClient _api;

  AuthController(this._api) : super(null);

  Future<void> hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.isEmpty) return;

    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    final staff = StaffUser.fromJson(Map<String, dynamic>.from(parsed['staff'] as Map));
    final token = parsed['token']?.toString() ?? '';
    if (token.isEmpty) return;

    _api.setToken(token);
    state = StaffSession(token: token, staff: staff);
  }

  Future<void> login({required String username, required String password}) async {
    final data = await _api.postJson('/auth/login', {
      'username': username,
      'password': password,
    });

    final token = data['token']?.toString() ?? '';
    if (token.isEmpty) {
      throw Exception('No token returned');
    }

    final staff = StaffUser.fromJson(Map<String, dynamic>.from(data['staff'] as Map));
    _api.setToken(token);
    state = StaffSession(token: token, staff: staff);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sessionKey,
      jsonEncode({
        'token': token,
        'staff': {
          'id': staff.id,
          'username': staff.username,
          'role': staff.role,
          'full_name': staff.fullName,
          'email': staff.email,
          'access': {
            'staff_reg_no': staff.access.staffRegNo,
            'can_gate': staff.access.canGate,
            'can_game': staff.access.canGame,
            'can_prize': staff.access.canPrize,
            'can_staff_checkin': staff.access.canStaffCheckin,
            'can_manage_checkin_days': staff.access.canManageCheckinDays,
          },
        }
      }),
    );
  }

  Future<void> logout() async {
    _api.setToken(null);
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}
