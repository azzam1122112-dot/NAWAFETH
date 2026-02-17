import 'package:dio/dio.dart';

import 'api_config.dart';
import '../core/network/api_dio.dart';
import 'dio_proxy.dart';
import 'session_storage.dart';

class OtpVerifyResult {
  final bool ok;
  final bool isNewUser;
  final bool needsCompletion;
  final String access;
  final String refresh;

  const OtpVerifyResult({
    required this.ok,
    required this.isNewUser,
    required this.needsCompletion,
    required this.access,
    required this.refresh,
  });

  factory OtpVerifyResult.fromJson(Map<String, dynamic> json) {
    return OtpVerifyResult(
      ok: json['ok'] == true,
      isNewUser: json['is_new_user'] == true,
      needsCompletion: json['needs_completion'] == true,
      access: (json['access'] ?? '').toString(),
      refresh: (json['refresh'] ?? '').toString(),
    );
  }
}

class AuthApi {
  // Development mode: allow any 4-digit OTP and skip backend verification.
  static const bool _devAllowAny4DigitsOtp = true;

  final Dio _dio;

  AuthApi({Dio? dio})
      : _dio = dio ?? ApiDio.dio {
    configureDioForLocalhost(_dio, ApiConfig.baseUrl);
  }

  // New API requested (keeps existing method names for compatibility).
  Future<String?> otpSend({required String phone}) => sendOtp(phone: phone);

  Future<OtpVerifyResult> otpVerify({required String phone, required String code}) async {
    final normalized = code.trim();
    if (_devAllowAny4DigitsOtp &&
        normalized.length == 4 &&
        int.tryParse(normalized) != null) {
      const devResult = OtpVerifyResult(
        ok: true,
        isNewUser: false,
        needsCompletion: false,
        access: 'dev_access_token',
        refresh: 'dev_refresh_token',
      );
      await ApiDio.setTokens(devResult.access, devResult.refresh);
      return devResult;
    }

    final result = await verifyOtp(phone: phone, code: code);
    if (result.access.trim().isNotEmpty && result.refresh.trim().isNotEmpty) {
      await ApiDio.setTokens(result.access, result.refresh);
    }
    return result;
  }

  Future<String?> sendOtp({required String phone}) async {
    final res = await _dio.post('${ApiConfig.apiPrefix}/accounts/otp/send/', data: {
      'phone': phone,
    });

    final data = res.data;
    if (data is Map && data['dev_code'] != null) {
      return data['dev_code'].toString();
    }
    return null;
  }

  Future<OtpVerifyResult> verifyOtp({required String phone, required String code}) async {
    final res = await _dio.post('${ApiConfig.apiPrefix}/accounts/otp/verify/', data: {
      'phone': phone,
      'code': code,
    });

    if (res.data is Map<String, dynamic>) {
      return OtpVerifyResult.fromJson(res.data as Map<String, dynamic>);
    }

    return OtpVerifyResult.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  /// Used by the API test screen to corrupt access while preserving refresh.
  Future<String?> getRefreshForDebug() async {
    return const SessionStorage().readRefreshToken();
  }

  Future<void> completeRegistration({
    required String accessToken,
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    required bool acceptTerms,
    String? city,
  }) async {
    final data = {
      'first_name': firstName,
      'last_name': lastName,
      'username': username,
      'email': email,
      'password': password,
      'password_confirm': passwordConfirm,
      'accept_terms': acceptTerms,
    };
    
    if (city != null && city.isNotEmpty) {
      data['city'] = city;
    }
    
    await _dio.post(
      '${ApiConfig.apiPrefix}/accounts/complete/',
      data: data,
      options: Options(
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      ),
    );
  }
}
