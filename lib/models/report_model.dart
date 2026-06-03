class ReportModel {
  const ReportModel({
    required this.id,
    this.rumahSakitId,
    this.ruanganId,
    this.rumahSakit,
    this.ruangan,
    this.gedung,
    this.merkAc,
    this.typeAc,
    this.tanggalService,
    this.saran,
    this.namaPenerima,
    this.status,
    this.photos = const [],
    this.items = const [],
  });

  final int id;
  final int? rumahSakitId;
  final int? ruanganId;
  final String? rumahSakit;
  final String? ruangan;
  final String? gedung;
  final String? merkAc;
  final String? typeAc;
  final String? tanggalService;
  final String? saran;
  final String? namaPenerima;
  final String? status;
  final List<ReportPhotoModel> photos;
  final List<ReportItemModel> items;

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    final rumahSakit =
        _nestedName(json['rumah_sakit']) ??
        _nestedName(json['rumahSakit']) ??
        _nestedName(json['rs']) ??
        json['rumah_sakit_nama']?.toString() ??
        json['nama_rumah_sakit']?.toString() ??
        json['nama_rs']?.toString() ??
        json['rumah_sakit_id']?.toString();
    final ruangan =
        _nestedName(json['ruangan']) ??
        _nestedName(json['room']) ??
        json['ruangan_nama']?.toString() ??
        json['nama_ruangan']?.toString() ??
        json['ruangan_id']?.toString();
    final acUnit = _map(json['ac_unit'] ?? json['ac']);

    return ReportModel(
      id: _toInt(json['id']),
      rumahSakitId: _nullableInt(json['rumah_sakit_id']),
      ruanganId: _nullableInt(json['ruangan_id']),
      rumahSakit: rumahSakit,
      ruangan: ruangan,
      gedung: json['gedung']?.toString(),
      merkAc:
          json['merk_ac']?.toString() ??
          json['merk']?.toString() ??
          acUnit?['merk_ac']?.toString() ??
          acUnit?['merk']?.toString(),
      typeAc:
          json['type_ac']?.toString() ??
          json['type']?.toString() ??
          acUnit?['type_ac']?.toString() ??
          acUnit?['type']?.toString(),
      tanggalService:
          json['tanggal_service']?.toString() ??
          json['tgl_service']?.toString() ??
          json['tanggal']?.toString(),
      saran: json['saran']?.toString(),
      namaPenerima:
          json['nama_penerima']?.toString() ??
          json['penerima']?.toString() ??
          json['receiver_name']?.toString(),
      status: json['status']?.toString(),
      photos:
          _list(
            json['photos'] ?? json['general_photos'] ?? json['foto_umum'],
          ).map((item) => ReportPhotoModel.fromJson(item)).toList(),
      items:
          _list(
            json['items'] ?? json['checklists'] ?? json['pemeriksaan'],
          ).map((item) => ReportItemModel.fromJson(item)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'rumah_sakit_id': rumahSakitId,
    'ruangan_id': ruanganId,
    'rumah_sakit': rumahSakit,
    'ruangan': ruangan,
    'gedung': gedung,
    'merk_ac': merkAc,
    'type_ac': typeAc,
    'tanggal_service': tanggalService,
    'saran': saran,
    'nama_penerima': namaPenerima,
    'status': status,
    'photos': photos.map((p) => p.toJson()).toList(),
    'items': items.map((i) => i.toJson()).toList(),
  };

  static String? _nestedName(dynamic value) {
    if (value is Map) return (value['nama'] ?? value['name'])?.toString();
    return value?.toString();
  }
}

class ReportItemModel {
  const ReportItemModel({
    required this.nomor,
    required this.nama,
    required this.isNormal,
    this.value,
    this.keterangan,
    this.photos = const [],
  });

  final String nomor;
  final String nama;
  final bool isNormal;
  final String? value;
  final String? keterangan;
  final List<ReportPhotoModel> photos;

  factory ReportItemModel.fromJson(Map<String, dynamic> json) {
    final pemeriksaan = _map(
      json['pemeriksaan'] ??
          json['pemeriksaan_item'] ??
          json['checklist'] ??
          json['item'],
    );
    final rawValue =
        json['value'] ??
        json['nilai'] ??
        json['status_pemeriksaan'] ??
        json['hasil'] ??
        json['is_normal'];
    final normalizedValue = rawValue?.toString().toLowerCase();
    final isNormal =
        rawValue == null ||
        rawValue == true ||
        rawValue?.toString() == '1' ||
        normalizedValue == 'true' ||
        normalizedValue == 'normal' ||
        normalizedValue == 'ok';

    return ReportItemModel(
      nomor:
          (json['nomor'] ?? pemeriksaan?['nomor'] ?? json['id'] ?? '')
              .toString(),
      nama:
          (json['nama'] ??
                  json['nama_pemeriksaan'] ??
                  pemeriksaan?['nama'] ??
                  pemeriksaan?['name'] ??
                  pemeriksaan?['pemeriksaan'] ??
                  '-')
              .toString(),
      isNormal: isNormal,
      value: rawValue?.toString(),
      keterangan: json['keterangan']?.toString(),
      photos:
          _list(
            json['photos'] ?? json['foto'] ?? json['item_photos'],
          ).map((item) => ReportPhotoModel.fromJson(item)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'nomor': nomor,
    'nama': nama,
    'is_normal': isNormal,
    'value': value,
    'keterangan': keterangan,
    'photos': photos.map((p) => p.toJson()).toList(),
  };
}

class ReportPhotoModel {
  const ReportPhotoModel({required this.url, this.caption});

  final String url;
  final String? caption;

  factory ReportPhotoModel.fromJson(Map<String, dynamic> json) {
    return ReportPhotoModel(
      url: (json['photo_url'] ?? json['url'] ?? '').toString(),
      caption: json['caption']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {'url': url, 'caption': caption};
}

List<Map<String, dynamic>> _list(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  return const [];
}

Map<String, dynamic>? _map(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value == 0 ? null : value;
  final parsed = int.tryParse(value.toString());
  if (parsed == null || parsed == 0) return null;
  return parsed;
}
