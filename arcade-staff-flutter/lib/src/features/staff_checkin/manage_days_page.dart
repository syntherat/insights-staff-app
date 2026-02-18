import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/auth_store.dart';
import '../shared/busy_overlay.dart';
import '../../ui/widgets.dart';

class ManageCheckinDaysPage extends ConsumerStatefulWidget {
  const ManageCheckinDaysPage({super.key});

  @override
  ConsumerState<ManageCheckinDaysPage> createState() => _ManageCheckinDaysPageState();
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
      final data = await api.getJson('/staff-checkin/days', query: {'include_inactive': '1'});
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Staff Checkin Days')),
      body: Stack(
        children: [
          AppBackdrop(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SectionHeader(
                  title: 'Schedule Checkin Days',
                  subtitle: 'Enable only event or meeting dates',
                ),
                const SizedBox(height: 8),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Create or activate day', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Text('Selected date: ${DateFormat('yyyy-MM-dd').format(_selected)}'),
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
                        decoration: const InputDecoration(labelText: 'Title (optional)'),
                      ),
                      TextField(
                        controller: _noteCtrl,
                        enabled: !_loading,
                        decoration: const InputDecoration(labelText: 'Note (optional)'),
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
                const SectionHeader(title: 'Configured Days'),
                const SizedBox(height: 8),
                ..._days.map(
                  (d) => SurfaceCard(
                    child: ListTile(
                      title: Text('${d['checkin_date']} · ${d['title'] ?? 'Staff Checkin'}'),
                      subtitle: Text((d['note'] ?? '').toString()),
                      trailing: FilledButton.tonal(
                        onPressed: _loading ? null : () => _toggleDay(d),
                        child: Text(d['is_active'] == true ? 'Disable' : 'Enable'),
                      ),
                    ),
                  ),
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
