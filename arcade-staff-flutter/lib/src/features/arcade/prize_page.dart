import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_store.dart';
import '../shared/busy_overlay.dart';
import '../shared/barcode_scan_dialog.dart';
import 'arcade_api.dart';
import '../../ui/widgets.dart';

class ArcadePrizePage extends ConsumerStatefulWidget {
  const ArcadePrizePage({super.key});

  @override
  ConsumerState<ArcadePrizePage> createState() => _ArcadePrizePageState();
}

class _ArcadePrizePageState extends ConsumerState<ArcadePrizePage> {
  final _codeCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool _loading = false;
  Map<String, dynamic>? _wallet;
  List<Map<String, dynamic>> _recent = const [];

  ArcadeApi get _arcade => ArcadeApi(ref.read(apiClientProvider));

  @override
  void dispose() {
    _codeCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
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

  Future<void> _redeem() async {
    final walletId = _wallet?['wallet_id']?.toString() ?? '';
    final amount = num.tryParse(_amountCtrl.text.trim());
    if (walletId.isEmpty || amount == null || amount <= 0 || _loading) return;

    setState(() => _loading = true);
    try {
      await _arcade.prizeRedeem(
        walletId: walletId,
        amount: amount,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      await HapticFeedback.mediumImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Redeemed $amount tickets')));
      _amountCtrl.clear();
      _noteCtrl.clear();
      await _lookup();
    } catch (e) {
      await HapticFeedback.vibrate();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Redeem failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirmRedeem(num amount) async {
    if (_loading) return false;
    await HapticFeedback.selectionClick();
    final name = _wallet?['name']?.toString() ?? 'this participant';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm redemption'),
        content: Text('Redeem $amount tickets from $name?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Redeem')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _confirmAndRedeem() async {
    final amount = num.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    final ok = await _confirmRedeem(amount);
    if (!ok) return;
    await _redeem();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = _wallet;

    return Scaffold(
      appBar: AppBar(
        title: const ClubAppBarTitle(title: 'Arcade Prize'),
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
                    title: 'Prize Redemption',
                    subtitle: 'Temporary event module'),
                const SizedBox(height: 8),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                                fontWeight: FontWeight.w700, fontSize: 18)),
                        const SizedBox(height: 8),
                        Text('Wallet: ${wallet['wallet_code'] ?? '-'}'),
                        _checkinStatusLine(
                            wallet['checkin_status']?.toString()),
                        Text(
                            'Tickets: ${wallet['reward_points_balance'] ?? 0}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Tickets to redeem'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Note (optional)'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _loading ? null : _confirmAndRedeem,
                    icon: const Icon(Icons.redeem_outlined),
                    label: Text(_loading ? 'Redeeming...' : 'Redeem Prize'),
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
