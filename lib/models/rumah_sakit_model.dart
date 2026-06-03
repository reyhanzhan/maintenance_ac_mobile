class RumahSakitModel {
  const RumahSakitModel({required this.id, required this.nama, this.alamat});

  final int id;
  final String nama;
  final String? alamat;

  factory RumahSakitModel.fromJson(Map<String, dynamic> json) {
    return RumahSakitModel(
      id: _toInt(json['id']),
      nama: (json['nama'] ?? json['name'] ?? '-').toString(),
      alamat: json['alamat']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'nama': nama, 'alamat': alamat};
}

class RuanganModel {
  const RuanganModel({
    required this.id,
    required this.rumahSakitId,
    required this.nama,
  });

  final int id;
  final int rumahSakitId;
  final String nama;

  factory RuanganModel.fromJson(
    Map<String, dynamic> json, {
    int? fallbackRumahSakitId,
  }) {
    int ruangId = 0;
    // Try to get from nested rumah_sakit object first
    final nestedRs = json['rumah_sakit'];
    if (nestedRs is Map) {
      ruangId = _toInt(nestedRs['id']);
    }
    // If nested didn't give us an ID, try flat field
    if (ruangId == 0) {
      ruangId = _toInt(json['rumah_sakit_id']);
    }
    if (ruangId == 0 && fallbackRumahSakitId != null) {
      ruangId = fallbackRumahSakitId;
    }
    return RuanganModel(
      id: _toInt(json['id']),
      rumahSakitId: ruangId,
      nama: (json['nama'] ?? json['name'] ?? '-').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'rumah_sakit_id': rumahSakitId,
    'nama': nama,
  };
}

class AcUnitModel {
  const AcUnitModel({
    required this.id,
    required this.ruanganId,
    this.merk,
    this.type,
  });

  final int id;
  final int ruanganId;
  final String? merk;
  final String? type;

  factory AcUnitModel.fromJson(Map<String, dynamic> json) {
    int ruangId = 0;
    // Try to get from nested ruangan object first
    final nestedRuang = json['ruangan'];
    if (nestedRuang is Map) {
      ruangId = _toInt(nestedRuang['id']);
    }
    // If nested didn't give us an ID, try flat field
    if (ruangId == 0) {
      ruangId = _toInt(json['ruangan_id']);
    }
    return AcUnitModel(
      id: _toInt(json['id']),
      ruanganId: ruangId,
      merk: json['merk_ac']?.toString() ?? json['merk']?.toString(),
      type: json['type_ac']?.toString() ?? json['type']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'ruangan_id': ruanganId,
    'merk_ac': merk,
    'type_ac': type,
  };
}

class PemeriksaanItemModel {
  const PemeriksaanItemModel({
    required this.nomor,
    required this.nama,
    this.desc,
  });

  final String nomor;
  final String nama;
  final String? desc;

  factory PemeriksaanItemModel.fromJson(Map<String, dynamic> json) {
    return PemeriksaanItemModel(
      nomor: (json['nomor'] ?? json['id'] ?? '').toString(),
      nama:
          (json['nama'] ?? json['name'] ?? json['pemeriksaan'] ?? '-')
              .toString(),
      desc: json['desc']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {'nomor': nomor, 'nama': nama, 'desc': desc};
}

class SyncData {
  const SyncData({
    required this.rumahSakits,
    required this.ruangans,
    required this.ruangansByRumahSakitId,
    required this.acUnits,
    required this.pemeriksaanDefault,
    required this.pemeriksaanSiloamBaru,
  });

  final List<RumahSakitModel> rumahSakits;
  final List<RuanganModel> ruangans;
  final Map<int, List<RuanganModel>> ruangansByRumahSakitId;
  final List<AcUnitModel> acUnits;
  final List<PemeriksaanItemModel> pemeriksaanDefault;
  final List<PemeriksaanItemModel> pemeriksaanSiloamBaru;

  factory SyncData.fromJson(Map<String, dynamic> json) {
    final data =
        json['data'] is Map<String, dynamic>
            ? json['data'] as Map<String, dynamic>
            : json;

    final List<RumahSakitModel> rumahSakits = <RumahSakitModel>[];
    final List<RuanganModel> ruangans = <RuanganModel>[];
    final List<AcUnitModel> acUnits = <AcUnitModel>[];

    final rawRumahSakits = _list(data['rumah_sakits']);
    for (final rawRs in rawRumahSakits) {
      // Add the RS model (without ruangans and ac_units)
      final rumahSakit = RumahSakitModel.fromJson(rawRs);
      rumahSakits.add(rumahSakit);

      // Extract ruangans from this RS
      final rawRuangans = _list(rawRs['ruangans']);
      for (final rawRuang in rawRuangans) {
        ruangans.add(
          RuanganModel.fromJson(rawRuang, fallbackRumahSakitId: rumahSakit.id),
        );
      }

      // Extract ac_units from this RS
      final rawAcUnits = _list(rawRs['ac_units']);
      for (final rawAcUnit in rawAcUnits) {
        acUnits.add(AcUnitModel.fromJson(rawAcUnit));
      }
    }

    for (final rawRuangan in _list(data['ruangans'])) {
      final ruangan = RuanganModel.fromJson(rawRuangan);
      if (!ruangans.any((item) => item.id == ruangan.id)) {
        ruangans.add(ruangan);
      }
    }

    for (final rawAcUnit in _list(data['ac_units'])) {
      final acUnit = AcUnitModel.fromJson(rawAcUnit);
      if (!acUnits.any((item) => item.id == acUnit.id)) {
        acUnits.add(acUnit);
      }
    }

    final pemeriksaanDefault =
        _list(
          data['pemeriksaan_default'],
        ).map((item) => PemeriksaanItemModel.fromJson(item)).toList();
    final pemeriksaanSiloamBaru =
        _list(
          data['pemeriksaan_siloam_baru'],
        ).map((item) => PemeriksaanItemModel.fromJson(item)).toList();
    final ruangansByRumahSakitId = <int, List<RuanganModel>>{};
    for (final ruangan in ruangans) {
      ruangansByRumahSakitId
          .putIfAbsent(ruangan.rumahSakitId, () => <RuanganModel>[])
          .add(ruangan);
    }

    return SyncData(
      rumahSakits: rumahSakits,
      ruangans: ruangans,
      ruangansByRumahSakitId: ruangansByRumahSakitId,
      acUnits: acUnits,
      pemeriksaanDefault: pemeriksaanDefault,
      pemeriksaanSiloamBaru: pemeriksaanSiloamBaru,
    );
  }

  Map<String, dynamic> toJson() => {
    'rumah_sakits': rumahSakits.map((r) => r.toJson()).toList(),
    'ruangans': ruangans.map((r) => r.toJson()).toList(),
    'ruangansByRumahSakitId': ruangansByRumahSakitId.map(
      (k, v) => MapEntry(k.toString(), v.map((r) => r.toJson()).toList()),
    ),
    'ac_units': acUnits.map((a) => a.toJson()).toList(),
    'pemeriksaan_default': pemeriksaanDefault.map((p) => p.toJson()).toList(),
    'pemeriksaan_siloam_baru':
        pemeriksaanSiloamBaru.map((p) => p.toJson()).toList(),
  };

  static List<Map<String, dynamic>> _list(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }
}

int _toInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
