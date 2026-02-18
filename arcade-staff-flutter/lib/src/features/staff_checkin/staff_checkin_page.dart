import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../core/auth_store.dart';
import '../shared/busy_overlay.dart';
import '../shared/barcode_scan_dialog.dart';
import '../../ui/widgets.dart';

class StaffCheckinPage extends ConsumerStatefulWidget {
  const StaffCheckinPage({super.key});

  @override
  ConsumerState<StaffCheckinPage> createState() => _StaffCheckinPageState();
}

class _StaffCheckinPageState extends ConsumerState<StaffCheckinPage> {
  final _regNoCtrl = TextEditingController();
  bool _loading = false;

  String _friendlyError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] != null) {
        return data['error'].toString();
      }
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) return message;
      return 'Request failed (${error.response?.statusCode ?? 'unknown'})';
    }
    return error.toString();
  }

  @override
  void dispose() {
    _regNoCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanViaCamera() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => const BarcodeScanDialog(title: 'Scan staff barcode'),
    );
    if (value == null || value.trim().isEmpty) return;
    _regNoCtrl.text = value.trim().toUpperCase();
    await _markCheckin();
  }

  Future<void> _markCheckin() async {
    final regNo = _regNoCtrl.text.trim().toUpperCase();
    if (regNo.isEmpty || _loading) return;
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.postJson('/staff-checkin/scan', {'reg_no': regNo});
      final day = data['day'] as Map<String, dynamic>?;
      final member = data['member'] as Map<String, dynamic>?;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Checked in ${member?['name'] ?? regNo} for ${day?['checkin_date'] ?? 'selected day'}')),
      );
      _regNoCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checkin failed: ${_friendlyError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff Checkin')),
      body: Stack(
        children: [
          AppBackdrop(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeader(
                    title: 'Mark Staff Checkin',
                    subtitle: 'Scan barcode or type registration number',
                  ),
                  const SizedBox(height: 8),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _regNoCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                              labelText: 'Registration number'),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          children: [
                            FilledButton.icon(
                              onPressed: _loading ? null : _markCheckin,
                              icon: const Icon(Icons.check_circle_outline),
                              label: Text(_loading
                                  ? 'Marking...'
                                  : 'Mark Staff Checkin'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _loading ? null : _scanViaCamera,
                              icon: const Icon(Icons.qr_code_scanner),
                              label: const Text('Scan Barcode'),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          BusyOverlay(busy: _loading, label: 'Please wait...'),
        ],
      ),
    );
  }
}
