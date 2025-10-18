import 'dart:io';

import 'package:flutter/material.dart';

import '../data/photo.dart';
import '../../app_constants.dart';

/// Renders a photo summary card and optionally exposes selection affordances.
class PhotoListTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final bool isTileDisabled = isDownloading;
    final effectiveOnTap =
        isTileDisabled
            ? null
            : (isSelectionMode ? (onSelectionToggle ?? onTap) : onTap);
    final effectiveOnLongPress = isTileDisabled ? null : onLongPress;
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
                  if (isSelectionMode)
                    Positioned.fill(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        color:
                            isSelected
                                ? Colors.black.withOpacity(0.35)
                                : Colors.black.withOpacity(0.15),
                      ),
                    ),
                  if (isDownloading)
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
                  if (isSelectionMode)
                    Positioned(
                      top: AppSpacingSmall,
                      right: AppSpacingSmall,
                      child: CircleAvatar(
                        radius: AppCircleAvatarRadius,
                        backgroundColor:
                            isSelected
                                ? theme.colorScheme.primary
                                : Colors.white,
                        foregroundColor:
                            isSelected ? Colors.white : Colors.black54,
                        child: Icon(
                          isSelected ? Icons.check : Icons.circle_outlined,
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
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: Colors.white,
                          ),
                          onPressed: onFavoritePressed,
                          tooltip:
                              isFavorite
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
                  Text(photo.description, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacingSmall),
                  Row(
                    children: [
                      const Icon(Icons.place, size: AppIconSizeSmall),
                      const SizedBox(width: AppSpacingExtraSmall),
                      Expanded(child: Text(photo.location)),
                    ],
                  ),
                  const SizedBox(height: AppSpacingExtraSmall),
                  Row(
                    children: [
                      const Icon(Icons.person, size: AppIconSizeSmall),
                      const SizedBox(width: AppSpacingExtraSmall),
                      Expanded(child: Text(photo.createdBy)),
                    ],
                  ),
                  const SizedBox(height: AppSpacingExtraSmall),
                  Row(
                    children: [
                      const Icon(Icons.camera_alt, size: AppIconSizeSmall),
                      const SizedBox(width: AppSpacingExtraSmall),
                      Text(_formatDate(photo.takenAt)),
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
    final localPath = photo.localImagePath;
    final ImageProvider imageProvider;

    if (localPath != null && File(localPath).existsSync()) {
      imageProvider = FileImage(File(localPath));
    } else {
      imageProvider = NetworkImage(photo.url);
    }

    return Image( // Use Image.file or Image.network with loadingBuilder
      image: imageProvider,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _errorPlaceholder(),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            child, // Show the image beneath the loading indicator
            Center(
              child: SizedBox(
                height: AppCircularProgressIndicatorSize,
                width: AppCircularProgressIndicatorSize,
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: AppStrokeWidthMedium,
                  color: Colors.white,
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _errorPlaceholder() {
    return const ColoredBox(
      color: Colors.black12,
      child: Center(child: Icon(Icons.broken_image)),
    );
  }
}
