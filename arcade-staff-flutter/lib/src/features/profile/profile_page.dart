import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/auth_store.dart';
import '../../ui/widgets.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  List<Map<String, dynamic>> _myCheckins = const [];
  bool _loading = false;

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String _fmtDate(DateTime value) {
    return DateFormat('dd MMM yyyy').format(value);
  }

  String _fmtDateTime(DateTime value) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(value.toLocal());
  }

  bool _isTruthy(dynamic value) {
    if (value == true) return true;
    if (value == null) return false;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      return v == 'true' || v == 't' || v == '1' || v == 'yes';
    }
    return false;
  }

  Widget _statusPill(bool isPresent) {
    final bg = isPresent ? const Color(0xFF166534) : const Color(0xFF991B1B);
    final label = isPresent ? 'Present' : 'Absent';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.getJson('/staff-checkin/my');
      final items = (data['items'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() => _myCheckins = items);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);
    final s = session?.staff;

    return Scaffold(
      appBar: AppBar(title: const ClubAppBarTitle(title: 'My Profile')),
      body: AppBackdrop(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: const Color(0x22FF7A1A),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.person_outline,
                            color: Color(0xFFFF9B4A), size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s?.fullName ?? s?.username ?? '-',
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 3),
                            Text(
                              s?.email ?? '-',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: const Color(0xFF97A1B2)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.badge_outlined,
                            size: 18, color: Color(0xFFFF9B4A)),
                        label: Text('Role: ${s?.role ?? '-'}'),
                      ),
                      Chip(
                        avatar: const Icon(Icons.confirmation_num_outlined,
                            size: 18, color: Color(0xFFFF9B4A)),
                        label: Text('Reg No: ${s?.access.staffRegNo ?? '-'}'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const SectionHeader(
                title: 'My Staff Checkin History',
                subtitle: 'Recent attendance records'),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CircularProgressIndicator()),
              ),
            ..._myCheckins.map(
              (it) {
                final checkinDate = _parseDate(it['checkin_date']);
                final checkedAt = _parseDate(it['checked_in_at']);
                final isPresent =
                    checkedAt != null || _isTruthy(it['is_present']);
                final dayText = checkinDate == null
                    ? '${it['checkin_date'] ?? '-'}'
                    : _fmtDate(checkinDate);
                final markText = checkedAt == null
                    ? '${it['checked_in_at'] ?? '-'}'
                    : _fmtDateTime(checkedAt);

                return SurfaceCard(
                  child: ListTile(
                    leading: Icon(
                      isPresent ? Icons.check_circle : Icons.cancel,
                      color: isPresent
                          ? const Color.fromARGB(255, 0, 184, 46)
                          : const Color(0xFFEF4444),
                    ),
                    title: Text('${it['title'] ?? 'Staff Checkin'} • $dayText'),
                    subtitle: Text(
                      isPresent ? 'Marked at $markText' : 'Not marked',
                    ),
                    trailing: _statusPill(isPresent),
                  ),
                );
              },
            ),
            if (!_loading && _myCheckins.isEmpty)
              const SurfaceCard(
                child: ListTile(
                  title: Text('No checkin records yet'),
                  subtitle: Text(
                      'Your attendance entries will appear here once marked.'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
