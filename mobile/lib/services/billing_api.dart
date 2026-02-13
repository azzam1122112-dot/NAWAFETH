import 'package:dio/dio.dart';

import '../core/network/api_dio.dart';
import 'api_config.dart';
import 'dio_proxy.dart';

class BillingApi {
  final Dio _dio;

  BillingApi({Dio? dio}) : _dio = dio ?? ApiDio.dio {
    configureDioForLocalhost(_dio, ApiConfig.baseUrl);
  }

  Future<Map<String, dynamic>> createInvoice(Map<String, dynamic> payload) async {
    final res = await _dio.post(
      '${ApiConfig.apiPrefix}/billing/invoices/',
      data: payload,
    );
    return _asMap(res.data);
  }

  Future<List<Map<String, dynamic>>> getMyInvoices() async {
    final res = await _dio.get('${ApiConfig.apiPrefix}/billing/invoices/my/');
    final data = res.data;
    if (data is List) {
      return data.map((e) => _asMap(e)).toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> getInvoiceDetail(int invoiceId) async {
    final res = await _dio.get('${ApiConfig.apiPrefix}/billing/invoices/$invoiceId/');
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> initPayment({
    required int invoiceId,
    required String provider,
    String? idempotencyKey,
  }) async {
    final res = await _dio.post(
      '${ApiConfig.apiPrefix}/billing/invoices/$invoiceId/init-payment/',
      data: {
        'provider': provider,
        if ((idempotencyKey ?? '').trim().isNotEmpty) 'idempotency_key': idempotencyKey,
      },
    );
    return _asMap(res.data);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }
}
