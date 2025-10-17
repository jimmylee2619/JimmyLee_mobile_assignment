import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/photo_bloc.dart';
import '../data/photo.dart';
import 'package:photo_gallery/app_constants.dart';

/// Displays metadata and actions for a single photo.
class PhotoDetailPage extends StatelessWidget {
  const PhotoDetailPage({super.key, required this.photo});

  static Route<void> route(Photo photo) {
    return MaterialPageRoute<void>(
      builder: (_) => PhotoDetailPage(photo: photo),
    );
  }

  final Photo photo;

  @override
  Widget build(BuildContext context) {
    return BlocListener<PhotoBloc, PhotoState>(
      listenWhen:
          (previous, current) => previous.infoMessage != current.infoMessage,
      listener: (context, state) {
        final message = state.infoMessage;
        if (message != null && message.isNotEmpty) {
          showAppSnackBar(context, message);
        }
      },
      child: BlocBuilder<PhotoBloc, PhotoState>(
        builder: (context, state) {
          final latest = state.allPhotos.firstWhere(
            (item) => item.id == photo.id,
            orElse: () => photo,
          );
          final isFavorite = state.favoriteIds.contains(latest.id);
          final theme = Theme.of(context);
          final isDownloading = state.downloadingPhotoIds.contains(latest.id);
          return Scaffold(
            appBar: AppBar(title: const Text('Photo details')),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: AppBorderRadius,
                    child: GestureDetector(
                      onTap: () => _showImagePreview(context, latest),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          AspectRatio(
                            aspectRatio: 4 / 3,
                            child: _buildImage(latest),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacingMedium),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: AppBorderRadius,
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppSpacingMedium,
                                  vertical: AppSpacingXSmall,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.fullscreen,
                                      size: AppIconSizeSmall,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: AppSpacingXSmall),
                                    Text(
                                      'Tap to open preview',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: AppFontSizeSmall,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacingExtraLarge),
                  Text(
                    latest.description,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacingLarge),
                  _DetailItem(
                    icon: Icons.place,
                    label: 'Location',
                    value: latest.location,
                  ),
                  _DetailItem(
                    icon: Icons.person,
                    label: 'Creator',
                    value: latest.createdBy,
                  ),
                  _DetailItem(
                    icon: Icons.calendar_month,
                    label: 'Captured on',
                    value: _formatDateTime(latest.takenAt),
                  ),
                  _DetailItem(
                    icon: Icons.upload,
                    label: 'Uploaded on',
                    value: _formatDateTime(latest.createdAt),
                  ),
                  const SizedBox(height: AppSpacingExtraLarge),
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: FilledButton.icon(
                          onPressed: isDownloading
                              ? null
                              : () {
                                  context.read<PhotoBloc>().add(
                                    PhotoDownloadRequested(latest),
                                  );
                                },
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: isDownloading
                                ? const SizedBox(
                                    key: ValueKey('downloadSpinner'),
                                    height: AppIconSizeMedium,
                                    width: AppIconSizeMedium,
                                    child: CircularProgressIndicator(
                                      strokeWidth: AppStrokeWidthSmall,
                                    ),
                                  )
                                : const Icon(
                                    Icons.download,
                                    key: ValueKey('downloadIcon'),
                                  ),
                          ),
                          label: Text(
                            isDownloading ? 'Downloading...' : 'Download image',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacingMedium),
                      Expanded(
                        flex: 1,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            context.read<PhotoBloc>().add(
                              PhotoFavoriteToggled(latest.id),
                            );
                          },
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                          ),
                          label: Text(
                            isFavorite
                                ? 'Remove favorites'
                                : 'Add to favorites',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildImage(Photo current) {
    final localPath = current.localImagePath;
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover, errorBuilder: _errorBuilder);
      }
    }
    return CachedNetworkImage(
      imageUrl: current.url,
      fit: BoxFit.cover,
      placeholder:
          (context, url) => const Center(child: CircularProgressIndicator()),
      errorWidget: (context, url, error) => _errorBuilder(context, error, null),
    );
  }

  Widget _errorBuilder(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    return const ColoredBox(
      color: Colors.black12,
      child: Center(child: Icon(Icons.broken_image)),
    );
  }

  Future<void> _showImagePreview(BuildContext context, Photo current) async {
    final controller = TransformationController();

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'image preview',
      barrierColor: Colors.black87,
      pageBuilder: (_, __, ___) {
        return StatefulBuilder(
          builder: (previewContext, setPreviewState) {
            void toggleZoom() {
              final isZoomed = controller.value != Matrix4.identity();
              setPreviewState(() {
                controller.value =
                    isZoomed
                        ? Matrix4.identity()
                        : (Matrix4.identity()..scale(2.5));
              });
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              onDoubleTap: toggleZoom,
              child: SafeArea(
                child: Stack(
                  children: [
                    Center(
                      child: InteractiveViewer(
                        transformationController: controller,
                        maxScale: 5,
                        minScale: 1,
                        child: AspectRatio(
                          aspectRatio:
                              current.localImagePath != null ? 4 / 3 : 1,
                          child: _buildFullScreenImage(current),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: AppSpacingExtraLarge,
                      left: AppSpacingExtraLarge,
                      right: AppSpacingExtraLarge,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacingLarge,
                            vertical: AppSpacingMedium,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: AppBorderRadius,
                          ),
                          child: const Text(
                            'Pinch or double-tap to zoom. Tap outside to close.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: AppFontSizeSmall,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();
  }

  Widget _buildFullScreenImage(Photo current) {
    final localPath = current.localImagePath;
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder:
              (context, error, stackTrace) =>
                  _errorBuilder(context, error, stackTrace),
        );
      }
    }
    return CachedNetworkImage(
      imageUrl: current.url,
      fit: BoxFit.contain,
      placeholder:
          (context, url) => const Center(child: CircularProgressIndicator()),
      errorWidget: (context, url, error) => _errorBuilder(context, error, null),
    );
  }
}

/// Convenience row showing an icon, label, and value pair.
class _DetailItem extends StatelessWidget {
  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacingMedium),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppIconSizeMedium),
          const SizedBox(width: AppSpacingSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelMedium),
                const SizedBox(height: AppSpacingExtraSmall),
                Text(value, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
