import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'models.dart';

const _sessionKey = 'insights_staff_session';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

final authControllerProvider =
    StateNotifierProvider<AuthController, StaffSession?>((ref) {
  final controller = AuthController(ref.read(apiClientProvider));
  controller.bindApiSessionHandlers();
  controller.hydrate();
  return controller;
});

class AuthController extends StateNotifier<StaffSession?> {
  final ApiClient _api;
  bool _isHydrating = false;

  AuthController(this._api) : super(null);

  void bindApiSessionHandlers() {
    _api.setSessionHandlers(
      onSessionToken: _handleRotatedToken,
      onUnauthorized: _handleUnauthorized,
    );
  }

  Future<void> _persistSession(StaffSession session) async {
    final staff = session.staff;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sessionKey,
      jsonEncode({
        'token': session.token,
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

  Future<void> _handleRotatedToken(String token) async {
    final current = state;
    if (current == null || token.isEmpty || current.token == token) return;
    final next = StaffSession(token: token, staff: current.staff);
    state = next;
    await _persistSession(next);
  }

  Future<void> _handleUnauthorized() async {
    if (state == null || _isHydrating) return;
    await logout();
  }

  Future<void> hydrate() async {
    _isHydrating = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionKey);
      if (raw == null || raw.isEmpty) return;

      try {
        final parsed = jsonDecode(raw) as Map<String, dynamic>;
        final staff = StaffUser.fromJson(
            Map<String, dynamic>.from(parsed['staff'] as Map));
        final token = parsed['token']?.toString() ?? '';
        if (token.isEmpty) return;

        // Set token temporarily for validation
        _api.setToken(token);

        // Validate session before restoring state
        try {
          await _api.getJson('/auth/session');
          // Validation succeeded - use the current token from API client (may be rotated)
          final validatedToken = _api.getToken() ?? token;
          state = StaffSession(token: validatedToken, staff: staff);
          // Persist with the validated/rotated token
          if (validatedToken != token) {
            await _persistSession(state!);
          }
        } on DioException catch (e) {
          // Only clear on 401 (expired/invalid token), not on network errors
          if (e.response?.statusCode == 401) {
            _api.setToken(null);
            await prefs.remove(_sessionKey);
          } else {
            // Network error or server error - keep session and try again later
            state = StaffSession(token: token, staff: staff);
          }
        }
      } catch (_) {
        await prefs.remove(_sessionKey);
        _api.setToken(null);
        state = null;
      }
    } finally {
      _isHydrating = false;
    }
  }

  Future<void> refreshSessionOnAppOpen() async {
    if (state == null) return;
    try {
      await _api.getJson('/auth/session');
    } catch (_) {
      // Errors are handled by interceptor or hydrate already
      return;
    }
  }

  Future<void> login(
      {required String username, required String password}) async {
    final data = await _api.postJson('/auth/login', {
      'username': username,
      'password': password,
    });

    final token = data['token']?.toString() ?? '';
    if (token.isEmpty) {
      throw Exception('No token returned');
    }

    final staff =
        StaffUser.fromJson(Map<String, dynamic>.from(data['staff'] as Map));
    _api.setToken(token);
    final session = StaffSession(token: token, staff: staff);
    state = session;
    await _persistSession(session);
  }

  Future<void> logout() async {
    _api.setToken(null);
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}
