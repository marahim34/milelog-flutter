import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/onboarding/permission_onboarding_screen.dart';
import '../../features/tracking/start_trip_sheet.dart';
import '../../features/tracking/tracking_screen.dart';
import '../../features/trips/edit_trip_screen.dart';
import '../../features/trips/trip_detail_screen.dart';
import '../../features/vehicles/add_edit_vehicle_screen.dart';
import '../../features/vehicles/odometer_log_screen.dart';
import '../../features/vehicles/vehicles_screen.dart';
import '../../features/workplaces/add_edit_workplace_screen.dart';
import '../../features/workplaces/workplaces_screen.dart';

class AppRoutes {
  static const permissionOnboarding = '/onboarding/permissions';
  static const login = '/login';
  static const signup = '/signup';
  static const home = '/';
  static const tracking = '/tracking';
  static const tripDetail = '/trips/:id';
  static const tripEdit = '/trips/:id/edit';
  static const reports = '/reports';
  static const vehicles = '/vehicles';
  static const vehicleNew = '/vehicles/new';
  static const vehicleEdit = '/vehicles/:id/edit';
  static const vehicleOdometerLog = '/vehicles/:id/odometer';
  static const workplaces = '/workplaces';
  static const workplaceNew = '/workplaces/new';
  static const workplaceEdit = '/workplaces/:id/edit';
  static const profile = '/profile';
  static const settings = '/settings';

  static String tripDetailPath(int tripId) => '/trips/$tripId';
  static String tripEditPath(int tripId) => '/trips/$tripId/edit';
  static String vehicleEditPath(int vehicleId) => '/vehicles/$vehicleId/edit';
  static String vehicleOdometerLogPath(int vehicleId) =>
      '/vehicles/$vehicleId/odometer';
  static String workplaceEditPath(int workplaceId) =>
      '/workplaces/$workplaceId/edit';
}

/// Tracks login/onboarding state so [AppRouter.router]'s redirect can react
/// to it. Must be assigned (see `main.dart`) before [AppRouter.router] is
/// first accessed, since the redirect/refreshListenable wiring captures it.
class SessionListenable extends ChangeNotifier {
  SessionListenable(this._isLoggedIn, this._onboardingCompleted);

  bool _isLoggedIn;
  bool get isLoggedIn => _isLoggedIn;
  set isLoggedIn(bool value) {
    if (_isLoggedIn == value) return;
    _isLoggedIn = value;
    notifyListeners();
  }

  bool _onboardingCompleted;
  bool get onboardingCompleted => _onboardingCompleted;
  set onboardingCompleted(bool value) {
    if (_onboardingCompleted == value) return;
    _onboardingCompleted = value;
    notifyListeners();
  }
}

class AppRouter {
  AppRouter._();

  static late SessionListenable session;

  static final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: session,
    redirect: (context, state) {
      final onOnboarding =
          state.matchedLocation == AppRoutes.permissionOnboarding;
      // Shown once, before login, regardless of session state — see
      // PermissionOnboardingService. Must stay put (return null) while
      // already there and not yet completed — returning a redirect target
      // here unconditionally is what caused a "/ -> onboarding -> /" loop.
      if (!session.onboardingCompleted) {
        return onOnboarding ? null : AppRoutes.permissionOnboarding;
      }

      final loggedIn = session.isLoggedIn;
      final onAuthPage = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.signup;
      // Onboarding just completed (or an already-logged-in install is
      // upgrading into the first run that has this flag at all) — route to
      // the normal destination for the current session instead of always
      // forcing login.
      if (onOnboarding) return loggedIn ? AppRoutes.home : AppRoutes.login;
      if (!loggedIn && !onAuthPage) return AppRoutes.login;
      if (loggedIn && onAuthPage) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.permissionOnboarding,
        builder: (context, state) => const PermissionOnboardingScreen(),
      ),
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
        builder: (context, state) =>
            TrackingScreen(args: state.extra as TrackingScreenArgs?),
      ),
      GoRoute(
        path: AppRoutes.tripDetail,
        builder: (context, state) {
          final tripId = int.parse(state.pathParameters['id']!);
          return TripDetailScreen(tripId: tripId);
        },
      ),
      GoRoute(
        path: AppRoutes.tripEdit,
        builder: (context, state) {
          final tripId = int.parse(state.pathParameters['id']!);
          return EditTripScreen(tripId: tripId);
        },
      ),
      GoRoute(
        path: AppRoutes.vehicles,
        builder: (context, state) => const VehiclesScreen(),
      ),
      GoRoute(
        path: AppRoutes.vehicleNew,
        builder: (context, state) => const AddEditVehicleScreen(),
      ),
      GoRoute(
        path: AppRoutes.vehicleEdit,
        builder: (context, state) {
          final vehicleId = int.parse(state.pathParameters['id']!);
          return AddEditVehicleScreen(vehicleId: vehicleId);
        },
      ),
      GoRoute(
        path: AppRoutes.vehicleOdometerLog,
        builder: (context, state) {
          final vehicleId = int.parse(state.pathParameters['id']!);
          return OdometerLogScreen(vehicleId: vehicleId);
        },
      ),
      GoRoute(
        path: AppRoutes.workplaces,
        builder: (context, state) => const WorkplacesScreen(),
      ),
      GoRoute(
        path: AppRoutes.workplaceNew,
        builder: (context, state) => const AddEditWorkplaceScreen(),
      ),
      GoRoute(
        path: AppRoutes.workplaceEdit,
        builder: (context, state) {
          final workplaceId = int.parse(state.pathParameters['id']!);
          return AddEditWorkplaceScreen(workplaceId: workplaceId);
        },
      ),
      // Additional feature routes will be added as screens are built.
    ],
  );
}
