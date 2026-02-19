import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/auth_store.dart';
import '../shared/busy_overlay.dart';
import '../../ui/widgets.dart';

class ManageCheckinDaysPage extends ConsumerStatefulWidget {
  const ManageCheckinDaysPage({super.key});

  @override
  ConsumerState<ManageCheckinDaysPage> createState() =>
      _ManageCheckinDaysPageState();
}

class _ManageCheckinDaysPageState extends ConsumerState<ManageCheckinDaysPage> {
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _selected = DateTime.now();
  bool _loading = false;
  List<Map<String, dynamic>> _days = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final data = await api
          .getJson('/staff-checkin/days', query: {'include_inactive': '1'});
      final list = (data['items'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() => _days = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createOrActivateDay() async {
    final api = ref.read(apiClientProvider);
    await api.postJson('/staff-checkin/days', {
      'checkin_date': DateFormat('yyyy-MM-dd').format(_selected),
      'title': _titleCtrl.text.trim(),
      'note': _noteCtrl.text.trim(),
    });
    await _load();
  }

  Future<void> _toggleDay(Map<String, dynamic> day) async {
    final api = ref.read(apiClientProvider);
    await api.patchJson('/staff-checkin/days/${day['id']}/active', {
      'is_active': !(day['is_active'] == true),
    });
    await _load();
  }

  String _fmtDate(dynamic value) {
    final raw = value?.toString() ?? '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('dd MMM yyyy, EEEE').format(dt);
  }

  Drawer _buildDrawer() {
    final session = ref.read(authControllerProvider);
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
            tile(
              icon: Icons.badge_outlined,
              title: 'Mark Attendance',
              subtitle: 'Open scanner and mark checkin',
              onTap: () {
                Navigator.pop(context);
                context.push('/staff-checkin');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        title: const ClubAppBarTitle(title: 'Manage Staff Checkin Days'),
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
                      Icon(Icons.event_note_outlined,
                          color: Color(0xFFFF9B4A), size: 26),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Schedule Checkin Days',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700)),
                            SizedBox(height: 2),
                            Text(
                                'Enable only event or meeting dates for attendance.'),
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
                      const Text('Create or activate day',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Text(
                          'Selected date: ${DateFormat('dd MMM yyyy, EEEE').format(_selected)}'),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _loading
                            ? null
                            : () async {
                                final pick = await showDatePicker(
                                  context: context,
                                  firstDate: DateTime(2025),
                                  lastDate: DateTime(2035),
                                  initialDate: _selected,
                                );
                                if (pick == null) return;
                                setState(() => _selected = pick);
                              },
                        child: const Text('Choose Date'),
                      ),
                      TextField(
                        controller: _titleCtrl,
                        enabled: !_loading,
                        decoration: const InputDecoration(
                            labelText: 'Title (optional)'),
                      ),
                      TextField(
                        controller: _noteCtrl,
                        enabled: !_loading,
                        decoration:
                            const InputDecoration(labelText: 'Note (optional)'),
                      ),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: _loading ? null : _createOrActivateDay,
                        child: const Text('Save Day'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const SectionHeader(
                    title: 'Configured Days',
                    subtitle: 'Active and inactive attendance days'),
                const SizedBox(height: 8),
                ..._days.map(
                  (d) {
                    final active = d['is_active'] == true;
                    final note = (d['note'] ?? '').toString().trim();
                    return SurfaceCard(
                      child: ListTile(
                        leading: Icon(
                          active ? Icons.check_circle : Icons.cancel,
                          color: active
                              ? const Color(0xFFFF9B4A)
                              : Colors.redAccent,
                        ),
                        title: Text(
                            '${_fmtDate(d['checkin_date'])} · ${d['title'] ?? 'Staff Checkin'}'),
                        subtitle: Text(note.isEmpty
                            ? (active
                                ? 'Day is currently active'
                                : 'Day is currently inactive')
                            : note),
                        trailing: FilledButton.tonal(
                          onPressed: _loading ? null : () => _toggleDay(d),
                          child: Text(active ? 'Disable' : 'Enable'),
                        ),
                      ),
                    );
                  },
                )
              ],
            ),
          ),
          BusyOverlay(busy: _loading, label: 'Please wait...'),
        ],
      ),
    );
  }
}
