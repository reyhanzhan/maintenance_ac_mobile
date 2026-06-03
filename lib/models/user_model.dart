class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
  });

  final int id;
  final String name;
  final String username;
  final String role;

  bool get isTeknisi => role.toLowerCase() == 'teknisi';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: _toInt(json['id']),
      name: (json['name'] ?? json['nama'] ?? json['nama_teknisi'] ?? '-')
          .toString(),
      username: (json['username'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
