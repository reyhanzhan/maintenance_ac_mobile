import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _reportDirName = 'report_photos';
  static const _cacheDirName = 'sync_cache';
  static Directory? _reportDir;
  static Directory? _cacheDir;

  static bool _offline = false;
  static bool get isOffline => !kIsWeb && _offline;

  static Future<void> init() async {
    if (kIsWeb) return;
    final root = await getApplicationDocumentsDirectory();
    _reportDir = Directory('${root.path}/$_reportDirName');
    _cacheDir = Directory('${root.path}/$_cacheDirName');
    await _reportDir!.create(recursive: true);
    await _cacheDir!.create(recursive: true);
  }

  static Directory get reportDir {
    if (_reportDir == null) throw StateError('StorageService not initialized');
    return _reportDir!;
  }

  static Future<String> savePhoto(XFile file) async {
    if (kIsWeb) return file.path;
    final ext = file.path.split('.').last.toLowerCase();
    final name = '${DateTime.now().microsecondsSinceEpoch}.$ext';
    final dest = File('${reportDir.path}/$name');
    await dest.create(recursive: true);
    await dest.writeAsBytes(await file.readAsBytes());
    return dest.path;
  }

  static Future<List<String>> savePhotos(List<XFile> files) async {
    final result = <String>[];
    for (final f in files) {
      result.add(await savePhoto(f));
    }
    return result;
  }

  static Future<void> deletePhotos(List<XFile?> files) async {
    if (kIsWeb) return;
    for (final f in files) {
      if (f == null) continue;
      final file = File(f.path);
      if (await file.exists()) await file.delete();
    }
  }

  static Future<void> deletePath(String? path) async {
    if (kIsWeb || path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  static Future<void> cacheReports(List<Map<String, dynamic>> reports) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_reports', jsonEncode(reports));
  }

  static Future<List<Map<String, dynamic>>> getCachedReports() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cached_reports');
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded.cast<Map<String, dynamic>>();
    return [];
  }

  static Future<void> cacheDetailReport(int id, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('report_detail_$id', jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> getCachedDetailReport(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('report_detail_$id');
    if (raw == null) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  static Future<void> cacheJson(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static Future<String?> getCachedJson(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<void> cacheSyncData(String json) async {
    if (kIsWeb || _cacheDir == null) return;
    final f = File('${_cacheDir!.path}/sync_data.json');
    await f.writeAsString(json);
  }

  static Future<String?> getCachedSyncData() async {
    if (kIsWeb || _cacheDir == null) return null;
    final f = File('${_cacheDir!.path}/sync_data.json');
    if (!await f.exists()) return null;
    return await f.readAsString();
  }

  static Stream<bool> get onConnectivityChanged =>
      Connectivity().onConnectivityChanged.map((results) {
        _offline = results.every((r) => r == ConnectivityResult.none);
        return !_offline;
      });
}
