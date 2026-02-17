import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'billing_api.dart';

class PaymentCheckout {
  static Future<bool> initAndOpen({
    required BuildContext context,
    required BillingApi billingApi,
    required int invoiceId,
    String provider = 'default',
    String? idempotencyKey,
    String? successMessage,
  }) async {
    try {
      final payment = await billingApi.initPayment(
        invoiceId: invoiceId,
        provider: provider,
        idempotencyKey: idempotencyKey,
      );

      final checkoutUrl = (payment['checkout_url'] ?? '').toString().trim();
      if (checkoutUrl.isEmpty) {
        if (!context.mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت تهيئة الدفع لكن رابط الدفع غير متوفر حالياً.')),
        );
        return false;
      }

      final launched = await launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);
      if (!context.mounted) return launched;

      if (launched) {
        if ((successMessage ?? '').trim().isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage!.trim())));
        }
        return true;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح صفحة الدفع تلقائياً.')),
      );
      return false;
    } on DioException catch (e) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_extractMessage(e))));
      return false;
    } catch (_) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر بدء عملية الدفع حالياً.')),
      );
      return false;
    }
  }

  static String _extractMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) return detail.trim();
      for (final value in data.values) {
        if (value is String && value.trim().isNotEmpty) return value.trim();
        if (value is List && value.isNotEmpty && value.first is String) {
          final first = (value.first as String).trim();
          if (first.isNotEmpty) return first;
        }
      }
    }
    return 'تعذر بدء عملية الدفع حالياً.';
  }
}
