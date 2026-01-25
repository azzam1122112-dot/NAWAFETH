import 'package:dio/dio.dart';

import 'api_config.dart';
import 'dio_proxy.dart';

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
  final Dio _dio;

  AuthApi({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 20),
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            ) {
    configureDioForLocalhost(_dio, ApiConfig.baseUrl);
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

  Future<void> completeRegistration({
    required String accessToken,
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    required bool acceptTerms,
  }) async {
    await _dio.post(
      '${ApiConfig.apiPrefix}/accounts/complete/',
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'username': username,
        'email': email,
        'password': password,
        'password_confirm': passwordConfirm,
        'accept_terms': acceptTerms,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      ),
    );
  }
}
