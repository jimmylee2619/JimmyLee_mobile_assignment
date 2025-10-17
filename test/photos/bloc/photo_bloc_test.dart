import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:photo_gallery/photos/bloc/photo_bloc.dart';
import 'package:photo_gallery/photos/data/photo.dart';
import 'package:photo_gallery/photos/data/photo_repository.dart';

class _MockPhotoRepository extends Mock implements PhotoRepository {}

class _FakePhoto extends Fake implements Photo {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePhoto());
  });

  group('PhotoBloc', () {
    late PhotoRepository repository;
    late Photo firstPhoto;
    late Photo secondPhoto;
    late Photo thirdPhoto;

    setUp(() {
      repository = _MockPhotoRepository();
      firstPhoto = Photo(
        id: '1',
        url: _transparentImageDataUri,
        description: 'Lakeside sunrise',
        location: 'Taipei',
        createdBy: 'Ava',
        createdAt: DateTime(2023, 1, 1),
        takenAt: DateTime(2022, 12, 31),
      );
      secondPhoto = Photo(
        id: '2',
        url: _transparentImageDataUri,
        description: 'City skyline',
        location: 'Kaohsiung',
        createdBy: 'Blake',
        createdAt: DateTime(2023, 1, 2),
        takenAt: DateTime(2023, 1, 1),
      );
      thirdPhoto = Photo(
        id: '3',
        url: _transparentImageDataUri,
        description: 'Forest trail',
        location: 'Taipei',
        createdBy: 'Charlie',
        createdAt: DateTime(2023, 1, 3),
        takenAt: DateTime(2023, 1, 2),
      );
    });

    blocTest<PhotoBloc, PhotoState>(
      'emits loading then success when photos load',
      build: () {
        when(
          () =>
              repository.fetchPhotos(forceRefresh: any(named: 'forceRefresh')),
        ).thenAnswer((_) async => [firstPhoto]);
        when(
          () => repository.getFavoriteIds(),
        ).thenAnswer((_) async => <String>{});
        return PhotoBloc(repository: repository);
      },
      act: (bloc) => bloc.add(const PhotoRequested()),
      expect:
          () => [
            const PhotoState(status: PhotoStatus.loading),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [firstPhoto],
              photos: [firstPhoto],
              favoriteIds: const <String>{},
              displayPhotos: [firstPhoto],
              totalPages: 1,
              currentPage: 0,
            ),
          ],
      verify: (_) {
        verify(() => repository.fetchPhotos(forceRefresh: false)).called(1);
      },
    );

    blocTest<PhotoBloc, PhotoState>(
      'refresh forces repository call with forceRefresh=true',
      build: () {
        when(
          () =>
              repository.fetchPhotos(forceRefresh: any(named: 'forceRefresh')),
        ).thenAnswer((_) async => [firstPhoto]);
        when(
          () => repository.getFavoriteIds(),
        ).thenAnswer((_) async => <String>{});
        return PhotoBloc(repository: repository);
      },
      act: (bloc) async {
        bloc.add(const PhotoRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const PhotoRefreshed());
      },
      expect:
          () => [
            const PhotoState(status: PhotoStatus.loading),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [firstPhoto],
              photos: [firstPhoto],
              favoriteIds: const <String>{},
              displayPhotos: [firstPhoto],
              totalPages: 1,
              currentPage: 0,
            ),
            PhotoState(
              status: PhotoStatus.loading,
              allPhotos: [firstPhoto],
              photos: [firstPhoto],
              favoriteIds: const <String>{},
              displayPhotos: [firstPhoto],
              totalPages: 1,
              currentPage: 0,
            ),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [firstPhoto],
              photos: [firstPhoto],
              favoriteIds: const <String>{},
              displayPhotos: [firstPhoto],
              totalPages: 1,
              currentPage: 0,
            ),
          ],
      verify: (_) {
        verify(() => repository.fetchPhotos(forceRefresh: false)).called(1);
        verify(() => repository.fetchPhotos(forceRefresh: true)).called(1);
      },
    );

    blocTest<PhotoBloc, PhotoState>(
      'emits failure when repository throws',
      build: () {
        when(
          () =>
              repository.fetchPhotos(forceRefresh: any(named: 'forceRefresh')),
        ).thenThrow(Exception('network failure'));
        when(
          () => repository.getFavoriteIds(),
        ).thenAnswer((_) async => <String>{});
        return PhotoBloc(repository: repository);
      },
      act: (bloc) => bloc.add(const PhotoRequested()),
      expect:
          () => const [
            PhotoState(status: PhotoStatus.loading),
            PhotoState(
              status: PhotoStatus.failure,
              errorMessage: 'Exception: network failure',
            ),
          ],
    );

    blocTest<PhotoBloc, PhotoState>(
      'filters photos on search query change',
      build: () {
        when(
          () =>
              repository.fetchPhotos(forceRefresh: any(named: 'forceRefresh')),
        ).thenAnswer((_) async => [firstPhoto, secondPhoto]);
        when(
          () => repository.getFavoriteIds(),
        ).thenAnswer((_) async => <String>{});
        return PhotoBloc(repository: repository);
      },
      act: (bloc) async {
        bloc.add(const PhotoRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const PhotoSearchQueryChanged('Blake'));
      },
      expect:
          () => [
            const PhotoState(status: PhotoStatus.loading),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [firstPhoto, secondPhoto],
              photos: [firstPhoto, secondPhoto],
              favoriteIds: const <String>{},
              displayPhotos: [firstPhoto, secondPhoto],
              totalPages: 1,
              currentPage: 0,
            ),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [firstPhoto, secondPhoto],
              photos: [secondPhoto],
              searchQuery: 'Blake',
              favoriteIds: const <String>{},
              displayPhotos: [secondPhoto],
              totalPages: 1,
              currentPage: 0,
            ),
          ],
    );

    blocTest<PhotoBloc, PhotoState>(
      'records recent search term on submit',
      build: () {
        when(
          () =>
              repository.fetchPhotos(forceRefresh: any(named: 'forceRefresh')),
        ).thenAnswer((_) async => [firstPhoto]);
        when(
          () => repository.getFavoriteIds(),
        ).thenAnswer((_) async => <String>{});
        return PhotoBloc(repository: repository);
      },
      act: (bloc) async {
        bloc.add(const PhotoRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const PhotoSearchSubmitted('sunrise'));
      },
      expect:
          () => [
            const PhotoState(status: PhotoStatus.loading),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [firstPhoto],
              photos: [firstPhoto],
              favoriteIds: const <String>{},
              displayPhotos: [firstPhoto],
              totalPages: 1,
              currentPage: 0,
            ),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [firstPhoto],
              photos: [firstPhoto],
              favoriteIds: const <String>{},
              recentSearches: ['sunrise'],
              displayPhotos: [firstPhoto],
              totalPages: 1,
              currentPage: 0,
            ),
          ],
    );

    blocTest<PhotoBloc, PhotoState>(
      'location filter narrows results',
      build: () {
        when(
          () =>
              repository.fetchPhotos(forceRefresh: any(named: 'forceRefresh')),
        ).thenAnswer((_) async => [firstPhoto, thirdPhoto]);
        when(
          () => repository.getFavoriteIds(),
        ).thenAnswer((_) async => <String>{});
        return PhotoBloc(repository: repository);
      },
      act: (bloc) async {
        bloc.add(const PhotoRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const PhotoLocationFilterToggled('Taipei'));
      },
      expect:
          () => [
            const PhotoState(status: PhotoStatus.loading),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [firstPhoto, thirdPhoto],
              photos: [firstPhoto, thirdPhoto],
              favoriteIds: const <String>{},
              displayPhotos: [firstPhoto, thirdPhoto],
              totalPages: 1,
              currentPage: 0,
            ),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [firstPhoto, thirdPhoto],
              photos: [firstPhoto, thirdPhoto],
              favoriteIds: const <String>{},
              selectedLocations: const {'Taipei'},
              displayPhotos: [firstPhoto, thirdPhoto],
              totalPages: 1,
              currentPage: 0,
            ),
          ],
    );

    blocTest<PhotoBloc, PhotoState>(
      'creator filter narrows results',
      build: () {
        when(
          () =>
              repository.fetchPhotos(forceRefresh: any(named: 'forceRefresh')),
        ).thenAnswer((_) async => [firstPhoto, secondPhoto]);
        when(
          () => repository.getFavoriteIds(),
        ).thenAnswer((_) async => <String>{});
        return PhotoBloc(repository: repository);
      },
      act: (bloc) async {
        bloc.add(const PhotoRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const PhotoCreatorFilterToggled('Blake'));
      },
      expect:
          () => [
            const PhotoState(status: PhotoStatus.loading),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [firstPhoto, secondPhoto],
              photos: [firstPhoto, secondPhoto],
              favoriteIds: const <String>{},
              displayPhotos: [firstPhoto, secondPhoto],
              totalPages: 1,
              currentPage: 0,
            ),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [firstPhoto, secondPhoto],
              photos: [secondPhoto],
              selectedCreators: const {'Blake'},
              favoriteIds: const <String>{},
              displayPhotos: [secondPhoto],
              totalPages: 1,
              currentPage: 0,
            ),
          ],
    );

    blocTest<PhotoBloc, PhotoState>(
      'toggle favorite updates set and derived favorites list',
      build: () {
        when(
          () =>
              repository.fetchPhotos(forceRefresh: any(named: 'forceRefresh')),
        ).thenAnswer((_) async => [firstPhoto]);
        when(
          () => repository.getFavoriteIds(),
        ).thenAnswer((_) async => <String>{});
        when(
          () => repository.toggleFavorite(firstPhoto.id),
        ).thenAnswer((_) async => <String>{firstPhoto.id});
        return PhotoBloc(repository: repository);
      },
      act: (bloc) async {
        bloc.add(const PhotoRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(PhotoFavoriteToggled(firstPhoto.id));
      },
      expect:
          () => [
            const PhotoState(status: PhotoStatus.loading),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [firstPhoto],
              photos: [firstPhoto],
              favoriteIds: const <String>{},
              displayPhotos: [firstPhoto],
              totalPages: 1,
              currentPage: 0,
            ),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [firstPhoto],
              photos: [firstPhoto],
              favoriteIds: const <String>{'1'},
              filteredFavoritePhotos: [firstPhoto],
              displayPhotos: [firstPhoto],
              favoriteDisplayPhotos: [firstPhoto],
              totalPages: 1,
              currentPage: 0,
              favoriteTotalPages: 1,
            ),
          ],
    );

    blocTest<PhotoBloc, PhotoState>(
      'download request marks photo as downloading then emits success message',
      build: () {
        final downloaded = firstPhoto.copyWith(
          localImagePath: '/tmp/photo.jpg',
        );
        when(
          () =>
              repository.fetchPhotos(forceRefresh: any(named: 'forceRefresh')),
        ).thenAnswer((_) async => [firstPhoto]);
        when(
          () => repository.getFavoriteIds(),
        ).thenAnswer((_) async => <String>{});
        when(
          () => repository.downloadPhoto(
            any(that: isA<Photo>()),
            overwriteExisting: any(named: 'overwriteExisting'),
          ),
        ).thenAnswer((_) async => downloaded);
        return PhotoBloc(repository: repository);
      },
      act: (bloc) async {
        bloc.add(const PhotoRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(PhotoDownloadRequested(firstPhoto));
      },
      expect:
          () => [
            const PhotoState(status: PhotoStatus.loading),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [firstPhoto],
              photos: [firstPhoto],
              favoriteIds: const <String>{},
              displayPhotos: [firstPhoto],
              totalPages: 1,
              currentPage: 0,
            ),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [firstPhoto],
              photos: [firstPhoto],
              favoriteIds: const <String>{},
              displayPhotos: [firstPhoto],
              totalPages: 1,
              currentPage: 0,
              downloadingPhotoIds: {'1'},
            ),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [
                firstPhoto.copyWith(localImagePath: '/tmp/photo.jpg'),
              ],
              photos: [firstPhoto.copyWith(localImagePath: '/tmp/photo.jpg')],
              favoriteIds: const <String>{},
              displayPhotos: [
                firstPhoto.copyWith(localImagePath: '/tmp/photo.jpg'),
              ],
              totalPages: 1,
              currentPage: 0,
              infoMessage: 'Saved to /tmp/photo.jpg',
            ),
          ],
    );

    blocTest<PhotoBloc, PhotoState>(
      'download request failure clears flag and surfaces error message',
      build: () {
        when(
          () =>
              repository.fetchPhotos(forceRefresh: any(named: 'forceRefresh')),
        ).thenAnswer((_) async => [firstPhoto]);
        when(
          () => repository.getFavoriteIds(),
        ).thenAnswer((_) async => <String>{});
        when(
          () => repository.downloadPhoto(
            any(that: isA<Photo>()),
            overwriteExisting: any(named: 'overwriteExisting'),
          ),
        ).thenThrow(Exception('disk full'));
        return PhotoBloc(repository: repository);
      },
      act: (bloc) async {
        bloc.add(const PhotoRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(PhotoDownloadRequested(firstPhoto));
      },
      expect:
          () => [
            const PhotoState(status: PhotoStatus.loading),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [firstPhoto],
              photos: [firstPhoto],
              favoriteIds: const <String>{},
              displayPhotos: [firstPhoto],
              totalPages: 1,
              currentPage: 0,
            ),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [firstPhoto],
              photos: [firstPhoto],
              favoriteIds: const <String>{},
              displayPhotos: [firstPhoto],
              totalPages: 1,
              currentPage: 0,
              downloadingPhotoIds: {'1'},
            ),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [firstPhoto],
              photos: [firstPhoto],
              favoriteIds: const <String>{},
              displayPhotos: [firstPhoto],
              totalPages: 1,
              currentPage: 0,
              errorMessage: 'Exception: disk full',
            ),
          ],
    );

    blocTest<PhotoBloc, PhotoState>(
      'layout mode change updates state',
      build: () {
        when(
          () =>
              repository.fetchPhotos(forceRefresh: any(named: 'forceRefresh')),
        ).thenAnswer((_) async => [firstPhoto]);
        when(
          () => repository.getFavoriteIds(),
        ).thenAnswer((_) async => <String>{});
        return PhotoBloc(repository: repository);
      },
      act: (bloc) async {
        bloc.add(const PhotoRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const PhotoLayoutModeChanged(GalleryLayoutMode.masonry));
      },
      expect:
          () => [
            const PhotoState(status: PhotoStatus.loading),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [firstPhoto],
              photos: [firstPhoto],
              favoriteIds: const <String>{},
              displayPhotos: [firstPhoto],
              totalPages: 1,
              currentPage: 0,
            ),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [firstPhoto],
              photos: [firstPhoto],
              favoriteIds: const <String>{},
              displayPhotos: [firstPhoto],
              totalPages: 1,
              currentPage: 0,
              layoutMode: GalleryLayoutMode.masonry,
            ),
          ],
    );

    blocTest<PhotoBloc, PhotoState>(
      'selection workflow adds and removes ids',
      build: () {
        when(
          () =>
              repository.fetchPhotos(forceRefresh: any(named: 'forceRefresh')),
        ).thenAnswer((_) async => [firstPhoto, secondPhoto]);
        when(
          () => repository.getFavoriteIds(),
        ).thenAnswer((_) async => <String>{});
        return PhotoBloc(repository: repository);
      },
      act: (bloc) async {
        bloc.add(const PhotoRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(PhotoSelectionModeStarted(anchorPhotoId: firstPhoto.id));
        bloc.add(PhotoSelectionToggled(secondPhoto.id));
        bloc.add(const PhotoSelectionCleared());
      },
      expect:
          () => [
            const PhotoState(status: PhotoStatus.loading),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [firstPhoto, secondPhoto],
              photos: [firstPhoto, secondPhoto],
              favoriteIds: const <String>{},
              displayPhotos: [firstPhoto, secondPhoto],
              totalPages: 1,
              currentPage: 0,
            ),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [firstPhoto, secondPhoto],
              photos: [firstPhoto, secondPhoto],
              favoriteIds: const <String>{},
              displayPhotos: [firstPhoto, secondPhoto],
              totalPages: 1,
              currentPage: 0,
              isSelectionMode: true,
              selectedPhotoIds: {'1'},
            ),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [firstPhoto, secondPhoto],
              photos: [firstPhoto, secondPhoto],
              favoriteIds: const <String>{},
              displayPhotos: [firstPhoto, secondPhoto],
              totalPages: 1,
              currentPage: 0,
              isSelectionMode: true,
              selectedPhotoIds: {'1', '2'},
            ),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [firstPhoto, secondPhoto],
              photos: [firstPhoto, secondPhoto],
              favoriteIds: const <String>{},
              displayPhotos: [firstPhoto, secondPhoto],
              totalPages: 1,
              currentPage: 0,
            ),
          ],
    );

    blocTest<PhotoBloc, PhotoState>(
      'batch download processes all selected photos and clears selection',
      build: () {
        final updatedFirst = firstPhoto.copyWith(
          localImagePath: '/tmp/first.jpg',
        );
        final updatedSecond = secondPhoto.copyWith(
          localImagePath: '/tmp/second.jpg',
        );
        when(
          () =>
              repository.fetchPhotos(forceRefresh: any(named: 'forceRefresh')),
        ).thenAnswer((_) async => [firstPhoto, secondPhoto]);
        when(
          () => repository.getFavoriteIds(),
        ).thenAnswer((_) async => <String>{});
        when(
          () => repository.downloadPhoto(
            any(that: isA<Photo>()),
            overwriteExisting: any(named: 'overwriteExisting'),
          ),
        ).thenAnswer((invocation) async {
          final target = invocation.positionalArguments.first as Photo;
          return target.id == firstPhoto.id ? updatedFirst : updatedSecond;
        });
        return PhotoBloc(repository: repository);
      },
      act: (bloc) async {
        bloc.add(const PhotoRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(PhotoSelectionModeStarted(anchorPhotoId: firstPhoto.id));
        bloc.add(PhotoSelectionToggled(secondPhoto.id));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const PhotoBatchDownloadRequested());
      },
      expect:
          () => [
            const PhotoState(status: PhotoStatus.loading),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [firstPhoto, secondPhoto],
              photos: [firstPhoto, secondPhoto],
              favoriteIds: const <String>{},
              displayPhotos: [firstPhoto, secondPhoto],
              totalPages: 1,
              currentPage: 0,
            ),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [firstPhoto, secondPhoto],
              photos: [firstPhoto, secondPhoto],
              favoriteIds: const <String>{},
              displayPhotos: [firstPhoto, secondPhoto],
              totalPages: 1,
              currentPage: 0,
              isSelectionMode: true,
              selectedPhotoIds: {'1'},
            ),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [firstPhoto, secondPhoto],
              photos: [firstPhoto, secondPhoto],
              favoriteIds: const <String>{},
              displayPhotos: [firstPhoto, secondPhoto],
              totalPages: 1,
              currentPage: 0,
              isSelectionMode: true,
              selectedPhotoIds: {'1', '2'},
            ),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [firstPhoto, secondPhoto],
              photos: [firstPhoto, secondPhoto],
              favoriteIds: const <String>{},
              displayPhotos: [firstPhoto, secondPhoto],
              totalPages: 1,
              currentPage: 0,
              isSelectionMode: true,
              selectedPhotoIds: {'1', '2'},
              downloadingPhotoIds: {'1', '2'},
            ),
            PhotoState(
              status: PhotoStatus.success,
              allPhotos: [
                firstPhoto.copyWith(localImagePath: '/tmp/first.jpg'),
                secondPhoto.copyWith(localImagePath: '/tmp/second.jpg'),
              ],
              photos: [
                firstPhoto.copyWith(localImagePath: '/tmp/first.jpg'),
                secondPhoto.copyWith(localImagePath: '/tmp/second.jpg'),
              ],
              favoriteIds: const <String>{},
              displayPhotos: [
                firstPhoto.copyWith(localImagePath: '/tmp/first.jpg'),
                secondPhoto.copyWith(localImagePath: '/tmp/second.jpg'),
              ],
              totalPages: 1,
              currentPage: 0,
              infoMessage: 'Downloaded 2 items.',
            ),
          ],
    );
  });
}

const _transparentImageDataUri =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=';
