import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/session_storage.dart';

class WhatsAppHelper {
  static String _normalizeDigits(String input) {
    const map = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
      '۰': '0',
      '۱': '1',
      '۲': '2',
      '۳': '3',
      '۴': '4',
      '۵': '5',
      '۶': '6',
      '۷': '7',
      '۸': '8',
      '۹': '9',
    };
    return input.split('').map((c) => map[c] ?? c).join();
  }

  static String? normalizePhone(String? raw) {
    final extracted = _extractContact(raw);
    if (extracted == null) return null;

    var digits = _normalizeDigits(extracted).replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('+')) {
      digits = digits.substring(1);
    }

    if (RegExp(r'^05\d{8}$').hasMatch(digits)) {
      return '966${digits.substring(1)}';
    }
    if (RegExp(r'^5\d{8}$').hasMatch(digits)) {
      return '966$digits';
    }
    if (RegExp(r'^9665\d{8}$').hasMatch(digits)) {
      return digits;
    }

    if (digits.length >= 9) {
      return digits;
    }
    return null;
  }

  static String? toWaMeLink(String? raw) {
    final phone = normalizePhone(raw);
    if (phone == null) return null;
    return 'https://wa.me/$phone';
  }

  static Future<bool> open({
    required BuildContext context,
    String? contact,
    String? message,
    String? fallbackContact,
  }) async {
    final fallback = fallbackContact ?? await const SessionStorage().readPhone();
    final waPhone = normalizePhone(contact) ?? normalizePhone(fallback);
    if (waPhone == null) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رقم واتساب غير متاح')),
      );
      return false;
    }

    final encoded = Uri.encodeComponent((message ?? '').trim());
    final appUri = Uri.parse('whatsapp://send?phone=$waPhone&text=$encoded');
    final webUri = Uri.parse('https://wa.me/$waPhone?text=$encoded');

    try {
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (_) {}

    try {
      if (await launchUrl(webUri, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {}

    try {
      await Clipboard.setData(ClipboardData(text: webUri.toString()));
    } catch (_) {}

    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر فتح واتساب، تم نسخ الرابط')),
    );
    return false;
  }

  static String? _extractContact(String? raw) {
    final text = _normalizeDigits((raw ?? '').trim());
    if (text.isEmpty) return null;

    final decoded = Uri.decodeFull(text);
    final uri = Uri.tryParse(decoded);
    if (uri == null || !uri.hasScheme) return decoded;

    final host = uri.host.toLowerCase();
    final isWhatsAppHost = host.contains('wa.me') || host.contains('whatsapp.com');
    if (!isWhatsAppHost) return decoded;

    final fromQuery = (uri.queryParameters['phone'] ?? '').trim();
    if (fromQuery.isNotEmpty) return fromQuery;

    for (final segment in uri.pathSegments) {
      final s = segment.trim();
      if (s.isNotEmpty) return s;
    }
    return decoded;
  }
}
