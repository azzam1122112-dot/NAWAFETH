import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

enum PermissionDecision {
  granted,
  denied,
  permanentlyDenied,
  error,
}

class PermissionResult {
  final PermissionDecision decision;
  final String messageAr;

  const PermissionResult(this.decision, this.messageAr);

  bool get isGranted => decision == PermissionDecision.granted;
}

class PermissionsService {
  const PermissionsService._();

  static Future<PermissionResult> ensureCamera() async {
    return _fromStatus(
      await ph.Permission.camera.request(),
      deniedMessage: 'تم رفض إذن الكاميرا.',
      permanentlyDeniedMessage: 'تم رفض إذن الكاميرا نهائيًا. افتح إعدادات التطبيق لتفعيله.',
    );
  }

  static Future<PermissionResult> ensureMic() async {
    return _fromStatus(
      await ph.Permission.microphone.request(),
      deniedMessage: 'تم رفض إذن الميكروفون.',
      permanentlyDeniedMessage: 'تم رفض إذن الميكروفون نهائيًا. افتح إعدادات التطبيق لتفعيله.',
    );
  }

  static Future<PermissionResult> ensureLocationWhenInUse() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return const PermissionResult(
          PermissionDecision.denied,
          'خدمة الموقع غير مفعلة. يرجى تفعيل GPS من إعدادات الجهاز.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return const PermissionResult(
          PermissionDecision.permanentlyDenied,
          'تم رفض إذن الموقع نهائيًا. افتح إعدادات التطبيق لتفعيله.',
        );
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        return const PermissionResult(
          PermissionDecision.granted,
          'تم منح إذن الموقع.',
        );
      }

      return const PermissionResult(
        PermissionDecision.denied,
        'تم رفض إذن الموقع.',
      );
    } catch (_) {
      return const PermissionResult(
        PermissionDecision.error,
        'حدث خطأ أثناء طلب إذن الموقع.',
      );
    }
  }

  static Future<PermissionResult> ensureGallery() async {
    try {
      if (Platform.isIOS) {
        final status = await ph.Permission.photos.request();
        if (status.isLimited || status.isGranted) {
          return const PermissionResult(
            PermissionDecision.granted,
            'تم منح إذن الصور.',
          );
        }
        return _fromStatus(
          status,
          deniedMessage: 'تم رفض إذن الصور.',
          permanentlyDeniedMessage: 'تم رفض إذن الصور نهائيًا. افتح إعدادات التطبيق لتفعيله.',
        );
      }

      if (Platform.isAndroid) {
        final photosStatus = await ph.Permission.photos.request();
        final videosStatus = await ph.Permission.videos.request();
        if (photosStatus.isGranted || videosStatus.isGranted) {
          return const PermissionResult(
            PermissionDecision.granted,
            'تم منح إذن الوسائط.',
          );
        }

        final legacyStorage = await ph.Permission.storage.request();
        return _fromStatus(
          legacyStorage,
          deniedMessage: 'تم رفض إذن معرض الصور.',
          permanentlyDeniedMessage: 'تم رفض إذن معرض الصور نهائيًا. افتح إعدادات التطبيق لتفعيله.',
        );
      }

      return const PermissionResult(
        PermissionDecision.granted,
        'لا يحتاج هذا النظام إذنًا إضافيًا للمعرض.',
      );
    } catch (_) {
      return const PermissionResult(
        PermissionDecision.error,
        'حدث خطأ أثناء طلب إذن معرض الصور.',
      );
    }
  }

  static Future<PermissionResult> ensureFileAccess() async {
    try {
      if (Platform.isAndroid) {
        // File picker uses the system picker (SAF) and usually does not require
        // broad storage permissions on modern Android versions.
        return const PermissionResult(
          PermissionDecision.granted,
          'يمكن اختيار الملفات عبر نافذة النظام مباشرة.',
        );
      }

      if (Platform.isIOS) {
        return const PermissionResult(
          PermissionDecision.granted,
          'يمكن اختيار الملفات عبر نافذة النظام مباشرة.',
        );
      }

      return const PermissionResult(
        PermissionDecision.granted,
        'يمكن اختيار الملفات على هذا النظام.',
      );
    } catch (_) {
      return const PermissionResult(
        PermissionDecision.error,
        'حدث خطأ أثناء تهيئة إذن الملفات.',
      );
    }
  }

  static Future<bool> openAppSettingsForPermission() async {
    try {
      return ph.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  static PermissionResult _fromStatus(
    ph.PermissionStatus status, {
    required String deniedMessage,
    required String permanentlyDeniedMessage,
  }) {
    if (status.isGranted || status.isLimited) {
      return const PermissionResult(
        PermissionDecision.granted,
        'تم منح الإذن.',
      );
    }

    if (status.isPermanentlyDenied || status.isRestricted) {
      return PermissionResult(
        PermissionDecision.permanentlyDenied,
        permanentlyDeniedMessage,
      );
    }

    return PermissionResult(
      PermissionDecision.denied,
      deniedMessage,
    );
  }
}
