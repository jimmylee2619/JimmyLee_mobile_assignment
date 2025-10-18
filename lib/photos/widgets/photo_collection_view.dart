import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../bloc/photo_bloc.dart';
import '../data/photo.dart';
import '../../app_constants.dart';
import 'photo_list_tile.dart';

typedef PhotoCallback = void Function(Photo photo);

/// Consolidates the scrolling presentation shared by the gallery and favorites tabs.
class PhotoCollectionView extends StatelessWidget {
  const PhotoCollectionView({
    super.key,
    required this.headerWidgets,
    required this.footerWidgets,
    required this.photos,
    required this.layoutMode,
    required this.isSelectionMode,
    required this.selectedPhotoIds,
    required this.downloadingPhotoIds,
    required this.isFavorite,
    required this.onFavoritePressed,
    required this.onPhotoTap,
    required this.onPhotoLongPress,
    required this.onPhotoSelectionToggle,
    required this.onRefresh,
    required this.emptyPlaceholder,
    this.masonryColumns = 2,
  });

  final List<Widget> headerWidgets;
  final List<Widget> footerWidgets;
  final List<Photo> photos;
  final GalleryLayoutMode layoutMode;
  final bool isSelectionMode;
  final Set<String> selectedPhotoIds;
  final Set<String> downloadingPhotoIds;
  final bool Function(Photo photo) isFavorite;
  final PhotoCallback onFavoritePressed;
  final PhotoCallback onPhotoTap;
  final PhotoCallback onPhotoLongPress;
  final PhotoCallback onPhotoSelectionToggle;
  final Future<void> Function() onRefresh;
  final Widget emptyPlaceholder;
  final int masonryColumns;

  @override
  Widget build(BuildContext context) {
    if (layoutMode == GalleryLayoutMode.masonry) {
      return _buildMasonryScroll(context);
    }
    return _buildListScroll(context);
  }

  Widget _buildListScroll(BuildContext context) {
    final tiles = _buildTiles(context);
    final children = <Widget>[
      ...headerWidgets,
      if (tiles.isNotEmpty) ...tiles else emptyPlaceholder,
      ...footerWidgets,
    ];

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        shrinkWrap: true,
        cacheExtent: 50000, // Increase cacheExtent
        padding: const EdgeInsets.all(AppSpacingLarge),
        itemCount: children.length,
        itemBuilder: (context, index) => children[index],
        separatorBuilder: (context, index) => const SizedBox(height: AppSpacingLarge),
      ),
    );
  }

  Widget _buildMasonryScroll(BuildContext context) {
    final tiles = _buildTiles(context);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        cacheExtent: 50000, // Increase cacheExtent
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          ..._buildHeaderSlivers(),
          if (tiles.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacingLarge, vertical: AppSpacingExtraLarge),
              sliver: SliverToBoxAdapter(child: emptyPlaceholder),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacingLarge, AppSpacingSmall, AppSpacingLarge, AppSpacingSmall),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: masonryColumns,
                mainAxisSpacing: AppSpacingLarge,
                crossAxisSpacing: AppSpacingLarge,
                childCount: tiles.length,
                itemBuilder: (context, index) => tiles[index],
              ),
            ),
          ..._buildFooterSlivers(),
          // Ensure the scroll view has enough trailing space to trigger pull-to-refresh.
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacingLarge)),
        ],
      ),
    );
  }

  Iterable<Widget> _buildHeaderSlivers() sync* {
    final length = headerWidgets.length;
    for (var index = 0; index < length; index++) {
      final topPadding = index == 0 ? AppSpacingLarge : AppSpacingSmall;
      yield SliverPadding(
        padding: EdgeInsets.fromLTRB(AppSpacingLarge, topPadding, AppSpacingLarge, AppSpacingSmall),
        sliver: SliverToBoxAdapter(child: headerWidgets[index]),
      );
    }
  }

  Iterable<Widget> _buildFooterSlivers() sync* {
    final length = footerWidgets.length;
    for (var index = 0; index < length; index++) {
      final bottomPadding = index == length - 1 ? AppSpacingLarge : AppSpacingSmall;
      yield SliverPadding(
        padding: EdgeInsets.fromLTRB(AppSpacingLarge, AppSpacingSmall, AppSpacingLarge, bottomPadding),
        sliver: SliverToBoxAdapter(child: footerWidgets[index]),
      );
    }
  }

  List<Widget> _buildTiles(BuildContext context) {
    return photos
        .map(
          (photo) => PhotoListTile(
            key: ValueKey(photo.id),
            photo: photo,
            isFavorite: isFavorite(photo),
            isSelectionMode: isSelectionMode,
            isSelected: selectedPhotoIds.contains(photo.id),
            isDownloading: downloadingPhotoIds.contains(photo.id),
            onFavoritePressed:
                isSelectionMode ? null : () => onFavoritePressed(photo),
            onTap: () => onPhotoTap(photo),
            onLongPress: () => onPhotoLongPress(photo),
            onSelectionToggle: () => onPhotoSelectionToggle(photo),
          ),
        )
        .toList(growable: false);
  }
}
