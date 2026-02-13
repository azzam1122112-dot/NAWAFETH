import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/api_config.dart';
import '../permissions/permissions_service.dart';
import 'api_client.dart';
import 'api_error.dart';

typedef UploadProgress = void Function(double progress);

class FeatureUploadResult {
  final bool ok;
  final String messageAr;
  final int? ticketId;
  final String? fileUrl;
  final String? fileName;

  const FeatureUploadResult({
    required this.ok,
    required this.messageAr,
    this.ticketId,
    this.fileUrl,
    this.fileName,
  });
}

class FeatureLocationResult {
  final bool ok;
  final String messageAr;
  final int? ticketId;
  final Map<String, dynamic>? payload;

  const FeatureLocationResult({
    required this.ok,
    required this.messageAr,
    this.ticketId,
    this.payload,
  });
}

class DeviceFeaturesApi {
  DeviceFeaturesApi({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  final Dio _dio;
  int? _cachedSupportTicketId;
  int? _cachedMaxUploadMb;

  static const int defaultMaxUploadBytes = 10 * 1024 * 1024; // 10MB fallback

  static const Set<String> _imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
  };

  static const Set<String> _audioExtensions = {
    'aac',
    'm4a',
    'mp3',
    'wav',
    'ogg',
  };

  static const Set<String> _docExtensions = {
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'txt',
    'zip',
    'rar',
    '7z',
    'png',
    'jpg',
    'jpeg',
  };

  Future<FeatureUploadResult> uploadImage({
    required File file,
    UploadProgress? onProgress,
  }) async {
    final error = await _validateByType(file, _imageExtensions);
    if (error != null) {
      return FeatureUploadResult(ok: false, messageAr: error);
    }
    return _uploadToSupportTicket(file: file, onProgress: onProgress);
  }

  Future<FeatureUploadResult> uploadAudio({
    required File file,
    UploadProgress? onProgress,
  }) async {
    final error = await _validateByType(file, _audioExtensions);
    if (error != null) {
      return FeatureUploadResult(ok: false, messageAr: error);
    }
    return _uploadToSupportTicket(file: file, onProgress: onProgress);
  }

  Future<FeatureUploadResult> uploadDocument({
    required File file,
    UploadProgress? onProgress,
  }) async {
    final error = await _validateByType(file, _docExtensions);
    if (error != null) {
      return FeatureUploadResult(ok: false, messageAr: error);
    }
    return _uploadToSupportTicket(file: file, onProgress: onProgress);
  }

  Future<FeatureLocationResult> submitCurrentLocation() async {
    try {
      final permission = await PermissionsService.ensureLocationWhenInUse();
      if (!permission.isGranted) {
        return FeatureLocationResult(
          ok: false,
          messageAr: permission.messageAr,
        );
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final payload = <String, dynamic>{
        'lat': double.parse(pos.latitude.toStringAsFixed(6)),
        'lng': double.parse(pos.longitude.toStringAsFixed(6)),
        'accuracy': pos.accuracy,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };

      final ticketId = await _ensureSupportTicket();
      await _dio.post(
        '${ApiConfig.apiPrefix}/support/tickets/$ticketId/comments/',
        data: {
          'text': jsonEncode(payload),
          'is_internal': false,
        },
      );

      return FeatureLocationResult(
        ok: true,
        messageAr: 'تم إرسال الموقع بنجاح.',
        ticketId: ticketId,
        payload: payload,
      );
    } catch (e) {
      final err = ApiClient.mapError(e);
      return FeatureLocationResult(ok: false, messageAr: err.messageAr);
    }
  }

  Future<FeatureUploadResult> _uploadToSupportTicket({
    required File file,
    UploadProgress? onProgress,
  }) async {
    try {
      final ticketId = await _ensureSupportTicket();
      final safeName = sanitizeFilename(file.path.split(Platform.pathSeparator).last);

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: safeName,
        ),
      });

      final res = await _dio.post(
        '${ApiConfig.apiPrefix}/support/tickets/$ticketId/attachments/',
        data: formData,
        onSendProgress: (sent, total) {
          if (onProgress == null || total <= 0) return;
          onProgress((sent / total).clamp(0, 1).toDouble());
        },
      );

      final map = _asMap(res.data);
      return FeatureUploadResult(
        ok: true,
        messageAr: 'تم رفع الملف بنجاح.',
        ticketId: ticketId,
        fileUrl: map?['file']?.toString(),
        fileName: safeName,
      );
    } catch (e) {
      final err = ApiClient.mapError(e);
      return FeatureUploadResult(ok: false, messageAr: err.messageAr);
    }
  }

  Future<String?> _validateByType(File file, Set<String> allowedExtensions) async {
    final maxBytes = await _resolveMaxUploadBytes();
    return validateUploadFile(
      file,
      allowedExtensions,
      maxBytes: maxBytes,
    );
  }

  Future<int> _resolveMaxUploadBytes() async {
    if (_cachedMaxUploadMb != null && _cachedMaxUploadMb! > 0) {
      return _cachedMaxUploadMb! * 1024 * 1024;
    }

    try {
      final res = await _dio.get('${ApiConfig.apiPrefix}/features/my/');
      final data = _asMap(res.data);
      final mb = _asInt(data?['max_upload_mb']);
      if (mb != null && mb > 0) {
        _cachedMaxUploadMb = mb;
        return mb * 1024 * 1024;
      }
    } catch (_) {
      // fallback only
    }

    return defaultMaxUploadBytes;
  }

  Future<int> _ensureSupportTicket() async {
    if (_cachedSupportTicketId != null) {
      return _cachedSupportTicketId!;
    }

    final res = await _dio.post(
      '${ApiConfig.apiPrefix}/support/tickets/create/',
      data: const {
        'ticket_type': 'tech',
        'description': 'Device feature session upload',
        'priority': 'normal',
      },
    );

    final data = _asMap(res.data);
    final id = data?['id'];
    if (id is int) {
      _cachedSupportTicketId = id;
      return id;
    }
    if (id is String) {
      final parsed = int.tryParse(id.trim());
      if (parsed != null) {
        _cachedSupportTicketId = parsed;
        return parsed;
      }
    }

    throw const ApiError(
      type: ApiErrorType.server,
      messageAr: 'تعذر إنشاء تذكرة الرفع.',
    );
  }

  static String sanitizeFilename(String raw) {
    final name = raw.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (name.isEmpty) return 'upload.bin';
    if (name.length > 120) {
      final ext = _fileExtension(name);
      final base = name.substring(0, 100);
      if (ext == null) return base;
      return '$base.$ext';
    }
    return name;
  }

  static String? validateUploadFile(
    File file,
    Set<String> allowedExtensions, {
    int? maxBytes,
  }) {
    if (!file.existsSync()) return 'الملف غير موجود.';

    final size = file.lengthSync();
    if (size <= 0) return 'الملف فارغ.';

    final limit = maxBytes ?? defaultMaxUploadBytes;
    if (size > limit) {
      final mb = (limit / (1024 * 1024)).round();
      return 'حجم الملف أكبر من ${mb}MB.';
    }

    final ext = _fileExtension(file.path);
    if (ext == null || !allowedExtensions.contains(ext)) {
      return 'نوع الملف غير مدعوم.';
    }

    return null;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static String? _fileExtension(String path) {
    final idx = path.lastIndexOf('.');
    if (idx < 0 || idx == path.length - 1) return null;
    return path.substring(idx + 1).toLowerCase();
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }
}
