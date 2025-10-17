import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:photo_gallery/photos/data/photo.dart';
import 'package:photo_gallery/photos/data/photo_api_client.dart';
import 'package:photo_gallery/photos/data/photo_local_data_source.dart';
import 'package:photo_gallery/photos/data/photo_repository.dart';

class _MockPhotoApiClient extends Mock implements PhotoApiClient {}

class _MockPhotoLocalDataSource extends Mock implements PhotoLocalDataSource {}

void main() {
  group('PhotoRepository', () {
    late PhotoApiClient apiClient;
    late PhotoLocalDataSource localDataSource;
    late PhotoRepository repository;
    late Photo remotePhoto;

    setUp(() {
      apiClient = _MockPhotoApiClient();
      localDataSource = _MockPhotoLocalDataSource();
      repository = PhotoRepository(
        apiClient: apiClient,
        localDataSource: localDataSource,
      );
      when(
        () => localDataSource.readFavoriteIds(),
      ).thenAnswer((_) async => <String>{});
      remotePhoto = Photo(
        id: '1',
        url: 'https://example.com/photo.jpg',
        description: 'desc',
        location: 'Taipei',
        createdBy: 'Alice',
        createdAt: DateTime(2024, 1, 1),
        takenAt: DateTime(2023, 12, 1),
      );
    });

    test(
      'returns cached photos when available without calling remote',
      () async {
        when(() => localDataSource.readPhotos()).thenAnswer(
          (_) async => [remotePhoto.copyWith(localImagePath: '/tmp/photo.jpg')],
        );
        when(
          () => apiClient.fetchPhotos(),
        ).thenThrow(Exception('should not call'));

        final result = await repository.fetchPhotos();

        expect(result, hasLength(1));
        expect(result.first.localImagePath, isNotNull);
      },
    );

    test('fetchPhotos downloads remote data and persists metadata', () async {
      when(() => localDataSource.readPhotos()).thenAnswer((_) async => null);
      when(
        () => apiClient.fetchPhotos(),
      ).thenAnswer((_) async => [remotePhoto]);
      when(
        () => localDataSource.savePhotos([
          remotePhoto,
        ], overwriteExisting: any(named: 'overwriteExisting')),
      ).thenAnswer(
        (_) async => [
          remotePhoto.copyWith(localImagePath: '/cache/${remotePhoto.id}.jpg'),
        ],
      );

      final result = await repository.fetchPhotos();

      expect(result.first.localImagePath, '/cache/1.jpg');
      verify(() => apiClient.fetchPhotos()).called(1);
      verify(
        () =>
            localDataSource.savePhotos([remotePhoto], overwriteExisting: false),
      ).called(1);
    });

    test('falls back to local cache when remote request fails', () async {
      var callCount = 0;
      when(() => localDataSource.readPhotos()).thenAnswer((_) async {
        if (callCount == 0) {
          callCount += 1;
          return null;
        }
        return [remotePhoto.copyWith(localImagePath: '/tmp/photo.jpg')];
      });
      when(() => apiClient.fetchPhotos()).thenThrow(Exception('network error'));

      final result = await repository.fetchPhotos();

      expect(result.first.localImagePath, '/tmp/photo.jpg');
    });

    test('invalidate clears in-memory and local cache', () async {
      when(() => localDataSource.clear()).thenAnswer((_) async {});

      await repository.invalidate();

      verify(() => localDataSource.clear()).called(1);
    });

    test(
      'toggleFavorite delegates to data source and returns updated set',
      () async {
        when(() => localDataSource.saveFavoriteIds(any())).thenAnswer((
          invocation,
        ) async {
          final ids = invocation.positionalArguments.first as Set<String>;
          return Set<String>.unmodifiable(ids);
        });

        final favorites = await repository.toggleFavorite('1');

        expect(favorites, equals(const {'1'}));
        verify(() => localDataSource.saveFavoriteIds({'1'})).called(1);
      },
    );

    test(
      'downloadPhoto delegates to data source and returns updated photo',
      () async {
        final updated = remotePhoto.copyWith(localImagePath: '/cache/1.jpg');
        when(
          () => localDataSource.readPhotos(),
        ).thenAnswer((_) async => [remotePhoto]);
        when(
          () => localDataSource.downloadPhoto(
            remotePhoto,
            overwriteExisting: any(named: 'overwriteExisting'),
          ),
        ).thenAnswer((_) async => updated);

        final result = await repository.downloadPhoto(remotePhoto);

        expect(result.localImagePath, '/cache/1.jpg');
        verify(
          () => localDataSource.downloadPhoto(
            remotePhoto,
            overwriteExisting: false,
          ),
        ).called(1);
      },
    );
  });
}
