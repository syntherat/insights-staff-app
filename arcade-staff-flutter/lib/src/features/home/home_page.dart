import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_store.dart';
import '../../ui/widgets.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider);
    final access = session?.staff.access;
    final displayName =
        session?.staff.fullName ?? session?.staff.username ?? 'Staff';

    Widget tile(
        {required String title,
        required String subtitle,
        required VoidCallback onTap,
        required IconData icon}) {
      return SurfaceCard(
        child: ListTile(
          leading: Icon(icon, color: const Color(0xFFFF9B4A)),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights Staff'),
        actions: [
          IconButton(
            onPressed: () => context.push('/profile'),
            icon: const Icon(Icons.person_outline),
          ),
          IconButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
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
                  Text('Welcome, $displayName',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                      'Minimal staff workspace with permanent club checkin and temporary arcade tools.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: const Color(0xFF97A1B2))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SectionHeader(
                title: 'Staff Checkin', subtitle: 'Permanent module'),
            const SizedBox(height: 12),
            tile(
              title: 'Staff Checkin',
              subtitle: 'Permanent: scan club member registration barcode',
              onTap: () => context.push('/staff-checkin'),
              icon: Icons.badge_outlined,
            ),
            if (access?.canManageCheckinDays == true) ...[
              const SizedBox(height: 8),
              tile(
                title: 'Manage Staff Checkin Days',
                subtitle: 'Create/enable only the days you want checkin',
                onTap: () => context.push('/staff-checkin-days'),
                icon: Icons.event_note_outlined,
              ),
            ],
            const SizedBox(height: 24),
            const SectionHeader(
                title: 'Arcade', subtitle: 'Temporary event modules'),
            const SizedBox(height: 12),
            if (access?.canGate == true) ...[
              tile(
                title: 'Arcade Gate',
                subtitle: 'Temporary event module',
                onTap: () => context.push('/arcade/gate'),
                icon: Icons.login_rounded,
              ),
              const SizedBox(height: 8),
            ],
            if (access?.canGame == true) ...[
              tile(
                title: 'Arcade Game',
                subtitle: 'Temporary event module',
                onTap: () => context.push('/arcade/game'),
                icon: Icons.sports_esports_outlined,
              ),
              const SizedBox(height: 8),
            ],
            if (access?.canPrize == true)
              tile(
                title: 'Arcade Prize',
                subtitle: 'Temporary event module',
                onTap: () => context.push('/arcade/prize'),
                icon: Icons.redeem_outlined,
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
