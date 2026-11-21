import 'dart:io';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/gallery_photo.dart';

class ExportHelper {
  /// Exports photos to a CSV file and triggers the system share sheet.
  static Future<void> exportToCsv(List<GalleryPhoto> photos) async {
    if (photos.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln('Filename,Capture Date,Capture Time,Latitude,Longitude,Google Maps Link');

    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm:ss');

    for (final photo in photos) {
      final name = _escapeCsv(photo.name);
      final date = dateFormat.format(photo.createdAt);
      final time = timeFormat.format(photo.createdAt);
      final lat = photo.latitude?.toStringAsFixed(6) ?? '';
      final lon = photo.longitude?.toStringAsFixed(6) ?? '';
      final mapsUrl = (photo.latitude != null && photo.longitude != null)
          ? 'https://maps.google.com/?q=$lat,$lon'
          : '';

      buffer.writeln('"$name","$date","$time","$lat","$lon","$mapsUrl"');
    }

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/geosnap_export_$timestamp.csv');
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'GeoSnap Survey Export (CSV)',
      text: 'Exported ${photos.length} geotagged photo records from GeoSnap.',
    );
  }

  /// Exports photos with GPS coordinates to a KML (Keyhole Markup Language) file for Google Earth.
  static Future<void> exportToKml(List<GalleryPhoto> photos) async {
    final geoPhotos = photos.where((p) => p.latitude != null && p.longitude != null).toList();
    if (geoPhotos.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<kml xmlns="http://www.opengis.net/kml/2.2">');
    buffer.writeln('  <Document>');
    buffer.writeln('    <name>GeoSnap Survey Photos</name>');
    buffer.writeln('    <description>Exported from GeoSnap</description>');

    final timeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    for (final photo in geoPhotos) {
      final formattedTime = timeFormat.format(photo.createdAt);
      buffer.writeln('    <Placemark>');
      buffer.writeln('      <name>${_escapeXml(photo.name)}</name>');
      buffer.writeln('      <description><![CDATA[');
      buffer.writeln('Captured: $formattedTime<br/>');
      buffer.writeln('Latitude: ${photo.latitude}<br/>');
      buffer.writeln('Longitude: ${photo.longitude}');
      buffer.writeln('      ]]></description>');
      buffer.writeln('      <Point>');
      buffer.writeln('        <coordinates>${photo.longitude},${photo.latitude},0</coordinates>');
      buffer.writeln('      </Point>');
      buffer.writeln('    </Placemark>');
    }

    buffer.writeln('  </Document>');
    buffer.writeln('</kml>');

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/geosnap_survey_$timestamp.kml');
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/vnd.google-earth.kml+xml')],
      subject: 'GeoSnap Survey Export (KML)',
      text: 'Exported ${geoPhotos.length} photo locations for Google Earth.',
    );
  }

  static String _escapeCsv(String value) {
    return value.replaceAll('"', '""');
  }

  static String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
