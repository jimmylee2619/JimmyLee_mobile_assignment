import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import 'package:photo_gallery/photos/data/photo.dart';
import 'package:photo_gallery/photos/data/photo_local_data_source.dart';

class _MockDio extends Mock implements Dio {}

class _FakeRequestOptions extends Fake implements RequestOptions {}

class _FakeOptions extends Fake implements Options {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRequestOptions());
    registerFallbackValue(_FakeOptions());
  });

  group('PhotoLocalDataSource', () {
    late Directory tempDir;
    late Directory downloadsDir;
    late Dio dio;
    late PhotoLocalDataSource dataSource;
    late List<int> imageBytes;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('photo_cache_test');
      downloadsDir = Directory(p.join(tempDir.path, 'downloads'));
      dio = _MockDio();
      imageBytes = List<int>.generate(16, (index) => index);
      dataSource = PhotoLocalDataSource(
        dio: dio,
        directoryProvider: () async => tempDir,
        downloadsDirectoryProvider: () async => downloadsDir,
        fileDownloadHandler: ({
          required String url,
          required String name,
        }) async {
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }
          final target = File(p.join(downloadsDir.path, name));
          await target.writeAsBytes(imageBytes, flush: true);
          return target.path;
        },
      );

      when(
        () => dio.get<List<int>>(any(), options: any(named: 'options')),
      ).thenAnswer((invocation) async {
        final url = invocation.positionalArguments.first as String;
        return Response<List<int>>(
          data: imageBytes,
          requestOptions: RequestOptions(path: url),
        );
      });
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('savePhotos downloads images and writes metadata', () async {
      final photos = [
        Photo(
          id: '1',
          url: 'https://example.com/photo.jpg',
          description: 'desc',
          location: 'Taipei',
          createdBy: 'Alice',
          createdAt: DateTime(2024, 1, 1),
          takenAt: DateTime(2023, 12, 1),
        ),
      ];

      final stored = await dataSource.savePhotos(photos);

      expect(stored, hasLength(1));
      final cached = stored.first.localImagePath;
      expect(cached, isNotNull);
      expect(File(cached!).existsSync(), isTrue);

      final metadataFile = File(p.join(tempDir.path, 'photos-cache.json'));
      expect(metadataFile.existsSync(), isTrue);
      expect(
        metadataFile.readAsStringSync().contains('localImagePath'),
        isTrue,
      );
    });

    test('readPhotos reconstructs photos from disk cache', () async {
      final photos = [
        Photo(
          id: '1',
          url: 'https://example.com/photo.jpg',
          description: 'desc',
          location: 'Taipei',
          createdBy: 'Alice',
          createdAt: DateTime(2024, 1, 1),
          takenAt: DateTime(2023, 12, 1),
        ),
      ];

      await dataSource.savePhotos(photos);

      final result = await dataSource.readPhotos();

      expect(result, isNotNull);
      expect(result, hasLength(1));
      expect(result!.first.localImagePath, isNotNull);
    });

    test('savePhotos with overwriteExisting re-downloads files', () async {
      final photos = [
        Photo(
          id: '1',
          url: 'https://example.com/photo.jpg',
          description: 'desc',
          location: 'Taipei',
          createdBy: 'Alice',
          createdAt: DateTime(2024, 1, 1),
          takenAt: DateTime(2023, 12, 1),
        ),
      ];

      await dataSource.savePhotos(photos);
      final metadataBefore =
          File(p.join(tempDir.path, 'photos-cache.json')).readAsStringSync();

      final stored = await dataSource.savePhotos(
        photos,
        overwriteExisting: true,
      );

      expect(stored.first.localImagePath, isNotNull);
      final metadataAfter =
          File(p.join(tempDir.path, 'photos-cache.json')).readAsStringSync();
      expect(metadataAfter, metadataBefore);
      verify(
        () => dio.get<List<int>>(any(), options: any(named: 'options')),
      ).called(2);
    });

    test('downloadPhoto updates cached metadata and local path', () async {
      final photo = Photo(
        id: '1',
        url: 'https://example.com/photo.jpg',
        description: 'desc',
        location: 'Taipei',
        createdBy: 'Alice',
        createdAt: DateTime(2024, 1, 1),
        takenAt: DateTime(2023, 12, 1),
      );

      await dataSource.savePhotos([photo]);
      final updated = await dataSource.downloadPhoto(photo);

      expect(
        updated.localImagePath,
        equals(p.join(downloadsDir.path, '1.jpg')),
      );
      final metadata = await dataSource.readPhotos();
      expect(metadata, isNotNull);
      expect(metadata!.first.localImagePath, equals(updated.localImagePath));
    });

    test(
      'saveFavoriteIds persists favorites and restores them later',
      () async {
        final favorites = await dataSource.saveFavoriteIds({'1', '2'});

        expect(favorites, equals(const {'1', '2'}));

        final reloaded = await dataSource.readFavoriteIds();
        expect(reloaded, equals(const {'1', '2'}));
      },
    );
  });
}
