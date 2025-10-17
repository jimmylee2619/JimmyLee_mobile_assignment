import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';

import 'package:photo_gallery/photos/bloc/photo_bloc.dart';
import 'package:photo_gallery/photos/data/photo.dart';
import 'package:photo_gallery/photos/data/photo_repository.dart';
import 'package:photo_gallery/photos/view/photo_page.dart';
import 'package:photo_gallery/photos/widgets/photo_list_tile.dart';

class _MockPhotoRepository extends Mock implements PhotoRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PhotoPage', () {
    late PhotoRepository repository;
    late List<Photo> photos;

    setUp(() {
      repository = _MockPhotoRepository();
      photos = List.generate(
        6,
        (i) => Photo(
          id: i.toString(),
          url: _transparentImageDataUri,
          description: 'Photo $i',
          location: 'Location $i',
          createdBy: 'Author $i',
          createdAt: DateTime(2023, 1, i + 1),
          takenAt: DateTime(2022, 12, 31 + i),
        ),
      );

      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.window
        ..physicalSizeTestValue = const Size(800, 1600)
        ..devicePixelRatioTestValue = 1.0;
    });

    tearDown(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.window
        ..clearPhysicalSizeTestValue()
        ..clearDevicePixelRatioTestValue();
    });

    Widget buildSubject() {
      return RepositoryProvider.value(
        value: repository,
        child: const MaterialApp(home: PhotoPage()),
      );
    }

    void stubFetchPhotos(List<Photo> data) {
      when(
        () => repository.fetchPhotos(forceRefresh: any(named: 'forceRefresh')),
      ).thenAnswer((_) async => data);
    }

    void stubFavoriteIds(Set<String> favorites) {
      when(
        () => repository.getFavoriteIds(),
      ).thenAnswer((_) async => favorites);
    }

    testWidgets(
      'renders search field, layout toggle, filter button, and tiles after load',
      (tester) async {
        stubFetchPhotos(photos);
        stubFavoriteIds(const {});

        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(buildSubject());
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.byType(TextField), findsOneWidget);
          expect(
            find.byType(SegmentedButton<GalleryLayoutMode>),
            findsOneWidget,
          );
          expect(find.byIcon(Icons.tune), findsOneWidget);

          final galleryContext = tester.element(find.byType(PhotoGalleryView));
          final bloc = galleryContext.read<PhotoBloc>();
          expect(bloc.state.displayPhotos, hasLength(5));
          expect(find.byType(PhotoListTile), findsWidgets);

          await tester.tap(find.byIcon(Icons.tune));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.text('Filter options'), findsOneWidget);
          expect(find.text('Clear'), findsOneWidget);
          expect(find.text('Done'), findsOneWidget);

          await tester.tap(find.text('Done'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
        });
      },
    );

    testWidgets('shows empty placeholder when repository returns no photos', (
      tester,
    ) async {
      stubFetchPhotos(const []);
      stubFavoriteIds(const {});

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text('No photos match the current filters.'),
          findsOneWidget,
        );
        expect(find.byType(PhotoListTile), findsNothing);
      });
    });

    testWidgets('filters photos based on search query', (tester) async {
      stubFetchPhotos(photos);
      stubFavoriteIds(const {});

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await tester.enterText(find.byType(TextField), 'Photo 1');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.descendant(
            of: find.byType(PhotoListTile),
            matching: find.text('Photo 1'),
          ),
          findsOneWidget,
        );
        expect(find.text('Photo 0'), findsNothing);
        expect(find.byType(PhotoListTile), findsOneWidget);
      });
    });

    testWidgets(
      'long press enters selection mode and exposes batch download action',
      (tester) async {
        stubFetchPhotos(photos);
        stubFavoriteIds(const {});

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

          await tester.longPress(find.byType(PhotoListTile).first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.text('Selected 1 item'), findsOneWidget);
          final downloadAction = tester.widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.download),
          );
          expect(downloadAction.onPressed, isNotNull);
        });
      },
    );

    testWidgets('switching to masonry layout renders a staggered grid', (
      tester,
    ) async {
      stubFetchPhotos(photos);
      stubFavoriteIds(const {});

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.text('Masonry'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(SliverMasonryGrid), findsOneWidget);
      });
    });
  });
}

const _transparentImageDataUri =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=';
