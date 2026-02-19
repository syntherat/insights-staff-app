import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_store.dart';
import '../shared/busy_overlay.dart';
import '../shared/barcode_scan_dialog.dart';
import 'arcade_api.dart';
import '../../ui/widgets.dart';

class ArcadeGatePage extends ConsumerStatefulWidget {
  const ArcadeGatePage({super.key});

  @override
  ConsumerState<ArcadeGatePage> createState() => _ArcadeGatePageState();
}

class _ArcadeGatePageState extends ConsumerState<ArcadeGatePage> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _item;
  List<Map<String, dynamic>> _recent = const [];

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  ArcadeApi get _arcade => ArcadeApi(ref.read(apiClientProvider));

  Future<void> _lookup([String? codeOverride]) async {
    final code = (codeOverride ?? _codeCtrl.text).trim();
    if (code.isEmpty || _loading) return;
    setState(() => _loading = true);
    try {
      final data = await _arcade.walletLookup(code);
      final item = data['item'] as Map<String, dynamic>?;
      final recent = (data['recent'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _item = item == null ? null : Map<String, dynamic>.from(item);
        _recent = recent;
      });
      if (item == null) {
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

  Future<void> _approve() async {
    final regId = _item?['reg_id']?.toString() ?? '';
    if (regId.isEmpty || _loading) return;
    setState(() => _loading = true);
    try {
      await _arcade.approveCheckin(regId);
      await HapticFeedback.mediumImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gate check-in approved')));
      await _lookup();
    } catch (e) {
      await HapticFeedback.vibrate();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Approve failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    final regId = _item?['reg_id']?.toString() ?? '';
    if (regId.isEmpty || _loading) return;
    setState(() => _loading = true);
    try {
      await _arcade.rejectCheckin(regId);
      await HapticFeedback.mediumImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Entry rejected')));
      await _lookup();
    } catch (e) {
      await HapticFeedback.vibrate();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Reject failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirm(
      {required String title,
      required String message,
      String confirmText = 'Confirm'}) async {
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

  Future<void> _confirmApprove() async {
    final name = _item?['name']?.toString() ?? 'this participant';
    final ok = await _confirm(
      title: 'Approve check-in',
      message: 'Approve gate check-in for $name?',
      confirmText: 'Approve',
    );
    if (!ok) return;
    await _approve();
  }

  Future<void> _confirmReject() async {
    final name = _item?['name']?.toString() ?? 'this participant';
    final ok = await _confirm(
      title: 'Reject entry',
      message: 'Reject entry for $name?',
      confirmText: 'Reject',
    );
    if (!ok) return;
    await _reject();
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    return Scaffold(
      appBar: AppBar(
        title: const ClubAppBarTitle(title: 'Arcade Gate'),
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
                    title: 'Gate Check-In', subtitle: 'Temporary event module'),
                const SizedBox(height: 8),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _codeCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Wallet code'),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: _loading ? null : _lookup,
                            icon: const Icon(Icons.search),
                            label: const Text('Lookup'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _loading ? null : _scan,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Scan'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (item != null) ...[
                  const SizedBox(height: 14),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['name']?.toString() ?? '-',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 18)),
                        const SizedBox(height: 8),
                        Text('Reg No: ${item['reg_no'] ?? '-'}'),
                        Text('Wallet: ${item['wallet_code'] ?? '-'}'),
                        Text('Checkin: ${item['checkin_status'] ?? '-'}'),
                        Text('Tokens: ${item['balance'] ?? 0}'),
                        Text('Tickets: ${item['reward_points_balance'] ?? 0}'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          children: [
                            FilledButton.icon(
                              onPressed: _loading ? null : _confirmApprove,
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Approve'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: _loading ? null : _confirmReject,
                              icon: const Icon(Icons.cancel_outlined),
                              label: const Text('Reject'),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ],
                if (_recent.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Recent transactions',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
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
