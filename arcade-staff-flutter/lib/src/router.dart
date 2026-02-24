import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/auth_store.dart';
import 'features/auth/login_page.dart';
import 'features/home/home_page.dart';
import 'features/staff_checkin/staff_checkin_page.dart';
import 'features/staff_checkin/manage_days_page.dart';
import 'features/profile/profile_page.dart';
import 'features/arcade/gate_page.dart';
import 'features/arcade/game_page.dart';
import 'features/arcade/prize_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final loggedIn = auth != null;
      final isLoginPath = state.matchedLocation == '/login';

      if (!loggedIn && !isLoginPath) return '/login';
      if (loggedIn && isLoginPath) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
      GoRoute(
          path: '/staff-checkin',
          builder: (context, state) => const StaffCheckinPage()),
      GoRoute(
          path: '/staff-checkin-days',
          builder: (context, state) => const ManageCheckinDaysPage()),
      GoRoute(
          path: '/profile', builder: (context, state) => const ProfilePage()),
      GoRoute(
          path: '/arcade/gate',
          builder: (context, state) => const ArcadeGatePage()),
      GoRoute(
          path: '/arcade/game',
          builder: (context, state) => const ArcadeGamePage()),
      GoRoute(
          path: '/arcade/prize',
          builder: (context, state) => const ArcadePrizePage()),
    ],
  );
});
