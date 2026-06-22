import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/tracking/tracking_screen.dart';

class AppRoutes {
  static const login = '/login';
  static const signup = '/signup';
  static const home = '/';
  static const tracking = '/tracking';
  static const tripDetail = '/trips/:id';
  static const reports = '/reports';
  static const vehicles = '/vehicles';
  static const workplaces = '/workplaces';
  static const profile = '/profile';
  static const settings = '/settings';
}

class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    initialLocation: AppRoutes.login,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.tracking,
        builder: (context, state) => const TrackingScreen(),
      ),
      // Additional feature routes will be added as screens are built.
    ],
    // TODO: add redirect guard once auth state provider is in place.
  );
}
