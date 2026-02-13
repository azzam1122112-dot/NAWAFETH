import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_error.dart';

void main() {
  group('ApiError.fromDio', () {
    test('parses validation message from detail', () {
      final ex = DioException(
        requestOptions: RequestOptions(path: '/x'),
        response: Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 400,
          data: {'detail': 'البيانات غير صحيحة'},
        ),
        type: DioExceptionType.badResponse,
      );

      final err = ApiError.fromDio(ex);
      expect(err.type, ApiErrorType.validation);
      expect(err.messageAr, 'البيانات غير صحيحة');
      expect(err.statusCode, 400);
    });

    test('maps network timeout to network error', () {
      final ex = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionTimeout,
      );

      final err = ApiError.fromDio(ex);
      expect(err.type, ApiErrorType.network);
    });
  });
}
