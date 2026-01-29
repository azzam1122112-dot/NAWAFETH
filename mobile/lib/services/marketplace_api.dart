import 'dart:io';

import 'package:dio/dio.dart';
import '../models/offer.dart';
import 'api_config.dart';
import 'api_dio.dart';
import 'dio_proxy.dart';
import 'session_storage.dart';

class MarketplaceApi {
  final Dio _dio;
  final SessionStorage _session;

  MarketplaceApi({Dio? dio, SessionStorage? session})
      : _dio = dio ?? ApiDio.dio,
        _session = session ?? const SessionStorage() {
    configureDioForLocalhost(_dio, ApiConfig.baseUrl);
  }

  Future<bool> createRequest({
    required int subcategoryId,
    required String title,
    required String description,
    required String requestType,
    required String city,
    List<File>? images,
    List<File>? videos,
    List<File>? files,
    String? audioPath,
  }) async {
    final token = await _session.readAccessToken();
    if (token == null) return false;

    try {
      final formData = FormData.fromMap({
        'subcategory': subcategoryId,
        'title': title,
        'description': description,
        'request_type': requestType,
        'city': city,
      });

      // Add Images
      if (images != null) {
        for (var file in images) {
          formData.files.add(MapEntry(
            'images',
            await MultipartFile.fromFile(file.path),
          ));
        }
      }

      // Add Videos
      if (videos != null) {
        for (var file in videos) {
          formData.files.add(MapEntry(
            'videos',
            await MultipartFile.fromFile(file.path),
          ));
        }
      }

      // Add Files
      if (files != null) {
        for (var file in files) {
          formData.files.add(MapEntry(
            'files',
            await MultipartFile.fromFile(file.path),
          ));
        }
      }

      // Add Audio
      if (audioPath != null) {
        formData.files.add(MapEntry(
          'audio',
          await MultipartFile.fromFile(audioPath),
        ));
      }

      await _dio.post(
        '${ApiConfig.apiPrefix}/marketplace/requests/create/',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            // Content-Type is set automatically by Dio for FormData
          },
        ),
      );
      return true;
    } catch (e) {
      // debugPrint('Create Request Error: $e');
      return false;
    }
  }

  Future<List<dynamic>> getMyRequests() async {
    final token = await _session.readAccessToken();
    if (token == null) return [];

    try {
      final response = await _dio.get(
        '${ApiConfig.apiPrefix}/marketplace/client/requests/',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<List<Offer>> getRequestOffers(String requestId) async {
    final token = await _session.readAccessToken();
    if (token == null) return [];

    try {
      final response = await _dio.get(
        '${ApiConfig.apiPrefix}/marketplace/requests/$requestId/offers/',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      return (response.data as List).map((e) => Offer.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> acceptOffer(int offerId) async {
    final token = await _session.readAccessToken();
    if (token == null) return false;

    try {
      await _dio.post(
        '${ApiConfig.apiPrefix}/marketplace/offers/$offerId/accept/',
        data: {},
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}
