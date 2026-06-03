import 'package:flutter/material.dart';

import '../models/report_model.dart';
import '../models/rumah_sakit_model.dart';
import '../services/queue_service.dart';
import '../services/sync_manager.dart';
import 'report_detail_screen.dart';

class ReportHistoryScreen extends StatefulWidget {
  const ReportHistoryScreen({super.key});

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  late Future<List<ReportModel>> _future;
  List<Map<String, dynamic>> _pendingReports = const [];
  SyncData? _syncData;

  @override
  void initState() {
    super.initState();
    _future = SyncManager.getReports();
    _loadPending();
    _loadSyncData();
  }

  Future<void> _loadSyncData() async {
    try {
      final data = await SyncManager.getSyncData();
      if (!mounted) return;
      setState(() => _syncData = data);
    } catch (_) {}
  }

  Future<void> _loadPending() async {
    final pending = await QueueService.getPending();
    if (!mounted) return;
    setState(() => _pendingReports = pending);
  }

  Future<void> _refresh() async {
    setState(() => _future = SyncManager.getReports());
    await _future;
    await Future.wait([_loadPending(), _loadSyncData()]);
  }

  String? _rumahSakitName(dynamic id, String? value) {
    final current = _cleanText(value);
    if (current != null && !_isNumericText(current)) return current;

    final lookupId = _toInt(id ?? current);
    if (lookupId == null) return current;

    for (final item in _syncData?.rumahSakits ?? const <RumahSakitModel>[]) {
      if (item.id == lookupId) return item.nama;
    }
    return current;
  }

  String? _ruanganName(dynamic id, String? value) {
    final current = _cleanText(value);
    if (current != null && !_isNumericText(current)) return current;

    final lookupId = _toInt(id ?? current);
    if (lookupId == null) return current;

    for (final item in _syncData?.ruangans ?? const <RuanganModel>[]) {
      if (item.id == lookupId) return item.nama;
    }
    return current;
  }

  String? _cleanText(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty || text == '-') return null;
    return text;
  }

  bool _isNumericText(String value) => int.tryParse(value) != null;

  int? _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  String _localReportLabel(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.length <= 6) return 'Laporan Lokal #$text';
    return 'Laporan Lokal #${text.substring(text.length - 6)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Laporan')),
      body: FutureBuilder<List<ReportModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }

          final reports = snapshot.data ?? const [];
          final merged = <Map<String, dynamic>>[];

          for (final r in reports) {
            merged.add({
              'id': r.id,
              'rumah_sakit': _rumahSakitName(r.rumahSakitId, r.rumahSakit),
              'ruangan': _ruanganName(r.ruanganId, r.ruangan),
              'tanggal_service': r.tanggalService,
              'is_local': false,
            });
          }

          for (final p in _pendingReports) {
            final fields = Map<String, dynamic>.from(p['fields'] ?? {});
            merged.add({
              'local_id': p['local_id'],
              'rumah_sakit': _rumahSakitName(fields['rumah_sakit_id'], null),
              'ruangan': _ruanganName(fields['ruangan_id'], null),
              'tanggal_service': fields['tanggal_service']?.toString(),
              'is_local': true,
            });
          }

          merged.sort((a, b) {
            final ta =
                DateTime.tryParse(a['tanggal_service'] ?? '') ?? DateTime.now();
            final tb =
                DateTime.tryParse(b['tanggal_service'] ?? '') ?? DateTime.now();
            return tb.compareTo(ta);
          });

          if (merged.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 160),
                  Center(child: Text('Belum ada laporan.')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final item = merged[index];
                final isLocal = item['is_local'] == true;
                final title =
                    item['rumah_sakit']?.toString() ??
                    (isLocal
                        ? _localReportLabel(item['local_id'])
                        : 'Laporan #${item['id']}');
                final subtitle = [
                  if (item['ruangan'] != null) item['ruangan']?.toString(),
                  if (item['tanggal_service'] != null)
                    item['tanggal_service']?.toString(),
                ].whereType<String>().join(' - ');

                return Card(
                  child: ListTile(
                    title: Text(title),
                    subtitle: Text(subtitle),
                    trailing: Icon(
                      isLocal
                          ? Icons.cloud_upload_outlined
                          : Icons.chevron_right,
                    ),
                    onTap: () {
                      if (!isLocal && item['id'] != null) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => ReportDetailScreen(
                                  reportId: item['id'] as int,
                                ),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemCount: merged.length,
            ),
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
