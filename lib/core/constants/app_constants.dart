class AppConstants {
  AppConstants._();

  // ── Database ────────────────────────────────────────────────────────────
  static const String dbName = 'milelog';
  static const int dbVersion = 1;

  // ── GPS tracking ────────────────────────────────────────────────────────
  static const int locationIntervalMs = 5000;
  static const int locationFastestIntervalMs = 3000;
  // Minimum movement before a new point is recorded (filters GPS jitter).
  static const double locationMinDistanceM = 5.0;
  static const double locationAccuracyThresholdM = 50.0;

  // Idle detection — mirrors original Android 1h warn + 5m auto-stop.
  static const int idleWarningMinutes = 60;
  static const int idleAutoStopMinutes = 5;
  static const int gpsLossWarningSeconds = 30;

  // ── Reporting ───────────────────────────────────────────────────────────
  static const int tripsPageSize = 50;
  static const int reportTopCompanies = 4;
  static const int heatmapCells = 35;

  // ── Notifications ───────────────────────────────────────────────────────
  static const int trackingNotificationId = 1001;
  static const int idleWarningNotificationId = 1002;
  static const int gpsLossNotificationId = 1003;

  // ── Mileage defaults ───────────────────────────────────────────────────
  static const double defaultMileageRate = 0.55;
  static const String defaultCurrencySymbol = '€';

  // ── Backup / sync ───────────────────────────────────────────────────────
  static const int firestoreBatchSize = 450;
  static const String backupDirName = 'Backups';
}
