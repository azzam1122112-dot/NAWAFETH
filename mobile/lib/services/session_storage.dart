import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStorage {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static const _phoneKey = 'phone';
  static const _usernameKey = 'username';
  static const _emailKey = 'email';
  static const _firstNameKey = 'first_name';
  static const _lastNameKey = 'last_name';
  static const _securityCodeKey = 'security_code';
  static const _faceIdCodeKey = 'face_id_code';

  final FlutterSecureStorage _secure;

  const SessionStorage({FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage();

  Future<void> saveTokens({required String access, required String refresh}) async {
    await _secure.write(key: _accessKey, value: access);
    await _secure.write(key: _refreshKey, value: refresh);
  }

  Future<String?> readAccessToken() => _secure.read(key: _accessKey);
  Future<String?> readRefreshToken() => _secure.read(key: _refreshKey);

  Future<void> saveUserId(int userId) => _secure.write(key: _userIdKey, value: userId.toString());

  Future<int?> readUserId() async {
    final raw = await _secure.read(key: _userIdKey);
    if (raw == null) return null;
    return int.tryParse(raw.trim());
  }

  Future<void> savePhone(String phone) => _secure.write(key: _phoneKey, value: phone);
  Future<String?> readPhone() => _secure.read(key: _phoneKey);

  Future<void> saveProfile({
    int? userId,
    String? username,
    String? email,
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    if (userId != null) {
      await _secure.write(key: _userIdKey, value: userId.toString());
    }
    if (username != null) {
      await _secure.write(key: _usernameKey, value: username);
    }
    if (email != null) {
      await _secure.write(key: _emailKey, value: email);
    }
    if (firstName != null) {
      await _secure.write(key: _firstNameKey, value: firstName);
    }
    if (lastName != null) {
      await _secure.write(key: _lastNameKey, value: lastName);
    }
    if (phone != null) {
      await _secure.write(key: _phoneKey, value: phone);
    }
  }

  Future<String?> readUsername() => _secure.read(key: _usernameKey);
  Future<String?> readEmail() => _secure.read(key: _emailKey);

  Future<String?> readFirstName() => _secure.read(key: _firstNameKey);
  Future<String?> readLastName() => _secure.read(key: _lastNameKey);

  Future<String?> readFullName() async {
    final first = (await readFirstName())?.trim();
    final last = (await readLastName())?.trim();
    final parts = [
      if (first != null && first.isNotEmpty) first,
      if (last != null && last.isNotEmpty) last,
    ];
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  Future<bool> isLoggedIn() async {
    final token = await readAccessToken();
    return token != null && token.trim().isNotEmpty;
  }

  Future<void> saveSecurityCode(String code) => _secure.write(key: _securityCodeKey, value: code);
  Future<String?> readSecurityCode() => _secure.read(key: _securityCodeKey);

  Future<void> saveFaceIdCode(String code) => _secure.write(key: _faceIdCodeKey, value: code);
  Future<String?> readFaceIdCode() => _secure.read(key: _faceIdCodeKey);

  Future<void> clear() async {
    await _secure.delete(key: _accessKey);
    await _secure.delete(key: _refreshKey);
    await _secure.delete(key: _userIdKey);
    await _secure.delete(key: _phoneKey);
    await _secure.delete(key: _usernameKey);
    await _secure.delete(key: _emailKey);
    await _secure.delete(key: _firstNameKey);
    await _secure.delete(key: _lastNameKey);
    await _secure.delete(key: _securityCodeKey);
    await _secure.delete(key: _faceIdCodeKey);
  }
}
