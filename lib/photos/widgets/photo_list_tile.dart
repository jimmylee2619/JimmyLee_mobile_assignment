import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data/photo.dart';
import '../../app_constants.dart';

/// Renders a photo summary card and optionally exposes selection affordances.
class PhotoListTile extends StatefulWidget {
  const PhotoListTile({
    super.key,
    required this.photo,
    this.onTap,
    required this.isFavorite,
    this.onFavoritePressed,
    this.onLongPress,
    this.onSelectionToggle,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.isDownloading = false,
  });

  final Photo photo;
  final VoidCallback? onTap;
  final bool isFavorite;
  final VoidCallback? onFavoritePressed;
  final VoidCallback? onLongPress;
  final VoidCallback? onSelectionToggle;
  final bool isSelectionMode;
  final bool isSelected;
  final bool isDownloading;

  @override
  State<PhotoListTile> createState() => _PhotoListTileState();
}

class _PhotoListTileState extends State<PhotoListTile>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final bool isTileDisabled = widget.isDownloading;
    final effectiveOnTap = isTileDisabled
        ? null
        : (widget.isSelectionMode
            ? (widget.onSelectionToggle ?? widget.onTap)
            : widget.onTap);
    final effectiveOnLongPress = isTileDisabled ? null : widget.onLongPress;
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: AppBorderRadius),
      child: InkWell(
        onTap: effectiveOnTap,
        onLongPress: effectiveOnLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildImage(),
                  if (widget.isSelectionMode)
                    Positioned.fill(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        color: widget.isSelected
                            ? Colors.black.withAlpha((255 * 0.35).round())
                            : Colors.black.withAlpha((255 * 0.15).round()),
                      ),
                    ),
                  if (widget.isDownloading)
                    const Positioned.fill(
                      // Blocks taps and surfaces feedback while the download is in flight.
                      child: ColoredBox(
                        color: Colors.black54,
                        child: Center(
                          child: SizedBox(
                            height: AppCircularProgressIndicatorSize,
                            width: AppCircularProgressIndicatorSize,
                            child: CircularProgressIndicator(strokeWidth: AppStrokeWidthMedium),
                          ),
                        ),
                      ),
                    ),
                  if (widget.isSelectionMode)
                    Positioned(
                      top: AppSpacingSmall,
                      right: AppSpacingSmall,
                      child: CircleAvatar(
                        radius: AppCircleAvatarRadius,
                        backgroundColor: widget.isSelected
                            ? theme.colorScheme.primary
                            : Colors.white,
                        foregroundColor:
                            widget.isSelected ? Colors.white : Colors.black54,
                        child: Icon(
                          widget.isSelected
                              ? Icons.check
                              : Icons.circle_outlined,
                        ),
                      ),
                    )
                  else
                    Positioned(
                      top: AppSpacingSmall,
                      right: AppSpacingSmall,
                      child: Material(
                        color: Colors.black45,
                        shape: const CircleBorder(),
                        child: IconButton(
                          iconSize: AppIconSizeMedium,
                          splashRadius: AppSplashRadius,
                          icon: Icon(
                            widget.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: Colors.white,
                          ),
                          onPressed: widget.onFavoritePressed,
                          tooltip: widget.isFavorite
                              ? 'Remove favorites'
                              : 'Add to favorites',
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.photo.description,
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacingSmall),
                  Row(
                    children: [
                      const Icon(Icons.place, size: AppIconSizeSmall),
                      const SizedBox(width: AppSpacingExtraSmall),
                      Expanded(child: Text(widget.photo.location)),
                    ],
                  ),
                  const SizedBox(height: AppSpacingExtraSmall),
                  Row(
                    children: [
                      const Icon(Icons.person, size: AppIconSizeSmall),
                      const SizedBox(width: AppSpacingExtraSmall),
                      Expanded(child: Text(widget.photo.createdBy)),
                    ],
                  ),
                  const SizedBox(height: AppSpacingExtraSmall),
                  Row(
                    children: [
                      const Icon(Icons.camera_alt, size: AppIconSizeSmall),
                      const SizedBox(width: AppSpacingExtraSmall),
                      Text(_formatDate(widget.photo.takenAt)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Formats the captured date into a short string.
  static String _formatDate(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }

  Widget _buildImage() {
    final localPath = widget.photo.localImagePath;
    if (localPath != null && File(localPath).existsSync()) {
      return Image.file(
        File(localPath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _errorPlaceholder(),
      );
    }

    return CachedNetworkImage(
      imageUrl: widget.photo.url,
      fit: BoxFit.cover,
      placeholder: (context, url) => const Center(
        child: SizedBox(
          height: AppCircularProgressIndicatorSize,
          width: AppCircularProgressIndicatorSize,
          child:
              CircularProgressIndicator(strokeWidth: AppStrokeWidthMedium),
        ),
      ),
      errorWidget: (context, url, error) => _errorPlaceholder(),
    );
  }

  Widget _errorPlaceholder() {
    return const ColoredBox(
      color: Colors.black12,
      child: Center(child: Icon(Icons.broken_image)),
    );
  }
}
