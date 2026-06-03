import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  AuthService({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  Future<UserModel> login({
    required String username,
    required String password,
  }) async {
    final json = await _apiService.post(
      '/login',
      body: {'username': username, 'password': password},
    );

    final token =
        (json['access_token'] ??
                json['token'] ??
                (json['data'] is Map ? json['data']['access_token'] : null))
            ?.toString();

    if (token == null || token.isEmpty) {
      throw ApiException('Token login tidak ditemukan.');
    }

    await _apiService.saveToken(token);
    final user = _parseUser(json) ?? await me();

    if (!user.isTeknisi) {
      await _apiService.clearToken();
      throw ApiException('Akun ini bukan teknisi.');
    }

    return user;
  }

  Future<UserModel?> restoreSession() async {
    final token = await _apiService.getToken();
    if (token == null || token.isEmpty) return null;

    try {
      final user = await me();
      if (!user.isTeknisi) {
        await _apiService.clearToken();
        return null;
      }
      return user;
    } catch (_) {
      await _apiService.clearToken();
      return null;
    }
  }

  Future<UserModel> me() async {
    final json = await _apiService.get('/me');
    final user = _parseUser(json);
    if (user == null) {
      throw ApiException('Data user tidak ditemukan.');
    }
    return user;
  }

  Future<void> logout() async {
    try {
      await _apiService.post('/logout');
    } finally {
      await _apiService.clearToken();
    }
  }

  UserModel? _parseUser(Map<String, dynamic> json) {
    final dynamic raw =
        json['user'] ??
        (json['data'] is Map && json['data']['user'] != null
            ? json['data']['user']
            : json['data']);
    if (raw is Map) {
      return UserModel.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }
}
