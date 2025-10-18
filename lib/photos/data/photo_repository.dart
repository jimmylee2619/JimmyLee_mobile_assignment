import 'dart:async';
import 'photo.dart';
import 'photo_api_client.dart';
import 'photo_local_data_source.dart';
import 'photo_sort_order.dart';

/// Integrates the remote API and local cache to serve data to the BLoC layer.
class PhotoRepository {
  PhotoRepository({
    required PhotoApiClient apiClient,
    PhotoLocalDataSource? localDataSource,
  }) : _apiClient = apiClient,
       _localDataSource = localDataSource ?? PhotoLocalDataSource();

  final PhotoApiClient _apiClient;
  final PhotoLocalDataSource _localDataSource;

  List<Photo>? _cache;
  Set<String> _favoriteIds = <String>{};
  bool _favoritesLoaded = false;

  /// Returns cached content unless [forceRefresh] mandates a new fetch.
  Future<List<Photo>> fetchPhotos({bool forceRefresh = false, PhotoSortOrder? sortOrder}) async {
    await _ensureFavoritesLoaded();
    if (!forceRefresh && _cache != null) {
      return _cache!;
    }

    if (!forceRefresh) {
      final localPhotos = await _localDataSource.readPhotos();
      if (localPhotos != null && localPhotos.isNotEmpty) {
        _cache = sorted(localPhotos, sortOrder ?? PhotoSortOrder.descending);
        return _cache!;
      }
    }

    try {
      final remotePhotos = await _apiClient.fetchPhotos().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Failed to load photos: Connection timed out');
        },
      );
      final persisted = await _localDataSource.savePhotos(
        remotePhotos,
        overwriteExisting: forceRefresh,
      );
      _cache = sorted(persisted, sortOrder ?? PhotoSortOrder.descending);
      return _cache!;
    } catch (error, stackTrace) {
      final fallback = await _localDataSource.readPhotos();
      if (fallback != null && fallback.isNotEmpty) {
        _cache = sorted(fallback, sortOrder ?? PhotoSortOrder.descending);
        return _cache!;
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Clears both in-memory and on-disk caches to force a fresh download next time.
  Future<void> invalidate() async {
    _cache = null;
    await _localDataSource.clear();
  }

  /// Reads the current set of favorite photo identifiers.
  Future<Set<String>> getFavoriteIds() async {
    await _ensureFavoritesLoaded();
    return _favoriteIds;
  }

  /// Toggles the favorite flag for the given photo and returns the updated set.
  Future<Set<String>> toggleFavorite(String photoId) async {
    await _ensureFavoritesLoaded();
    final next = Set<String>.from(_favoriteIds);
    if (!next.add(photoId)) {
      next.remove(photoId);
    }
    _favoriteIds = await _localDataSource.saveFavoriteIds(next);
    return _favoriteIds;
  }

  /// Downloads a single photo and synchronizes the cached copy.
  Future<Photo> downloadPhoto(
    Photo photo, {
    bool overwriteExisting = false,
  }) async {
    final updated = await _localDataSource.downloadPhoto(
      photo,
      overwriteExisting: overwriteExisting,
    );
    final base = _cache ?? await _localDataSource.readPhotos() ?? <Photo>[];
    final merged = <Photo>[];
    var replaced = false;
    for (final item in base) {
      if (item.id == updated.id) {
        merged.add(updated);
        replaced = true;
      } else {
        merged.add(item);
      }
    }
    if (!replaced) {
      merged.add(updated);
    }
    _cache = sorted(merged, PhotoSortOrder.descending); // Maintain default sorting for downloads
    return updated;
  }

  List<Photo> sorted(List<Photo> source, PhotoSortOrder sortOrder) {
    final sorted = List<Photo>.of(source)
      ..sort(
        (a, b) => sortOrder == PhotoSortOrder.ascending
            ? a.takenAt.compareTo(b.takenAt)
            : b.takenAt.compareTo(a.takenAt),
      );
    return List<Photo>.unmodifiable(sorted);
  }

  Future<void> _ensureFavoritesLoaded() async {
    if (_favoritesLoaded) {
      return;
    }
    _favoriteIds = await _localDataSource.readFavoriteIds();
    _favoritesLoaded = true;
  }
}
