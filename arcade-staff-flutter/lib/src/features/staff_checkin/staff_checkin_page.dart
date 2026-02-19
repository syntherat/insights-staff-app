import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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

  String _fmtDate(dynamic value) {
    final raw = value?.toString() ?? '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('dd MMM yyyy').format(dt);
  }

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
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const BarcodeScanDialog(title: 'Scan attendance code'),
      ),
    );
    if (!mounted) return;
    if (value == null || value.trim().isEmpty) return;
    setState(() {
      _regNoCtrl.text = value.trim().toUpperCase();
    });
    await _markCheckin();
  }

  Drawer _buildDrawer() {
    final session = ref.read(authControllerProvider);
    final access = session?.staff.access;
    final displayName =
        session?.staff.fullName ?? session?.staff.username ?? 'Staff';

    Widget tile({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) {
      return ListTile(
        leading: Icon(icon, color: const Color(0xFFFF9B4A)),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: onTap,
      );
    }

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0x1FFF7A1A),
                border: Border.all(color: const Color(0x33FF9B4A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Insights Club',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Hello, $displayName'),
                ],
              ),
            ),
            tile(
              icon: Icons.home_outlined,
              title: 'Home',
              subtitle: 'Dashboard and attendance',
              onTap: () {
                Navigator.pop(context);
                context.go('/home');
              },
            ),
            if (access?.canManageCheckinDays == true)
              tile(
                icon: Icons.event_note_outlined,
                title: 'Manage Checkin Days',
                subtitle: 'Configure attendance dates',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/staff-checkin-days');
                },
              ),
          ],
        ),
      ),
    );
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
                'Checked in ${member?['name'] ?? regNo} for ${_fmtDate(day?['checkin_date'])}')),
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
      drawer: _buildDrawer(),
      appBar: AppBar(
        title: const ClubAppBarTitle(title: 'Staff Checkin'),
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
                const SurfaceCard(
                  child: Row(
                    children: [
                      Icon(Icons.badge_outlined,
                          color: Color(0xFFFF9B4A), size: 26),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mark Staff Checkin',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700)),
                            SizedBox(height: 2),
                            Text(
                                'Scan barcode or enter registration number manually.'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _regNoCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Registration number',
                          prefixIcon: Icon(Icons.confirmation_num_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _loading ? null : _markCheckin,
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(
                            _loading ? 'Marking...' : 'Mark Staff Checkin'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _scanViaCamera,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Open Full Screen Scanner'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          BusyOverlay(busy: _loading, label: 'Please wait...'),
        ],
      ),
    );
  }
}
