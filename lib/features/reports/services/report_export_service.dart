import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/trip_type.dart';

class ReportExportService {
  static const _downloadChannel =
      MethodChannel('com.aisora.goodo/downloads');

  Future<({Uint8List bytes, String filename})> generatePdf({
    required List<Trip> trips,
    required String periodLabel,
    String reportTitle = 'ALL TRIPS',
    String currency = AppConstants.defaultCurrencyCode,
    String filterType = 'all',
    Map<int, List<TripWaypoint>> waypoints = const {},
    Map<int, List<LocationPoint>> locationPoints = const {},
    String profileName = '',
    String profileAddress = '',
    String profilePhone = '',
    String profileEmail = '',
  }) async {
    final bytes = await _buildPdfBytes(
      trips: trips,
      periodLabel: periodLabel,
      reportTitle: reportTitle,
      currency: currency,
      filterType: filterType,
      waypoints: waypoints,
      locationPoints: locationPoints,
      profileName: profileName,
      profileAddress: profileAddress,
      profilePhone: profilePhone,
      profileEmail: profileEmail,
    );
    final filename = 'GoOdo_Report_${_timestamp()}.pdf';
    return (bytes: bytes, filename: filename);
  }

  Future<({List<int> bytes, String filename})> generateCsv({
    required List<Trip> trips,
  }) async {
    final bytes = _buildCsvBytes(trips);
    final filename = 'GoOdo_Export_${_timestamp()}.csv';
    return (bytes: bytes, filename: filename);
  }

  Future<void> shareFile(String filename, List<int> bytes) async {
    final tempDir = await getTemporaryDirectory();
    if (!tempDir.existsSync()) await tempDir.create(recursive: true);
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)], subject: filename);
  }

  Future<bool> downloadToDevice(String filename, List<int> bytes) async {
    try {
      await _downloadChannel.invokeMethod<String>('saveToDownloads', {
        'filename': filename,
        'bytes': Uint8List.fromList(bytes),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── PDF colour palette ───────────────────────────────────────────────
  static const _rose = PdfColor.fromInt(0xFFDA1D69);
  static const _nearBlack = PdfColor.fromInt(0xFF1A1A1A);
  static const _darkGrey = PdfColor.fromInt(0xFF424242);
  static const _midGrey = PdfColor.fromInt(0xFF9E9E9E);
  static const _lightGrey = PdfColor.fromInt(0xFFF7F7F7);
  static const _borderLight = PdfColor.fromInt(0xFFE0E0E0);
  static const _mapBg = PdfColor.fromInt(0xFFF5F5F5);
  static const _routeColour = PdfColor.fromInt(0xFFDA1D69);
  Future<Uint8List> _buildPdfBytes({
    required List<Trip> trips,
    required String periodLabel,
    required String currency,
    required Map<int, List<TripWaypoint>> waypoints,
    Map<int, List<LocationPoint>> locationPoints = const {},
    String reportTitle = 'ALL TRIPS',
    String filterType = 'all',
    String profileName = '',
    String profileAddress = '',
    String profilePhone = '',
    String profileEmail = '',
  }) async {
    final doc = pw.Document();

    final totalDist = trips.fold<double>(0, (s, t) => s + t.distanceKm);
    final totalCost =
        trips.fold<double>(0, (s, t) => s + t.distanceKm * t.mileageRate);

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 32),
      buildBackground: (ctx) => pw.FullPage(
        ignoreMargins: true,
        child: pw.Center(
          child: pw.Transform.rotate(
            angle: -math.pi / 4,
            child: pw.Text(
              'GoOdo',
              style: pw.TextStyle(
                fontSize: 72,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor(0.855, 0.114, 0.412, 0.01),
              ),
            ),
          ),
        ),
      ),
    );

    // ── Shared header / footer / background ────────────────────────────
    pw.Widget pageHeader(pw.Context ctx) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.CustomPaint(
                      size: const PdfPoint(14, 14),
                      painter: _pdfSpeedometerIcon,
                    ),
                    pw.SizedBox(width: 5),
                    pw.Text(
                      'GoOdo',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: _rose,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 7, color: _midGrey),
                ),
              ],
            ),
            pw.SizedBox(height: 7),
            pw.Container(height: 0.5, color: _borderLight),
            pw.SizedBox(height: 12),
          ],
        );

    pw.Widget pageFooter(pw.Context ctx) => pw.Column(
          children: [
            pw.Container(height: 0.5, color: _borderLight),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'Generated by GoOdo - '
                  '${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 7, color: _midGrey),
                ),
              ],
            ),
          ],
        );

    // ── Build widgets ──────────────────────────────────────────────────
    final summaryWidgets =
        _buildSummary(trips, totalDist, totalCost, currency, periodLabel,
            reportTitle, filterType, profileName, profileAddress, profilePhone, profileEmail);

    final detailWidgets = <pw.Widget>[];
    for (final trip in trips) {
      detailWidgets.add(pw.NewPage());
      detailWidgets.addAll(_buildTripDetail(
        trip,
        currency,
        waypoints[trip.id] ?? const [],
        locationPoints[trip.id] ?? const [],
      ));
    }

    doc.addPage(pw.MultiPage(
      pageTheme: pageTheme,
      header: pageHeader,
      footer: pageFooter,
      build: (ctx) => [...summaryWidgets, ...detailWidgets],
    ));

    return doc.save();
  }

  // ── Summary page content ───────────────────────────────────────────────
  List<pw.Widget> _buildSummary(
    List<Trip> trips,
    double totalDist,
    double totalCost,
    String currency,
    String periodLabel,
    String reportTitle,
    String filterType,
    String profileName,
    String profileAddress,
    String profilePhone,
    String profileEmail,
  ) {
    final businessDist = trips
        .where((t) => TripType.fromString(t.tripType) == TripType.business)
        .fold<double>(0, (s, t) => s + t.distanceKm);
    final personalDist = trips
        .where((t) => TripType.fromString(t.tripType) == TripType.personal)
        .fold<double>(0, (s, t) => s + t.distanceKm);

    return [
      // ── Brand header ────────────────────────────────────────────────
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.CustomPaint(
            size: const PdfPoint(52, 52),
            painter: _pdfSpeedometerIcon,
          ),
          pw.SizedBox(width: 14),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'GoOdo',
                style: pw.TextStyle(
                  fontSize: 32,
                  fontWeight: pw.FontWeight.bold,
                  color: _rose,
                  letterSpacing: 0.5,
                ),
              ),
              pw.Text(
                'Mileage Report',
                style: const pw.TextStyle(fontSize: 11, color: _darkGrey),
              ),
            ],
          ),
          pw.Spacer(),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                reportTitle,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: _rose,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                periodLabel,
                style: const pw.TextStyle(fontSize: 10, color: _darkGrey),
              ),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 16),
      pw.Container(height: 1, color: _borderLight),
      pw.SizedBox(height: 14),

      // ── Profile ──────────────────────────────────────────────────────
      if (profileName.isNotEmpty) ...[
        pw.Text(
          profileName,
          style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: _nearBlack),
        ),
        pw.SizedBox(height: 4),
      ],
      if (profileAddress.isNotEmpty) ...[
        pw.Text(profileAddress,
            style: const pw.TextStyle(fontSize: 9, color: _darkGrey)),
        pw.SizedBox(height: 3),
      ],
      if (profilePhone.isNotEmpty || profileEmail.isNotEmpty) ...[
        pw.Text(
          [profilePhone, profileEmail].where((s) => s.isNotEmpty).join('   |   '),
          style: const pw.TextStyle(fontSize: 9, color: _darkGrey),
        ),
        pw.SizedBox(height: 3),
      ],
      pw.SizedBox(height: 10),

      // ── Stats chips ──────────────────────────────────────────────────
      pw.Row(
        children: [
          _summaryStat('TRIPS', '${trips.length}', _rose),
          pw.SizedBox(width: 8),
          _summaryStat(
              'TOTAL KM', '${totalDist.toStringAsFixed(1)} km', _nearBlack),
          pw.SizedBox(width: 8),
          _summaryStat('BUSINESS',
              '${businessDist.toStringAsFixed(1)} km', _rose),
          pw.SizedBox(width: 8),
          _summaryStat('PERSONAL',
              '${personalDist.toStringAsFixed(1)} km', _darkGrey),
          pw.SizedBox(width: 8),
          _summaryStat('TOTAL COST ($currency)',
              totalCost.toStringAsFixed(2), _nearBlack),
        ],
      ),
      pw.SizedBox(height: 20),
      pw.Container(height: 0.5, color: _borderLight),
      pw.SizedBox(height: 14),

      // ── Trips table ──────────────────────────────────────────────────
      pw.Text(
        reportTitle,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: _rose,
          letterSpacing: 0.8,
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Table(
        border: pw.TableBorder.all(color: _borderLight, width: 0.5),
        columnWidths: filterType == 'all'
            ? const {
                0: pw.FixedColumnWidth(22),
                1: pw.FlexColumnWidth(80),
                2: pw.FlexColumnWidth(35),
                3: pw.FlexColumnWidth(55),
                4: pw.FlexColumnWidth(90),
                5: pw.FlexColumnWidth(50),
              }
            : filterType == 'business'
                ? const {
                    0: pw.FixedColumnWidth(22),
                    1: pw.FlexColumnWidth(80),
                    2: pw.FlexColumnWidth(55),
                    3: pw.FlexColumnWidth(90),
                    4: pw.FlexColumnWidth(50),
                  }
                : const {
                    0: pw.FixedColumnWidth(22),
                    1: pw.FlexColumnWidth(80),
                    2: pw.FlexColumnWidth(55),
                    3: pw.FlexColumnWidth(90),
                  },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _rose),
            children: [
              _hCell('#'),
              _hCell('DATE'),
              if (filterType == 'all') _hCell('TYPE'),
              _hCell('DISTANCE'),
              _hCell('ODOMETER (START / END)'),
              if (filterType != 'personal') _hCell('COST ($currency)'),
            ],
          ),
          for (var i = 0; i < trips.length; i++)
            pw.TableRow(
              decoration: pw.BoxDecoration(
                  color: i.isEven ? PdfColors.white : _lightGrey),
              children: [
                _tCell('${i + 1}'),
                _tCell(DateFormat('MMM d, y').format(
                    DateTime.fromMillisecondsSinceEpoch(trips[i].startTime))),
                if (filterType == 'all')
                  _tCell(
                    TripType.fromString(trips[i].tripType) == TripType.business
                        ? 'Bus'
                        : 'Per',
                  ),
                _tCell('${trips[i].distanceKm.toStringAsFixed(1)} km'),
                _tCell(_fmtOdo(trips[i].odometerStart, trips[i].odometerEnd)),
                if (filterType != 'personal')
                  _tCell((trips[i].distanceKm * trips[i].mileageRate)
                      .toStringAsFixed(2)),
              ],
            ),
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _lightGrey),
            children: [
              _tCell(''),
              pw.Padding(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: pw.Text(
                  'TOTAL',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _nearBlack),
                ),
              ),
              if (filterType == 'all') _tCell(''),
              pw.Padding(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: pw.Text(
                  '${totalDist.toStringAsFixed(1)} km',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _rose),
                ),
              ),
              _tCell(''),
              if (filterType != 'personal')
                pw.Padding(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: pw.Text(
                    totalCost.toStringAsFixed(2),
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: _rose),
                  ),
                ),
            ],
          ),
        ],
      ),
    ];
  }

  // ── Per-trip detail ────────────────────────────────────────────────────
  List<pw.Widget> _buildTripDetail(
    Trip trip,
    String currency,
    List<TripWaypoint> tripWaypoints,
    List<LocationPoint> points,
  ) {
    final startDt = DateTime.fromMillisecondsSinceEpoch(trip.startTime);
    final isBusiness = TripType.fromString(trip.tripType) == TripType.business;
    final hasOdo = trip.odometerStart > 0 || trip.odometerEnd > 0;
    final pauseWps = tripWaypoints.where((w) => w.isPause).toList();

    return [
      // ── Date + vehicle + type ──────────────────────────────────────
      pw.Text(
        DateFormat('EEEE, MMMM d, y').format(startDt),
        style: pw.TextStyle(
            fontSize: 18, fontWeight: pw.FontWeight.bold, color: _nearBlack),
      ),
      pw.SizedBox(height: 4),
      pw.Row(
        children: [
          if (trip.vehicleNumber.isNotEmpty) ...[
            pw.Text(
              trip.vehicleNumber,
              style: const pw.TextStyle(fontSize: 9, color: _darkGrey),
            ),
            pw.Text(
              '  |  ',
              style: const pw.TextStyle(fontSize: 9, color: _midGrey),
            ),
          ],
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: pw.BoxDecoration(
              color: isBusiness
                  ? _rose
                  : const PdfColor.fromInt(0xFF757575),
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Text(
              isBusiness ? 'Business' : 'Personal',
              style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white),
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 10),

      // ── Odometer box ──────────────────────────────────────────────
      if (hasOdo) ...[
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _borderLight),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'ODOMETER READING',
                style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: _midGrey,
                    letterSpacing: 0.5),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                _fmtOdoRange(trip.odometerStart, trip.odometerEnd),
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: _nearBlack),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
      ],

      // ── Stops & Segments table ────────────────────────────────────
      pw.Text(
        'STOPS & SEGMENTS',
        style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: _rose,
            letterSpacing: 0.8),
      ),
      pw.SizedBox(height: 6),
      _buildStopsTable(trip, pauseWps),

      // ── Route map ────────────────────────────────────────────────
      if (points.length > 1) ...[
        pw.SizedBox(height: 12),
        _buildRouteMapWidget(points, pauseWps),
        pw.SizedBox(height: 2),
        pw.Text(
          'Map data © OpenStreetMap contributors',
          style: const pw.TextStyle(fontSize: 7, color: _midGrey),
        ),
      ],

      // ── Company / notes ──────────────────────────────────────────
      if (trip.companyName.isNotEmpty || trip.notes.isNotEmpty) ...[
        pw.SizedBox(height: 10),
        pw.Container(height: 0.5, color: _borderLight),
        pw.SizedBox(height: 8),
        if (trip.companyName.isNotEmpty) _row('Company', trip.companyName),
        if (trip.notes.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          _row('Notes', trip.notes),
        ],
      ],
    ];
  }

  // ── Stops table ───────────────────────────────────────────────────────
  pw.Widget _buildStopsTable(Trip trip, List<TripWaypoint> pauseWps) {
    final startDt = DateTime.fromMillisecondsSinceEpoch(trip.startTime);
    final endDt = trip.endTime != null
        ? DateTime.fromMillisecondsSinceEpoch(trip.endTime!)
        : null;

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _rose),
        children: [
          _hCell('#'),
          _hCell('TIME'),
          _hCell('LOCATION'),
          _hCell('DISTANCE'),
          _hCell('ODOMETER'),
        ],
      ),
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.white),
        children: [
          _stopBadge('S', isStart: true),
          _tCell(DateFormat('h:mm a').format(startDt)),
          _tCell(trip.startAddress.isNotEmpty ? trip.startAddress : 'Start'),
          _tCell('-'),
          _tCell(trip.odometerStart > 0
              ? '${trip.odometerStart.toStringAsFixed(1)} km'
              : '-'),
        ],
      ),
    ];

    double prevKm = 0.0;
    for (var i = 0; i < pauseWps.length; i++) {
      final wp = pauseWps[i];
      final segKm = wp.distanceKmAtStop - prevKm;
      final odoAtStop = trip.odometerStart > 0
          ? trip.odometerStart + wp.distanceKmAtStop
          : null;
      final loc = wp.address.isNotEmpty
          ? wp.address
          : '${wp.latitude.toStringAsFixed(4)}, ${wp.longitude.toStringAsFixed(4)}';
      rows.add(pw.TableRow(
        decoration:
            pw.BoxDecoration(color: i.isEven ? _lightGrey : PdfColors.white),
        children: [
          _stopBadge('${i + 1}'),
          _tCell(DateFormat('h:mm a')
              .format(DateTime.fromMillisecondsSinceEpoch(wp.timestamp))),
          _tCell(loc),
          _tCell('${segKm.toStringAsFixed(1)} km'),
          _tCell(odoAtStop != null
              ? '${odoAtStop.toStringAsFixed(1)} km'
              : '-'),
        ],
      ));
      prevKm = wp.distanceKmAtStop;
    }

    final finalSegKm = trip.distanceKm - prevKm;
    rows.add(pw.TableRow(
      decoration: pw.BoxDecoration(
          color: pauseWps.length.isEven ? _lightGrey : PdfColors.white),
      children: [
        _stopBadge('E', isEnd: true),
        _tCell(endDt != null ? DateFormat('h:mm a').format(endDt) : '-'),
        _tCell(trip.endAddress.isNotEmpty ? trip.endAddress : 'End'),
        _tCell(finalSegKm > 0.01 ? '${finalSegKm.toStringAsFixed(1)} km' : '-'),
        _tCell(trip.odometerEnd > 0
            ? '${trip.odometerEnd.toStringAsFixed(1)} km'
            : '-'),
      ],
    ));

    return pw.Table(
      border: pw.TableBorder.all(color: _borderLight, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(28),
        1: pw.FlexColumnWidth(55),
        2: pw.FlexColumnWidth(180),
        3: pw.FlexColumnWidth(55),
        4: pw.FlexColumnWidth(65),
      },
      children: rows,
    );
  }

  pw.Widget _stopBadge(String label,
      {bool isStart = false, bool isEnd = false}) {
    final color =
        isStart ? const PdfColor.fromInt(0xFF2E7D32) : _rose;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Center(
        child: pw.Container(
          width: 16,
          height: 16,
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          alignment: pw.Alignment.center,
          child: pw.Text(
            label,
            style: pw.TextStyle(
                fontSize: 6,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white),
          ),
        ),
      ),
    );
  }

  // ── Route map with labeled markers ────────────────────────────────────
  pw.Widget _buildRouteMapWidget(
      List<LocationPoint> points, List<TripWaypoint> stops) {
    if (points.length < 2) return pw.SizedBox(height: 0);
    const w = 522.0, h = 200.0, pad = 16.0;

    double minLat = points.first.latitude, maxLat = minLat;
    double minLng = points.first.longitude, maxLng = minLng;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final latSpan = (maxLat - minLat) * 1.15 + 0.0001;
    final lngSpan = (maxLng - minLng) * 1.15 + 0.0001;
    final latCx = (maxLat + minLat) / 2;
    final lngCx = (maxLng + minLng) / 2;

    // Widget coordinates: y=0 at top, increases downward
    double pxFn(double lng) =>
        pad + (lng - (lngCx - lngSpan / 2)) / lngSpan * (w - 2 * pad);
    double pyFn(double lat) =>
        h - pad - (lat - (latCx - latSpan / 2)) / latSpan * (h - 2 * pad);

    const markerR = 9.0;

    return pw.SizedBox(
      width: w,
      height: h,
      child: pw.Stack(
        children: [
          pw.Positioned(
            left: 0,
            top: 0,
            child: pw.CustomPaint(
              size: const PdfPoint(w, h),
              painter: (g, size) => _drawRouteLines(g, size, points),
            ),
          ),
          for (var i = 0; i < stops.length; i++)
            pw.Positioned(
              left: pxFn(stops[i].longitude) - markerR,
              top: pyFn(stops[i].latitude) - markerR,
              child: _mapMarker('${i + 1}'),
            ),
          pw.Positioned(
            left: pxFn(points.first.longitude) - markerR,
            top: pyFn(points.first.latitude) - markerR,
            child: _mapMarker('S', isStart: true),
          ),
          pw.Positioned(
            left: pxFn(points.last.longitude) - markerR,
            top: pyFn(points.last.latitude) - markerR,
            child: _mapMarker('E', isEnd: true),
          ),
        ],
      ),
    );
  }

  pw.Widget _mapMarker(String label,
      {bool isStart = false, bool isEnd = false}) {
    final color = isStart ? const PdfColor.fromInt(0xFF2E7D32) : _rose;
    return pw.Container(
      width: 18,
      height: 18,
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(9),
      ),
      alignment: pw.Alignment.center,
      child: pw.Text(
        label,
        style: pw.TextStyle(
            fontSize: 7,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white),
      ),
    );
  }

  // ── Route line painter (background + polyline only, markers are widgets) ─
  static void _drawRouteLines(
    PdfGraphics g,
    PdfPoint size,
    List<LocationPoint> points,
  ) {
    if (points.length < 2) return;
    const pad = 16.0;

    double minLat = points.first.latitude, maxLat = minLat;
    double minLng = points.first.longitude, maxLng = minLng;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final latSpan = (maxLat - minLat) * 1.15 + 0.0001;
    final lngSpan = (maxLng - minLng) * 1.15 + 0.0001;
    final latCx = (maxLat + minLat) / 2;
    final lngCx = (maxLng + minLng) / 2;

    double px(double lng) =>
        pad + (lng - (lngCx - lngSpan / 2)) / lngSpan * (size.x - 2 * pad);
    double py(double lat) =>
        pad + (lat - (latCx - latSpan / 2)) / latSpan * (size.y - 2 * pad);

    // Background
    g.setFillColor(_mapBg);
    g.moveTo(0, 0);
    g.lineTo(size.x, 0);
    g.lineTo(size.x, size.y);
    g.lineTo(0, size.y);
    g.closePath();
    g.fillPath();

    // Border
    g.setStrokeColor(_borderLight);
    g.setLineWidth(0.5);
    g.moveTo(0, 0);
    g.lineTo(size.x, 0);
    g.lineTo(size.x, size.y);
    g.lineTo(0, size.y);
    g.closePath();
    g.strokePath();

    // Route polyline
    g.setStrokeColor(_routeColour);
    g.setLineWidth(2.0);
    g.setLineCap(PdfLineCap.round);
    bool first = true;
    for (final p in points) {
      final x = px(p.longitude), y = py(p.latitude);
      if (first) {
        g.moveTo(x, y);
        first = false;
      } else {
        g.lineTo(x, y);
      }
    }
    g.strokePath();
  }

  // ── PDF speedometer (transparent background) ───────────────────────────
  static void _pdfSpeedometerIcon(PdfGraphics g, PdfPoint size) {
    const svgW = 96.0, svgH = 96.0;
    final sx = size.x / svgW;
    final sy = size.y / svgH;
    double px(double x) => x * sx;
    double py(double y) => size.y - y * sy;

    // Background intentionally transparent — only draw the speedometer elements
    // Arc: M(18,62) → top(48,32) → (78,62)
    const cx = 48.0, cy = 62.0, r = 30.0, k = 0.5523;
    g.setStrokeColor(const PdfColor.fromInt(0xFFDA1D69));
    g.setLineWidth(4 * sx);
    g.setLineCap(PdfLineCap.round);
    g.moveTo(px(cx - r), py(cy));
    g.curveTo(px(cx - r), py(cy - r * k), px(cx - r * k), py(cy - r),
        px(cx), py(cy - r));
    g.curveTo(px(cx + r * k), py(cy - r), px(cx + r), py(cy - r * k),
        px(cx + r), py(cy));
    g.strokePath();

    // Top tick
    g.setStrokeColor(const PdfColor(0.863, 0.361, 0.541, 0.45));
    g.setLineWidth(2.5 * sx);
    g.moveTo(px(48), py(32));
    g.lineTo(px(48), py(25));
    g.strokePath();

    // Needle
    g.setStrokeColor(const PdfColor.fromInt(0xFFDA1D69));
    g.setLineWidth(3.5 * sx);
    g.setLineCap(PdfLineCap.round);
    g.moveTo(px(48), py(62));
    g.lineTo(px(66), py(38));
    g.strokePath();

    // Pivot outer
    g.setFillColor(const PdfColor.fromInt(0xFFDA1D69));
    _pdfCircle(g, px(48), py(62), 6 * sx);
    g.fillPath();

    // Pivot inner (white for visibility on white PDF bg)
    g.setFillColor(PdfColors.white);
    _pdfCircle(g, px(48), py(62), 3 * sx);
    g.fillPath();
  }

  static void _pdfCircle(PdfGraphics g, double cx, double cy, double r) {
    const k = 0.5523;
    g.moveTo(cx + r, cy);
    g.curveTo(cx + r, cy + r * k, cx + r * k, cy + r, cx, cy + r);
    g.curveTo(cx - r * k, cy + r, cx - r, cy + r * k, cx - r, cy);
    g.curveTo(cx - r, cy - r * k, cx - r * k, cy - r, cx, cy - r);
    g.curveTo(cx + r * k, cy - r, cx + r, cy - r * k, cx + r, cy);
    g.closePath();
  }

  // ── Small widget helpers ───────────────────────────────────────────────
  pw.Widget _summaryStat(String label, String value, PdfColor valueColor) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _borderLight),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(
                    fontSize: 6,
                    fontWeight: pw.FontWeight.bold,
                    color: _midGrey),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                value,
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: valueColor),
              ),
            ],
          ),
        ),
      );

  pw.Widget _hCell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: pw.Text(
          text,
          style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white),
        ),
      );

  pw.Widget _tCell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: pw.Text(text,
            style: const pw.TextStyle(fontSize: 9, color: _nearBlack)),
      );

  pw.Widget _row(String label, String value) => pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 60,
            child: pw.Text(label,
                style: const pw.TextStyle(fontSize: 8, color: _midGrey)),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 8, color: _nearBlack),
              maxLines: 2,
              overflow: pw.TextOverflow.clip,
            ),
          ),
        ],
      );

  String _fmtOdo(double start, double end) {
    if (start <= 0 && end <= 0) return '-';
    final s = start > 0 ? NumberFormat('#,##0').format(start.round()) : '-';
    final e = end > 0 ? NumberFormat('#,##0').format(end.round()) : '-';
    return '$s / $e km';
  }

  String _fmtOdoRange(double start, double end) {
    if (start <= 0 && end <= 0) return '-';
    final s = start > 0 ? start.toStringAsFixed(1) : '-';
    final e = end > 0 ? end.toStringAsFixed(1) : '-';
    return '$s - $e km';
  }

  // ── CSV ────────────────────────────────────────────────────────────────
  List<int> _buildCsvBytes(List<Trip> trips) {
    final rows = <List<dynamic>>[
      [
        'ID', 'Start Time', 'End Time', 'Distance (km)', 'Max Speed (km/h)',
        'Avg Speed (km/h)', 'Type', 'Company', 'Vehicle', 'Start Address',
        'End Address', 'Start Lat', 'Start Lng', 'End Lat', 'End Lng',
        'Odometer Start', 'Odometer End', 'Rate', 'Cost', 'Notes',
        'Synced', 'Auto Started',
      ],
      for (final t in trips)
        [
          t.id,
          _fmtDt(t.startTime),
          t.endTime != null ? _fmtDt(t.endTime!) : '',
          t.distanceKm.toStringAsFixed(2),
          t.maxSpeedKmh.toStringAsFixed(1),
          t.avgSpeedKmh.toStringAsFixed(1),
          t.tripType,
          t.companyName,
          t.vehicleNumber,
          t.startAddress,
          t.endAddress,
          t.startLat ?? '',
          t.startLng ?? '',
          t.endLat ?? '',
          t.endLng ?? '',
          t.odometerStart,
          t.odometerEnd,
          t.mileageRate,
          (t.distanceKm * t.mileageRate).toStringAsFixed(2),
          t.notes,
          t.isSynced,
          t.autoStarted,
        ],
    ];
    return utf8.encode(const ListToCsvConverter().convert(rows));
  }

  String _fmtDt(int ms) =>
      DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ms));

  String _timestamp() =>
      DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
}
