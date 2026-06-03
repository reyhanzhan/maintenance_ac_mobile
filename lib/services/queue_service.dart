import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:maintenance_ac_mobile/services/storage_service.dart';

class QueueService {
  static const String _key = 'queued_reports';

  static Future<List<Map<String, dynamic>>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    return raw
        .map((e) => Map<String, dynamic>.from(jsonDecode(e) as Map))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getPending() async {
    final all = await getAll();
    all.sort((a, b) {
      final ta = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now();
      final tb = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.now();
      return tb.compareTo(ta);
    });
    return all.where((r) => r['status'] == 'pending').toList();
  }

  static Future<int> getPendingCount() async =>
      (await getPending()).length;

  static Future<void> enqueue(Map<String, dynamic> report) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await getAll();
    all.add(report);
    await prefs.setStringList(
      _key,
      all.map((e) => jsonEncode(e)).toList(),
    );
  }

  static Future<void> updateStatus(String localId, String status,
      {String? error}) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await getAll();
    final idx = all.indexWhere((r) => r['local_id'] == localId);
    if (idx != -1) {
      all[idx] = {
        ...all[idx],
        'status': status,
        if (error != null) 'error_message': error,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await prefs.setStringList(
        _key,
        all.map((e) => jsonEncode(e)).toList(),
      );
    }
  }

  static Future<void> remove(String localId) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await getAll();
    final target = all.firstWhereOrNull((r) => r['local_id'] == localId);
    if (target != null) {
      final generalPaths = List<String>.from(target['general_photo_paths'] ?? []);
      for (final p in generalPaths) {
        await StorageService.deletePath(p);
      }
      final itemPaths = Map<String, dynamic>.from(target['item_photo_paths'] ?? {});
      for (final paths in itemPaths.values) {
        for (final p in List<String>.from(paths)) {
          await StorageService.deletePath(p);
        }
      }
    }
    final filtered = all.where((r) => r['local_id'] != localId).toList();
    await prefs.setStringList(
      _key,
      filtered.map((e) => jsonEncode(e)).toList(),
    );
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove(_key);
  }
}

extension _FirstWhereOrNullExtension<E> on List<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
