import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/auth_store.dart';
import '../../ui/widgets.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  List<_AttendanceDayView> _attendance = const [];
  bool _loadingAttendance = false;
  Timer? _attendanceRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
    _attendanceRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _loadAttendance(),
    );
  }

  @override
  void dispose() {
    _attendanceRefreshTimer?.cancel();
    super.dispose();
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String _fmtDay(DateTime date) {
    return DateFormat('dd MMM yyyy, EEEE').format(date);
  }

  String _fmtDateTime(DateTime date) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(date.toLocal());
  }

  Future<void> _loadAttendance() async {
    setState(() => _loadingAttendance = true);
    try {
      final api = ref.read(apiClientProvider);
      final daysData = await api
          .getJson('/staff-checkin/days', query: {'include_inactive': '1'});
      final myData = await api.getJson('/staff-checkin/my');

      final days = (daysData['items'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final myItems = (myData['items'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final checkedByDate = <String, DateTime>{};
      for (final row in myItems) {
        final dateKey = (row['checkin_date'] ?? '').toString();
        final checkedAt = _parseDate(row['checked_in_at']);
        if (dateKey.isEmpty || checkedAt == null) continue;
        final existing = checkedByDate[dateKey];
        if (existing == null || checkedAt.isAfter(existing)) {
          checkedByDate[dateKey] = checkedAt;
        }
      }

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final built = <_AttendanceDayView>[];

      for (final day in days) {
        final dateKey = (day['checkin_date'] ?? '').toString();
        final parsedDay = _parseDate(dateKey);
        if (dateKey.isEmpty || parsedDay == null) continue;

        final checkedAt = checkedByDate[dateKey];
        final dayStart =
            DateTime(parsedDay.year, parsedDay.month, parsedDay.day);

        late final String status;
        late final Color tone;
        late final String details;

        if (checkedAt != null) {
          status = 'Present';
          tone = const Color.fromARGB(255, 7, 196, 0);
          details = 'Marked at ${_fmtDateTime(checkedAt)}';
        } else if (dayStart.isBefore(todayStart)) {
          status = 'Absent';
          tone = Colors.redAccent;
          details = 'No check-in was recorded for this day';
        } else {
          status = 'Pending';
          tone = const Color(0xFFEAB676);
          details = 'Attendance status will update after this day ends';
        }

        built.add(
          _AttendanceDayView(
            date: parsedDay,
            title: (day['title'] ?? 'Staff Checkin').toString(),
            note: (day['note'] ?? '').toString(),
            status: status,
            details: details,
            tone: tone,
          ),
        );
      }

      built.sort((a, b) => b.date.compareTo(a.date));
      if (!mounted) return;
      setState(() => _attendance = built.take(5).toList());
    } finally {
      if (mounted) setState(() => _loadingAttendance = false);
    }
  }

  Widget _menuTile({
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

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);
    final access = session?.staff.access;
    final displayName =
        session?.staff.fullName ?? session?.staff.username ?? 'Staff';

    return Scaffold(
      drawer: Drawer(
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
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('Hello, $displayName',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              _menuTile(
                icon: Icons.home_outlined,
                title: 'Home',
                subtitle: 'Overview and attendance',
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              if (access?.canManageCheckinDays == true) ...[
                _menuTile(
                  icon: Icons.badge_outlined,
                  title: 'Mark Attendance',
                  subtitle: 'Mark staff checkin manually or by scan',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/staff-checkin');
                  },
                ),
                _menuTile(
                  icon: Icons.event_note_outlined,
                  title: 'Manage Checkin Days',
                  subtitle: 'Configure attendance dates',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/staff-checkin-days');
                  },
                ),
              ],
              if (access?.canGate == true)
                _menuTile(
                  icon: Icons.login_rounded,
                  title: 'VRCADE Gate',
                  subtitle: 'Checkin Participants',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/arcade/gate');
                  },
                ),
              if (access?.canGame == true)
                _menuTile(
                  icon: Icons.sports_esports_outlined,
                  title: 'VRCADE Games',
                  subtitle: 'Manage games',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/arcade/game');
                  },
                ),
              if (access?.canPrize == true)
                _menuTile(
                  icon: Icons.redeem_outlined,
                  title: 'VRCADE Prize',
                  subtitle: 'Prize Redeem Counter',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/arcade/prize');
                  },
                ),
              const Divider(height: 22),
              _menuTile(
                icon: Icons.logout,
                title: 'Logout',
                subtitle: 'Sign out',
                onTap: () async {
                  Navigator.pop(context);
                  await ref.read(authControllerProvider.notifier).logout();
                },
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: const ClubAppBarTitle(title: 'Insights Club Staff'),
        actions: [
          IconButton(
            onPressed: () => context.push('/profile'),
            icon: const Icon(Icons.person_outline),
          ),
          IconButton(
            onPressed: _loadingAttendance ? null : _loadAttendance,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: AppBackdrop(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: const Color(0x22FF7A1A),
                        ),
                        child: const Icon(Icons.waving_hand_rounded,
                            color: Color(0xFFFF9B4A)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Welcome, $displayName',
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 3),
                            Text(
                              'Insights Club Staff dashboard',
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
                ],
              ),
            ),
            if (access?.canManageCheckinDays == true) ...[
              const SizedBox(height: 12),
              SurfaceCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Attendance Marking',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            'Open attendance scanner to mark staff present for selected checkin day.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: const Color(0xFF97A1B2)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: () => context.push('/staff-checkin'),
                      icon: const Icon(Icons.badge_outlined),
                      label: const Text('Mark'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const SectionHeader(
                title: 'Your Attendance Status',
                subtitle: 'Latest 5 attendance logs'),
            const SizedBox(height: 12),
            if (_loadingAttendance)
              const SurfaceCard(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_attendance.isEmpty)
              const SurfaceCard(
                child: ListTile(
                  title: Text('No attendance days available yet'),
                ),
              )
            else
              ..._attendance.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SurfaceCard(
                    child: ListTile(
                      leading: Icon(
                        item.status == 'Present'
                            ? Icons.check_circle
                            : item.status == 'Absent'
                                ? Icons.cancel
                                : Icons.schedule,
                        color: item.tone,
                      ),
                      title: Text('${_fmtDay(item.date)} • ${item.title}'),
                      subtitle: Text(item.note.isEmpty
                          ? item.details
                          : '${item.note}\n${item.details}'),
                      isThreeLine: item.note.isNotEmpty,
                      trailing: Text(
                        item.status,
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: item.tone),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _AttendanceDayView {
  final DateTime date;
  final String title;
  final String note;
  final String status;
  final String details;
  final Color tone;

  const _AttendanceDayView({
    required this.date,
    required this.title,
    required this.note,
    required this.status,
    required this.details,
    required this.tone,
  });
}
