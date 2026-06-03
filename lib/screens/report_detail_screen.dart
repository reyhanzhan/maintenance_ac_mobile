import 'package:flutter/material.dart';

import '../models/report_model.dart';
import '../models/rumah_sakit_model.dart';
import '../services/sync_manager.dart';

class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({super.key, required this.reportId});

  final int reportId;

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  late Future<ReportModel?> _future;
  SyncData? _syncData;

  @override
  void initState() {
    super.initState();
    _future = SyncManager.getReportDetail(widget.reportId);
    _loadSyncData();
  }

  Future<void> _loadSyncData() async {
    try {
      final data = await SyncManager.getSyncData();
      if (!mounted) return;
      setState(() => _syncData = data);
    } catch (_) {}
  }

  String _rumahSakitName(ReportModel report) {
    final current = _cleanText(report.rumahSakit);
    if (current != null && !_isNumericText(current)) return current;

    final lookupId = report.rumahSakitId ?? _toInt(current);
    if (lookupId != null) {
      for (final item in _syncData?.rumahSakits ?? const <RumahSakitModel>[]) {
        if (item.id == lookupId) return item.nama;
      }
    }

    return current ?? '-';
  }

  String _ruanganName(ReportModel report) {
    final current = _cleanText(report.ruangan);
    if (current != null && !_isNumericText(current)) return current;

    final lookupId = report.ruanganId ?? _toInt(current);
    if (lookupId != null) {
      for (final item in _syncData?.ruangans ?? const <RuanganModel>[]) {
        if (item.id == lookupId) return item.nama;
      }
    }

    return current ?? '-';
  }

  String? _cleanText(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty || text == '-') return null;
    return text;
  }

  bool _isNumericText(String value) => int.tryParse(value) != null;

  int? _toInt(dynamic value) => int.tryParse(value?.toString() ?? '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Laporan #${widget.reportId}')),
      body: FutureBuilder<ReportModel?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  snapshot.error?.toString() ??
                      'Detail laporan tidak tersedia.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final report = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _InfoCard(
                title: 'Informasi',
                rows: {
                  'Rumah sakit': _rumahSakitName(report),
                  'Ruangan': _ruanganName(report),
                  'Gedung':
                      report.gedung?.isEmpty == false ? report.gedung! : '-',
                  'Merk AC': report.merkAc ?? '-',
                  'Type AC': report.typeAc ?? '-',
                  'Tanggal service': report.tanggalService ?? '-',
                  'Uraian pekerjaan': report.saran ?? '-',
                },
              ),
              const SizedBox(height: 16),
              _PhotoSection(title: 'Foto Umum', photos: report.photos),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Checklist',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      if (report.items.isEmpty)
                        const Text('Tidak ada item checklist.')
                      else
                        for (final item in report.items)
                          _ItemDetail(item: item),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});

  final String title;
  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            for (final entry in rows.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(child: Text(entry.value)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ItemDetail extends StatelessWidget {
  const _ItemDetail({required this.item});

  final ReportItemModel item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${item.nomor}. ${item.nama}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text('Nilai: ${_itemValueText(item)}'),
          if (item.keterangan?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(item.keterangan!),
          ],
          if (item.photos.isNotEmpty) ...[
            const SizedBox(height: 8),
            _PhotoGrid(photos: item.photos),
          ],
        ],
      ),
    );
  }

  String _itemValueText(ReportItemModel item) {
    final raw = item.value?.trim();
    if (raw == null || raw.isEmpty) {
      return item.isNormal ? 'Normal' : 'Tidak normal';
    }

    final normalized = raw.toLowerCase();
    if (raw == '1' || normalized == 'true' || normalized == 'normal') {
      return 'Normal';
    }
    if (raw == '0' || normalized == 'false' || normalized == 'tidak normal') {
      return 'Tidak normal';
    }
    return raw;
  }
}

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({required this.title, required this.photos});

  final String title;
  final List<ReportPhotoModel> photos;

  @override
  Widget build(BuildContext context) {
    final visiblePhotos =
        photos.where((photo) => photo.url.isNotEmpty).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (visiblePhotos.isEmpty)
              const Text('Tidak ada foto.')
            else
              _PhotoGrid(photos: visiblePhotos),
          ],
        ),
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.photos});

  final List<ReportPhotoModel> photos;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        return InkWell(
          onTap:
              () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (_) => _PhotoViewerScreen(
                        photos: photos,
                        initialIndex: index,
                      ),
                ),
              ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              photo.url,
              fit: BoxFit.cover,
              errorBuilder:
                  (_, _, _) => Container(
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(8),
                    child: const Text('Foto gagal dimuat'),
                  ),
            ),
          ),
        );
      },
    );
  }
}

class _PhotoViewerScreen extends StatefulWidget {
  const _PhotoViewerScreen({required this.photos, required this.initialIndex});

  final List<ReportPhotoModel> photos;
  final int initialIndex;

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1}/${widget.photos.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photos.length,
        onPageChanged: (value) => setState(() => _index = value),
        itemBuilder: (context, index) {
          final photo = widget.photos[index];
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: Image.network(
                photo.url,
                fit: BoxFit.contain,
                errorBuilder:
                    (_, _, _) => const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Foto gagal dimuat',
                        style: TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
              ),
            ),
          );
        },
      ),
    );
  }
}
