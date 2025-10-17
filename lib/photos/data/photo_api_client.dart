import 'package:dio/dio.dart';

import 'photo.dart';

/// Minimal client responsible for talking to the remote photo API.
class PhotoApiClient {
  PhotoApiClient({Dio? dio}) : _dio = dio ?? Dio();

  static const _endpoint =
      'https://qchkdevhiring.blob.core.windows.net/mobile/api/photos';

  final Dio _dio;

  /// Issues a GET request and converts the payload into a list of [Photo]s.
  Future<List<Photo>> fetchPhotos() async {
    try {
      final response = await _dio.get<List<dynamic>>(_endpoint);
      final data = response.data;
      if (data == null) {
        throw const PhotoApiException('API returned an empty payload');
      }
      return data
          .map((raw) {
            return Photo.fromJson(raw as Map<String, dynamic>);
          })
          .toList(growable: false);
    } on DioException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PhotoApiException(error.message ?? 'Dio request failed'),
        stackTrace,
      );
    } on TypeError catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PhotoApiException('Unexpected response format: $error'),
        stackTrace,
      );
    }
  }
}

/// Exception thrown whenever API interaction fails.
class PhotoApiException implements Exception {
  const PhotoApiException(this.message);

  /// Human readable failure reason.
  final String message;

  @override
  String toString() => 'PhotoApiException: $message';
}
