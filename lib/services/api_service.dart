import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/report_model.dart';
import '../models/rumah_sakit_model.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class ApiService {
  static const String _tokenKey = 'access_token';

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<Map<String, dynamic>> get(String path) async {
    final response = await http.get(_uri(path), headers: await _headers());
    return _decode(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await http.post(
      _uri(path),
      headers: await _headers(jsonBody: true),
      body: jsonEncode(body ?? {}),
    );
    return _decode(response);
  }

  Future<void> postMultipartReport({
    required Map<String, String> fields,
    required Map<String, ItemPayload> items,
    required List<XFile> generalPhotos,
    required Map<String, List<XFile>> itemPhotos,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/teknisi/reports'));
    final token = await getToken();
    request.headers.addAll({
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    });

    request.fields.addAll(fields);
    for (final entry in items.entries) {
      request.fields['items[${entry.key}][is_normal]'] =
          entry.value.isNormal ? '1' : '0';
      if (entry.value.keterangan.trim().isNotEmpty) {
        request.fields['items[${entry.key}][keterangan]'] =
            entry.value.keterangan.trim();
      }
    }

    for (final photo in generalPhotos) {
      request.files.add(await _multipartFile('general_photos[]', photo));
    }

    for (final entry in itemPhotos.entries) {
      for (final photo in entry.value) {
        request.files.add(
          await _multipartFile('item_photos[${entry.key}][]', photo),
        );
      }
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    _decode(response);
  }

  Future<SyncData> fetchSyncData() async {
    final json = await get('/teknisi/sync');
    return SyncData.fromJson(json);
  }

  Future<List<ReportModel>> fetchReports() async {
    final json = await get('/teknisi/reports');
    final data = _extractList(json);
    return data.map((item) => ReportModel.fromJson(item)).toList();
  }

  Future<ReportModel> fetchReportDetail(int id) async {
    final json = await get('/teknisi/reports/$id');

    return ReportModel.fromJson(_extractObject(json));
  }

  Uri _uri(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('${ApiConfig.baseUrl}$normalized');
  }

  Future<Map<String, String>> _headers({bool jsonBody = false}) async {
    final token = await getToken();
    return {
      'Accept': 'application/json',
      if (jsonBody) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    final dynamic decoded =
        response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    final json =
        decoded is Map
            ? Map<String, dynamic>.from(decoded)
            : <String, dynamic>{'data': decoded};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        (json['message'] ?? 'Terjadi kesalahan server').toString(),
        response.statusCode,
      );
    }
    return json;
  }

  List<Map<String, dynamic>> _extractList(Map<String, dynamic> json) {
    final dynamic data = json['data'] ?? json['reports'] ?? json;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  Map<String, dynamic> _extractObject(Map<String, dynamic> json) {
    dynamic data = json['data'] ?? json['report'] ?? json['laporan'] ?? json;
    if (data is String) data = jsonDecode(data);

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final nested = map['data'] ?? map['report'] ?? map['laporan'];
      if (nested is Map || nested is String) {
        return _extractObject({'data': nested});
      }
      return map;
    }

    return json;
  }

  Future<http.MultipartFile> _multipartFile(String field, XFile file) async {
    if (kIsWeb) {
      return http.MultipartFile.fromBytes(
        field,
        await file.readAsBytes(),
        filename: file.name,
      );
    }
    return http.MultipartFile.fromPath(field, file.path, filename: file.name);
  }
}

class ItemPayload {
  const ItemPayload({required this.isNormal, required this.keterangan});
  final bool isNormal;
  final String keterangan;
  Map<String, dynamic> toJson() => {
    'is_normal': isNormal,
    'keterangan': keterangan,
  };
}
