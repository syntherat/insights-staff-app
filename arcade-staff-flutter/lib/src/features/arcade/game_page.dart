import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_store.dart';
import '../shared/busy_overlay.dart';
import '../shared/barcode_scan_dialog.dart';
import 'arcade_api.dart';
import '../../ui/widgets.dart';

class ArcadeGamePage extends ConsumerStatefulWidget {
  const ArcadeGamePage({super.key});

  @override
  ConsumerState<ArcadeGamePage> createState() => _ArcadeGamePageState();
}

class _ArcadeGamePageState extends ConsumerState<ArcadeGamePage> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;

  List<Map<String, dynamic>> _games = const [];
  String? _gameId;
  List<Map<String, dynamic>> _presets = const [];

  Map<String, dynamic>? _wallet;
  List<Map<String, dynamic>> _recent = const [];

  ArcadeApi get _arcade => ArcadeApi(ref.read(apiClientProvider));

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGames() async {
    setState(() => _loading = true);
    try {
      final games = await _arcade.games();
      String? selected = _gameId;
      if (selected == null && games.isNotEmpty) {
        selected = games.first['id']?.toString();
      }
      setState(() {
        _games = games;
        _gameId = selected;
      });
      if (selected != null) {
        await _loadPresets(selected);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to load games: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPresets(String gameId) async {
    try {
      final presets = await _arcade.gamePresets(gameId);
      if (!mounted) return;
      setState(() => _presets = presets);
    } catch (_) {
      if (!mounted) return;
      setState(() => _presets = const []);
    }
  }

  Future<void> _lookup([String? codeOverride]) async {
    final code = (codeOverride ?? _codeCtrl.text).trim();
    if (code.isEmpty || _loading) return;
    setState(() => _loading = true);
    try {
      final data = await _arcade.walletLookup(code);
      final wallet = data['item'] as Map<String, dynamic>?;
      final recent = (data['recent'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _wallet = wallet == null ? null : Map<String, dynamic>.from(wallet);
        _recent = recent.take(6).toList();
      });
      if (wallet == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Wallet not found')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lookup failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scan() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => const BarcodeScanDialog(title: 'Scan wallet code'),
    );
    if (value == null || value.trim().isEmpty) return;
    _codeCtrl.text = value.trim();
    await _lookup(value);
  }

  Widget _checkinStatusLine(String? status) {
    final raw = (status ?? '-').toString();
    final normalized = raw.toUpperCase();
    Color bgColor;

    if (normalized.contains('CHECKED')) {
      bgColor = const Color(0xFF166534);
    } else if (normalized.contains('REJECT')) {
      bgColor = const Color(0xFF991B1B);
    } else if (normalized.contains('NOT_CHECKED') ||
        normalized.contains('PENDING')) {
      bgColor = const Color(0xFFB45309);
    } else {
      bgColor = const Color(0xFF374151);
    }

    return Row(
      children: [
        const Text('Checkin: '),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            raw.replaceAll('_', ' '),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  List<num> _debitOptions() {
    final game = _games.firstWhere(
      (g) => g['id']?.toString() == _gameId,
      orElse: () => const {},
    );
    final list = (game['allowed_debit_amounts'] as List? ?? const [])
        .map((e) => num.tryParse(e.toString()))
        .whereType<num>()
        .where((n) => n > 0)
        .toSet()
        .toList();

    final def = num.tryParse((game['default_debit_amount'] ?? '').toString());
    if (def != null && def > 0 && !list.contains(def)) list.add(def);
    list.sort();
    return list;
  }

  Future<void> _debit(num amount) async {
    final walletId = _wallet?['wallet_id']?.toString() ?? '';
    final gameId = _gameId ?? '';
    if (walletId.isEmpty || gameId.isEmpty || _loading) return;

    setState(() => _loading = true);
    try {
      await _arcade.debitTokens(
          walletId: walletId, gameId: gameId, amount: amount);
      await HapticFeedback.mediumImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Debited $amount tokens')));
      await _lookup();
    } catch (e) {
      await HapticFeedback.vibrate();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Debit failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reward(Map<String, dynamic> preset) async {
    final walletId = _wallet?['wallet_id']?.toString() ?? '';
    final gameId = _gameId ?? '';
    final amount = num.tryParse((preset['amount'] ?? '').toString());
    if (walletId.isEmpty ||
        gameId.isEmpty ||
        amount == null ||
        amount <= 0 ||
        _loading) {
      return;
    }

    setState(() => _loading = true);
    try {
      await _arcade.rewardTickets(
        walletId: walletId,
        gameId: gameId,
        amount: amount,
        presetId: preset['id']?.toString(),
        reason: preset['label']?.toString() ?? 'REWARD',
      );
      await HapticFeedback.mediumImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Credited $amount tickets')));
      await _lookup();
    } catch (e) {
      await HapticFeedback.vibrate();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Reward failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirm(
      {required String title,
      required String message,
      required String confirmText}) async {
    if (_loading) return false;
    await HapticFeedback.selectionClick();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmText)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _confirmDebit(num amount) async {
    final name = _wallet?['name']?.toString() ?? 'this participant';
    final ok = await _confirm(
      title: 'Confirm debit',
      message: 'Debit $amount tokens from $name?',
      confirmText: 'Debit',
    );
    if (!ok) return;
    await _debit(amount);
  }

  Future<void> _confirmReward(Map<String, dynamic> preset) async {
    final name = _wallet?['name']?.toString() ?? 'this participant';
    final amount = preset['amount']?.toString() ?? '0';
    final label = preset['label']?.toString() ?? 'reward';
    final ok = await _confirm(
      title: 'Confirm reward',
      message: 'Credit $amount tickets ($label) to $name?',
      confirmText: 'Credit',
    );
    if (!ok) return;
    await _reward(preset);
  }

  @override
  Widget build(BuildContext context) {
    final wallet = _wallet;
    final debitOptions = _debitOptions();

    return Scaffold(
      appBar: AppBar(
        title: const ClubAppBarTitle(title: 'Arcade Game'),
        actions: [
          IconButton(
            onPressed: () => context.push('/profile'),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: Stack(
        children: [
          AppBackdrop(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SectionHeader(
                    title: 'Game Counter', subtitle: 'Temporary event module'),
                const SizedBox(height: 8),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _gameId,
                        items: _games
                            .map(
                              (g) => DropdownMenuItem<String>(
                                value: g['id']?.toString(),
                                child: Text(g['name']?.toString() ?? '-'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) async {
                          if (value == null) return;
                          setState(() => _gameId = value);
                          await _loadPresets(value);
                        },
                        decoration:
                            const InputDecoration(labelText: 'Select game'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                          controller: _codeCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Wallet code')),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        children: [
                          FilledButton.icon(
                              onPressed: _loading ? null : _lookup,
                              icon: const Icon(Icons.search),
                              label: const Text('Lookup')),
                          OutlinedButton.icon(
                              onPressed: _loading ? null : _scan,
                              icon: const Icon(Icons.qr_code_scanner),
                              label: const Text('Scan')),
                        ],
                      ),
                    ],
                  ),
                ),
                if (wallet != null) ...[
                  const SizedBox(height: 14),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(wallet['name']?.toString() ?? '-',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text('Wallet: ${wallet['wallet_code'] ?? '-'}'),
                        _checkinStatusLine(
                            wallet['checkin_status']?.toString()),
                        Text('Tokens: ${wallet['balance'] ?? 0}'),
                        Text(
                            'Tickets: ${wallet['reward_points_balance'] ?? 0}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Debit tokens',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: debitOptions
                        .map(
                          (n) => FilledButton.tonal(
                            onPressed: _loading ? null : () => _confirmDebit(n),
                            child: Text('-$n'),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text('Reward tickets presets',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (_presets.isEmpty)
                    const Text('No active presets for this game',
                        style: TextStyle(color: Colors.white70)),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _presets
                        .map(
                          (p) => FilledButton(
                            onPressed:
                                _loading ? null : () => _confirmReward(p),
                            child: Text(
                                '+${p['amount']} ${p['label'] ?? 'TICKETS'}'),
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (_recent.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text('Recent transactions',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  ..._recent.map(
                    (t) => SurfaceCard(
                      child: ListTile(
                        title: Text(
                            '${t['type']} ${t['amount']} ${t['currency'] ?? ''}'),
                        subtitle: Text(
                            '${t['reason'] ?? ''} • ${t['created_at'] ?? ''}'),
                      ),
                    ),
                  )
                ]
              ],
            ),
          ),
          BusyOverlay(busy: _loading, label: 'Please wait...'),
        ],
      ),
    );
  }
}
