import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      appBar: AppBar(title: const Text('My Profile')),
      body: AppBackdrop(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SurfaceCard(
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0x22FF7A1A),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.person_outline,
                        color: Color(0xFFFF9B4A)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s?.fullName ?? s?.username ?? '-',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                            'Role: ${s?.role ?? '-'} • Reg No: ${s?.access.staffRegNo ?? '-'}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: const Color(0xFF97A1B2))),
                        Text('Email: ${s?.email ?? '-'}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: const Color(0xFF97A1B2))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const SectionHeader(title: 'My Staff Checkin History'),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CircularProgressIndicator()),
              ),
            ..._myCheckins.map(
              (it) => SurfaceCard(
                child: ListTile(
                  title: Text(
                      '${it['staff_name'] ?? s?.fullName ?? s?.username ?? '-'} · ${it['checkin_date']}'),
                  subtitle: Text(
                      '${it['title'] ?? 'Staff Checkin'} • Marked at ${it['checked_in_at']}'),
                ),
              ),
            ),
            if (!_loading && _myCheckins.isEmpty)
              const SurfaceCard(
                  child: ListTile(title: Text('No checkin records yet'))),
          ],
        ),
      ),
    );
  }
}
