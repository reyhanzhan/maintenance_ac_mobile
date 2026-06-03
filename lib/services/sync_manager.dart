import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:maintenance_ac_mobile/services/api_service.dart';
import 'package:maintenance_ac_mobile/services/storage_service.dart';
import 'package:maintenance_ac_mobile/services/queue_service.dart';
import 'package:maintenance_ac_mobile/models/report_model.dart';
import 'package:maintenance_ac_mobile/models/rumah_sakit_model.dart';
import 'package:image_picker/image_picker.dart';

class SyncManager {
  static bool _syncing = false;
  static bool _online = true;

  static bool get isOnline => !kIsWeb && _online;
  static bool get shouldAutoSync => true;

  static Future<void> init() async {
    await StorageService.init();

    StorageService.onConnectivityChanged.listen((online) {
      _online = online;
      if (online) _flushQueue();
    });
  }

  static Future<void> tryFlush() async => _flushQueue();

  static Future<List<ReportModel>> getReports() async {
    try {
      final api = ApiService();
      final reports = await api.fetchReports();
      await StorageService.cacheReports(reports.map((r) => r.toJson()).toList());
      return reports;
    } catch (e) {
      final cached = await StorageService.getCachedReports();
      if (cached.isNotEmpty) {
        return cached.map((r) => ReportModel.fromJson(r)).toList();
      }
      rethrow;
    }
  }

  static Future<ReportModel?> getReportDetail(int id) async {
    try {
      final api = ApiService();
      final report = await api.fetchReportDetail(id);
      await StorageService.cacheDetailReport(id, report.toJson());
      return report;
    } catch (e) {
      final cached = await StorageService.getCachedDetailReport(id);
      if (cached != null) return ReportModel.fromJson(cached);
      rethrow;
    }
  }

  static Future<SyncData?> getSyncData() async {
    try {
      final api = ApiService();
      final data = await api.fetchSyncData();
      await StorageService.cacheSyncData(jsonEncode(data.toJson()));
      return data;
    } catch (e) {
      final cached = await StorageService.getCachedSyncData();
      if (cached != null) return SyncData.fromJson(jsonDecode(cached));
      rethrow;
    }
  }

  static Future<String?> enqueueReport({
    required Map<String, String> fields,
    required Map<String, ItemPayload> items,
    required List<XFile> generalPhotos,
    required Map<String, List<XFile>> itemPhotos,
  }) async {
    final generalPaths = <String>[];
    for (final f in generalPhotos) {
      final saved = await StorageService.savePhoto(f);
      generalPaths.add(saved);
    }

    final itemPaths = <String, List<String>>{};
    for (final entry in itemPhotos.entries) {
      final saved = <String>[];
      for (final f in entry.value) {
        saved.add(await StorageService.savePhoto(f));
      }
      itemPaths[entry.key] = saved;
    }

    final serializedItems = items.map((k, v) => MapEntry(
      k,
      <String, dynamic>{'is_normal': v.isNormal, 'keterangan': v.keterangan},
    ));

    final record = <String, dynamic>{
      'local_id': '${DateTime.now().millisecondsSinceEpoch}',
      'fields': fields,
      'items': serializedItems,
      'general_photo_paths': generalPaths,
      'item_photo_paths': itemPaths,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    };

    await QueueService.enqueue(record);

    if (isOnline) _flushQueue();

    return record['local_id'] as String;
  }

  static Future<List<Map<String, dynamic>>> getPending() async =>
      QueueService.getPending();

  static Future<void> clearAll() => QueueService.clearAll();

  static Future<void> _flushQueue() async {
    if (_syncing || !isOnline) return;
    _syncing = true;
    try {
      final pending = QueueService.getPending();
      final api = ApiService();

      for (final record in await pending) {
        final localId = record['local_id'] as String;
        try {
          await QueueService.updateStatus(localId, 'uploading');

          final fields = Map<String, String>.from(record['fields'] as Map);
          final rawItems = Map<String, dynamic>.from(record['items'] as Map? ?? {});
          final items = rawItems.map((k, v) {
            final m = Map<String, dynamic>.from(v as Map);
            return MapEntry(
              k,
              ItemPayload(
                isNormal: m['is_normal'] == true || m['is_normal'] == '1',
                keterangan: (m['keterangan'] ?? '').toString(),
              ),
            );
          });

          final generalPaths = List<String>.from(record['general_photo_paths'] ?? []);
          final generalXFiles = generalPaths.map((p) => XFile(p)).toList();

          final itemPhotoPaths = Map<String, dynamic>.from(record['item_photo_paths'] ?? {});
          final itemXFiles = <String, List<XFile>>{};
          for (final entry in itemPhotoPaths.entries) {
            itemXFiles[entry.key] = List<String>.from(entry.value)
                .map((p) => XFile(p))
                .toList();
          }

          await api.postMultipartReport(
            fields: fields,
            items: items,
            generalPhotos: generalXFiles,
            itemPhotos: itemXFiles,
          );

          await StorageService.deletePhotos(generalXFiles);
          for (final files in itemXFiles.values) {
            await StorageService.deletePhotos(files);
          }
          await QueueService.remove(localId);
        } catch (e) {
          await QueueService.updateStatus(localId, 'failed', error: e.toString());
        }
      }
    } catch (_) {
    } finally {
      _syncing = false;
    }
  }
}
