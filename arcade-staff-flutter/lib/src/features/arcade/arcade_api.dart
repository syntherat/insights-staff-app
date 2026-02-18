import '../../core/api_client.dart';

String actionId() => 'staff_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';

class ArcadeApi {
  const ArcadeApi(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> walletLookup(String code) {
    return _api.getJson('/wallets/lookup', query: {'code': code});
  }

  Future<List<Map<String, dynamic>>> games() async {
    final data = await _api.getJson('/games');
    final list = (data['items'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return list;
  }

  Future<List<Map<String, dynamic>>> gamePresets(String gameId) async {
    final data = await _api.getJson('/games/$gameId/presets');
    final list = (data['items'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return list;
  }

  Future<void> approveCheckin(String regId) async {
    await _api.postJson('/checkin/approve', {'reg_id': regId});
  }

  Future<void> rejectCheckin(String regId, {String reason = ''}) async {
    await _api.postJson('/checkin/reject', {'reg_id': regId, 'reason': reason});
  }

  Future<void> debitTokens({
    required String walletId,
    required String gameId,
    required num amount,
    String reason = 'PLAY',
  }) async {
    await _api.postJson('/txns/debit', {
      'wallet_id': walletId,
      'game_id': gameId,
      'amount': amount,
      'reason': reason,
      'action_id': actionId(),
    });
  }

  Future<void> rewardTickets({
    required String walletId,
    required String gameId,
    required num amount,
    String reason = 'REWARD',
    String? presetId,
  }) async {
    await _api.postJson('/txns/reward', {
      'wallet_id': walletId,
      'game_id': gameId,
      'preset_id': presetId,
      'amount': amount,
      'reason': reason,
      'action_id': actionId(),
    });
  }

  Future<void> prizeRedeem({
    required String walletId,
    required num amount,
    String reason = 'PRIZE_REDEMPTION',
    String? note,
  }) async {
    await _api.postJson('/txns/prize-redeem', {
      'wallet_id': walletId,
      'amount': amount,
      'reason': reason,
      'note': note,
      'action_id': actionId(),
    });
  }
}
