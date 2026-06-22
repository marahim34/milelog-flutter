import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/services/background_tracking_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait lock and the background tracking service only apply on mobile.
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    await BackgroundTrackingService.initialize();
  }

  runApp(
    const ProviderScope(
      child: MileLogApp(),
    ),
  );
}
