import 'dart:convert';
import 'dart:io';
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
      MethodChannel('com.example.milelog_flutter/downloads');

  Future<({Uint8List bytes, String filename})> generatePdf({
    required List<Trip> trips,
    required String periodLabel,
    String currency = AppConstants.defaultCurrencyCode,
    Map<int, List<TripWaypoint>> waypoints = const {},
    String profileName = '',
    String profileAddress = '',
    String profilePhone = '',
    String profileEmail = '',
  }) async {
    final bytes = await _buildPdfBytes(
      trips: trips,
      periodLabel: periodLabel,
      currency: currency,
      waypoints: waypoints,
      profileName: profileName,
      profileAddress: profileAddress,
      profilePhone: profilePhone,
      profileEmail: profileEmail,
    );
    final filename = 'MileLog_Report_${_timestamp()}.pdf';
    return (bytes: bytes, filename: filename);
  }

  Future<({List<int> bytes, String filename})> generateCsv({
    required List<Trip> trips,
  }) async {
    final bytes = _buildCsvBytes(trips);
    final filename = 'MileLog_Export_${_timestamp()}.csv';
    return (bytes: bytes, filename: filename);
  }

  /// Shares file via OS share sheet.
  Future<void> shareFile(String filename, List<int> bytes) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)], subject: filename);
  }

  /// Saves file to device Downloads folder via native MediaStore (Android 10+)
  /// or legacy path. Returns true on success.
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

  // ── PDF color palette (white bg, rose accent) ───────────────────────────
  static const _roseAccent = PdfColor.fromInt(0xFFDA1D69);
  static const _nearBlack = PdfColor.fromInt(0xFF1A1A1A);
  static const _darkGrey = PdfColor.fromInt(0xFF424242);
  static const _midGrey = PdfColor.fromInt(0xFF9E9E9E);
  static const _lightGrey = PdfColor.fromInt(0xFFF7F7F7);
  static const _borderLight = PdfColor.fromInt(0xFFE0E0E0);

  Future<Uint8List> _buildPdfBytes({
    required List<Trip> trips,
    required String periodLabel,
    required String currency,
    required Map<int, List<TripWaypoint>> waypoints,
    String profileName = '',
    String profileAddress = '',
    String profilePhone = '',
    String profileEmail = '',
  }) async {
    final doc = pw.Document();

    final totalDistance =
        trips.fold<double>(0, (sum, t) => sum + t.distanceKm);
    final businessTrips = trips
        .where((t) => TripType.fromString(t.tripType) == TripType.business)
        .toList();
    final personalTrips = trips
        .where((t) => TripType.fromString(t.tripType) == TripType.personal)
        .toList();
    final businessDistance =
        businessTrips.fold<double>(0, (sum, t) => sum + t.distanceKm);
    final personalDistance =
        personalTrips.fold<double>(0, (sum, t) => sum + t.distanceKm);
    final totalCost =
        trips.fold<double>(0, (sum, t) => sum + t.distanceKm * t.mileageRate);

    const pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.all(36),
    );

    // ── Cover page ──────────────────────────────────────────────────────
    doc.addPage(pw.Page(
      pageTheme: pageTheme,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Brand bar
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 5,
                height: 44,
                color: _roseAccent,
                margin: const pw.EdgeInsets.only(right: 14),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'MILELOG',
                    style: pw.TextStyle(
                      fontSize: 34,
                      fontWeight: pw.FontWeight.bold,
                      color: _roseAccent,
                      letterSpacing: 1.6,
                    ),
                  ),
                  pw.Text(
                    'Mileage Report',
                    style: const pw.TextStyle(
                        fontSize: 11, color: _darkGrey),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 32),
          pw.Container(height: 1, color: _borderLight),
          pw.SizedBox(height: 28),
          // Company / profile info
          if (profileName.isNotEmpty) ...[
            pw.Text(
              profileName,
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: _nearBlack,
              ),
            ),
            pw.SizedBox(height: 6),
          ],
          if (profileAddress.isNotEmpty) ...[
            pw.Text(profileAddress,
                style:
                    const pw.TextStyle(fontSize: 11, color: _darkGrey)),
            pw.SizedBox(height: 4),
          ],
          if (profilePhone.isNotEmpty || profileEmail.isNotEmpty) ...[
            pw.Row(
              children: [
                if (profilePhone.isNotEmpty)
                  pw.Text(profilePhone,
                      style: const pw.TextStyle(
                          fontSize: 11, color: _darkGrey)),
                if (profilePhone.isNotEmpty && profileEmail.isNotEmpty)
                  pw.Text('   ·   ',
                      style: const pw.TextStyle(
                          fontSize: 11, color: _midGrey)),
                if (profileEmail.isNotEmpty)
                  pw.Text(profileEmail,
                      style: const pw.TextStyle(
                          fontSize: 11, color: _darkGrey)),
              ],
            ),
            pw.SizedBox(height: 4),
          ],
          pw.SizedBox(height: 28),
          pw.Container(height: 1, color: _borderLight),
          pw.SizedBox(height: 20),
          // Period + generation date
          pw.Row(
            children: [
              pw.Text('Period:  ',
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: _roseAccent)),
              pw.Text(periodLabel,
                  style: const pw.TextStyle(
                      fontSize: 11, color: _nearBlack)),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Text('Generated:  ',
                  style: const pw.TextStyle(
                      fontSize: 11, color: _midGrey)),
              pw.Text(
                DateFormat('MMMM d, yyyy').format(DateTime.now()),
                style: const pw.TextStyle(
                    fontSize: 11, color: _darkGrey),
              ),
            ],
          ),
          pw.SizedBox(height: 32),
          // Summary stats box
          pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _borderLight),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _coverStat('TRIPS', '${trips.length}', _roseAccent),
                _vDivider(),
                _coverStat('TOTAL',
                    '${totalDistance.toStringAsFixed(1)} km', _nearBlack),
                _vDivider(),
                _coverStat('BUSINESS',
                    '${businessDistance.toStringAsFixed(1)} km', _roseAccent),
                _vDivider(),
                _coverStat('PERSONAL',
                    '${personalDistance.toStringAsFixed(1)} km', _darkGrey),
                _vDivider(),
                _coverStat(
                  'COST ($currency)',
                  totalCost.toStringAsFixed(2),
                  _nearBlack,
                ),
              ],
            ),
          ),
        ],
      ),
    ));

    // ── Trip table + detail pages ──────────────────────────────────────
    pw.Widget header(pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'MILELOG',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: _roseAccent,
                    letterSpacing: 0.8,
                  ),
                ),
                pw.Text(
                  periodLabel,
                  style: const pw.TextStyle(fontSize: 9, color: _midGrey),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Container(height: 1, color: _borderLight),
            pw.SizedBox(height: 14),
          ],
        );

    pw.Widget footer(pw.Context ctx) => pw.Column(
          children: [
            pw.Container(height: 1, color: _borderLight),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated by MileLog · '
                  '${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
                  style: const pw.TextStyle(
                      fontSize: 7, color: _midGrey),
                ),
                pw.Text(
                  'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: const pw.TextStyle(
                      fontSize: 7, color: _midGrey),
                ),
              ],
            ),
          ],
        );

    doc.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        header: header,
        footer: footer,
        build: (context) => [
          // ── Trip summary table ─────────────────────────────────────
          pw.Text(
            'TRIP SUMMARY',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: _roseAccent,
              letterSpacing: 0.8,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: _borderLight, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.8),
              1: pw.FlexColumnWidth(1.3),
              2: pw.FlexColumnWidth(1.1),
              3: pw.FlexColumnWidth(1.8),
              4: pw.FlexColumnWidth(1.3),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _roseAccent),
                children: [
                  _headerCell('DATE'),
                  _headerCell('DISTANCE'),
                  _headerCell('TYPE'),
                  _headerCell('COMPANY'),
                  _headerCell('COST ($currency)'),
                ],
              ),
              for (var i = 0; i < trips.length; i++)
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: i.isEven ? PdfColors.white : _lightGrey,
                  ),
                  children: [
                    _cell(
                      DateFormat('MMM d, y').format(
                        DateTime.fromMillisecondsSinceEpoch(
                            trips[i].startTime),
                      ),
                    ),
                    _cell(
                        '${trips[i].distanceKm.toStringAsFixed(1)} km'),
                    _badgeCell(TripType.fromString(trips[i].tripType)),
                    _cell(trips[i].companyName.isEmpty
                        ? '-'
                        : trips[i].companyName),
                    _cell(
                      (trips[i].distanceKm * trips[i].mileageRate)
                          .toStringAsFixed(2),
                    ),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 28),
          // ── Per-trip detail section ────────────────────────────────
          pw.Text(
            'TRIP DETAILS',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: _roseAccent,
              letterSpacing: 0.8,
            ),
          ),
          pw.SizedBox(height: 10),
          for (final trip in trips) ...[
            _tripDetailCard(
              trip,
              currency,
              waypoints[trip.id] ?? const [],
            ),
            pw.SizedBox(height: 8),
          ],
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _coverStat(
          String label, String value, PdfColor valueColor) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: _midGrey,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      );

  pw.Widget _vDivider() =>
      pw.Container(width: 1, height: 36, color: _borderLight);

  pw.Widget _headerCell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
        ),
      );

  pw.Widget _cell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: pw.Text(
          text,
          style: const pw.TextStyle(fontSize: 9, color: _nearBlack),
        ),
      );

  pw.Widget _badgeCell(TripType type) {
    final isBusiness = type == TripType.business;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: pw.Container(
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: pw.BoxDecoration(
          color: isBusiness
              ? _roseAccent
              : const PdfColor.fromInt(0xFF757575),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(
          type.value,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
        ),
      ),
    );
  }

  pw.Widget _tripDetailCard(
    Trip trip,
    String currency,
    List<TripWaypoint> tripWaypoints,
  ) {
    final startDt = DateTime.fromMillisecondsSinceEpoch(trip.startTime);
    final endDt = trip.endTime != null
        ? DateTime.fromMillisecondsSinceEpoch(trip.endTime!)
        : null;
    final duration =
        endDt != null ? _formatDuration(endDt.difference(startDt)) : '-';
    final isBusiness =
        TripType.fromString(trip.tripType) == TripType.business;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: _borderLight, width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                DateFormat('EEE, MMM d, y · HH:mm').format(startDt),
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: _nearBlack,
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: pw.BoxDecoration(
                  color: isBusiness
                      ? _roseAccent
                      : const PdfColor.fromInt(0xFF757575),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  isBusiness ? 'Business' : 'Personal',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          // Stats
          pw.Row(
            children: [
              _detailStat('Distance',
                  '${trip.distanceKm.toStringAsFixed(1)} km', _roseAccent),
              pw.SizedBox(width: 24),
              _detailStat('Duration', duration, _darkGrey),
              pw.SizedBox(width: 24),
              _detailStat(
                'Cost',
                '${trip.distanceKm > 0 && trip.mileageRate > 0 ? (trip.distanceKm * trip.mileageRate).toStringAsFixed(2) : '-'} $currency',
                _darkGrey,
              ),
            ],
          ),
          if (trip.startAddress.isNotEmpty ||
              trip.endAddress.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Container(height: 0.5, color: _borderLight),
            pw.SizedBox(height: 8),
            if (trip.startAddress.isNotEmpty)
              _detailRow('From', trip.startAddress),
            if (trip.endAddress.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              _detailRow('To', trip.endAddress),
            ],
          ],
          if (trip.odometerStart > 0 || trip.odometerEnd > 0) ...[
            pw.SizedBox(height: 6),
            _detailRow(
              'Odometer',
              '${trip.odometerStart.toStringAsFixed(0)} → '
                  '${trip.odometerEnd.toStringAsFixed(0)} km',
            ),
          ],
          if (trip.companyName.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            _detailRow('Company', trip.companyName),
          ],
          if (trip.notes.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            _detailRow('Notes', trip.notes),
          ],
          if (tripWaypoints.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Container(height: 0.5, color: _borderLight),
            pw.SizedBox(height: 6),
            pw.Text(
              'STOPS',
              style: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: _roseAccent,
                letterSpacing: 0.6,
              ),
            ),
            pw.SizedBox(height: 4),
            for (final wp in tripWaypoints)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 56,
                      child: pw.Text(
                        DateFormat('HH:mm').format(
                          DateTime.fromMillisecondsSinceEpoch(
                              wp.timestamp),
                        ),
                        style: const pw.TextStyle(
                            fontSize: 7, color: _midGrey),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        wp.address.isNotEmpty
                            ? wp.address
                            : '${wp.latitude.toStringAsFixed(4)}, '
                                '${wp.longitude.toStringAsFixed(4)}',
                        style: const pw.TextStyle(
                            fontSize: 7, color: _darkGrey),
                        maxLines: 1,
                        overflow: pw.TextOverflow.clip,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  pw.Widget _detailStat(
          String label, String value, PdfColor valueColor) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style:
                  const pw.TextStyle(fontSize: 7, color: _midGrey)),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      );

  pw.Widget _detailRow(String label, String value) => pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 56,
            child: pw.Text(
              label,
              style:
                  const pw.TextStyle(fontSize: 8, color: _midGrey),
            ),
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

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  List<int> _buildCsvBytes(List<Trip> trips) {
    final rows = <List<dynamic>>[
      [
        'ID',
        'Start Time',
        'End Time',
        'Distance (km)',
        'Max Speed (km/h)',
        'Avg Speed (km/h)',
        'Type',
        'Company',
        'Vehicle',
        'Start Address',
        'End Address',
        'Start Lat',
        'Start Lng',
        'End Lat',
        'End Lng',
        'Odometer Start',
        'Odometer End',
        'Rate',
        'Cost',
        'Notes',
        'Synced',
        'Auto Started',
      ],
      for (final trip in trips)
        [
          trip.id,
          _formatDateTime(trip.startTime),
          trip.endTime != null ? _formatDateTime(trip.endTime!) : '',
          trip.distanceKm.toStringAsFixed(2),
          trip.maxSpeedKmh.toStringAsFixed(1),
          trip.avgSpeedKmh.toStringAsFixed(1),
          trip.tripType,
          trip.companyName,
          trip.vehicleNumber,
          trip.startAddress,
          trip.endAddress,
          trip.startLat ?? '',
          trip.startLng ?? '',
          trip.endLat ?? '',
          trip.endLng ?? '',
          trip.odometerStart,
          trip.odometerEnd,
          trip.mileageRate,
          (trip.distanceKm * trip.mileageRate).toStringAsFixed(2),
          trip.notes,
          trip.isSynced,
          trip.autoStarted,
        ],
    ];

    return utf8.encode(const ListToCsvConverter().convert(rows));
  }

  String _formatDateTime(int timestampMs) =>
      DateFormat('yyyy-MM-dd HH:mm')
          .format(DateTime.fromMillisecondsSinceEpoch(timestampMs));

  String _timestamp() =>
      DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
}
