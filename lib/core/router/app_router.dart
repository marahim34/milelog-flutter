import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/tracking/tracking_screen.dart';
import '../../features/trips/trip_detail_screen.dart';
import '../../features/vehicles/add_edit_vehicle_screen.dart';
import '../../features/vehicles/vehicles_screen.dart';
import '../../features/workplaces/add_edit_workplace_screen.dart';
import '../../features/workplaces/workplaces_screen.dart';

class AppRoutes {
  static const login = '/login';
  static const signup = '/signup';
  static const home = '/';
  static const tracking = '/tracking';
  static const tripDetail = '/trips/:id';
  static const reports = '/reports';
  static const vehicles = '/vehicles';
  static const vehicleNew = '/vehicles/new';
  static const vehicleEdit = '/vehicles/:id/edit';
  static const workplaces = '/workplaces';
  static const workplaceNew = '/workplaces/new';
  static const workplaceEdit = '/workplaces/:id/edit';
  static const profile = '/profile';
  static const settings = '/settings';

  static String tripDetailPath(int tripId) => '/trips/$tripId';
  static String vehicleEditPath(int vehicleId) => '/vehicles/$vehicleId/edit';
  static String workplaceEditPath(int workplaceId) =>
      '/workplaces/$workplaceId/edit';
}

/// Tracks login state so [AppRouter.router]'s redirect can react to it.
/// Must be assigned (see `main.dart`) before [AppRouter.router] is first
/// accessed, since the redirect/refreshListenable wiring captures it.
class SessionListenable extends ChangeNotifier {
  SessionListenable(this._isLoggedIn);

  bool _isLoggedIn;
  bool get isLoggedIn => _isLoggedIn;
  set isLoggedIn(bool value) {
    if (_isLoggedIn == value) return;
    _isLoggedIn = value;
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
      final loggedIn = session.isLoggedIn;
      final onAuthPage = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.signup;
      if (!loggedIn && !onAuthPage) return AppRoutes.login;
      if (loggedIn && onAuthPage) return AppRoutes.home;
      return null;
    },
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
      GoRoute(
        path: AppRoutes.tripDetail,
        builder: (context, state) {
          final tripId = int.parse(state.pathParameters['id']!);
          return TripDetailScreen(tripId: tripId);
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
