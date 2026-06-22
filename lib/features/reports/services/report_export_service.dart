import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/app_constants.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/trip_type.dart';

/// Generates and saves PDF/CSV trip exports for the Reports tab.
///
/// Tries the device's public Downloads folder first; on platforms or
/// Android versions where scoped storage blocks a direct write there, it
/// falls back to the app's own external-storage directory (no runtime
/// permission required) so the export never silently fails. The returned
/// [File] always reflects where the export actually landed.
class ReportExportService {
  Future<File> exportPdf({
    required List<Trip> trips,
    required String periodLabel,
  }) async {
    final bytes = await _buildPdfBytes(trips: trips, periodLabel: periodLabel);
    return _saveFile('MileLog_Report_${_timestamp()}.pdf', bytes);
  }

  Future<File> exportCsv({required List<Trip> trips}) async {
    final bytes = _buildCsvBytes(trips);
    return _saveFile('MileLog_Export_${_timestamp()}.csv', bytes);
  }

  Future<Uint8List> _buildPdfBytes({
    required List<Trip> trips,
    required String periodLabel,
  }) async {
    final doc = pw.Document();
    const teal = PdfColor.fromInt(0xFF00BCD4);

    final totalDistance = trips.fold<double>(0, (sum, t) => sum + t.distanceKm);
    final totalCost = trips.fold<double>(
      0,
      (sum, t) => sum + t.distanceKm * t.mileageRate,
    );

    doc.addPage(
      pw.MultiPage(
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'MILELOG',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: teal,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              periodLabel,
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 12),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 12),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
          ),
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: const ['Date', 'Distance (km)', 'Type', 'Company', 'Cost'],
            data: [
              for (final trip in trips)
                [
                  DateFormat('MMM d, y')
                      .format(DateTime.fromMillisecondsSinceEpoch(trip.startTime)),
                  trip.distanceKm.toStringAsFixed(1),
                  TripType.fromString(trip.tripType).value,
                  trip.companyName.isEmpty ? '-' : trip.companyName,
                  '${AppConstants.defaultCurrencySymbol}'
                      '${(trip.distanceKm * trip.mileageRate).toStringAsFixed(2)}',
                ],
            ],
            border: null,
            headerDecoration: const pw.BoxDecoration(color: teal),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 10,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _totalColumn('TOTAL TRIPS', '${trips.length}'),
                _totalColumn('TOTAL DISTANCE', '${totalDistance.toStringAsFixed(1)} km'),
                _totalColumn(
                  'TOTAL COST',
                  '${AppConstants.defaultCurrencySymbol}${totalCost.toStringAsFixed(2)}',
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _totalColumn(String label, String value) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
        ],
      );

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

  String _formatDateTime(int timestampMs) => DateFormat('yyyy-MM-dd HH:mm')
      .format(DateTime.fromMillisecondsSinceEpoch(timestampMs));

  String _timestamp() => DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

  Future<File> _saveFile(String fileName, List<int> bytes) async {
    final downloadsDir = await _tryGetDownloadsDirectory();
    if (downloadsDir != null) {
      try {
        final file = File('${downloadsDir.path}/$fileName');
        await file.writeAsBytes(bytes, flush: true);
        return file;
      } catch (_) {
        // Scoped storage (Android 10+) or platform sandboxing can block a
        // direct write to the public Downloads folder — fall back below
        // instead of failing the export outright.
      }
    }

    final fallbackDir =
        await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final file = File('${fallbackDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<Directory?> _tryGetDownloadsDirectory() async {
    try {
      return await getDownloadsDirectory();
    } catch (_) {
      return null;
    }
  }
}
