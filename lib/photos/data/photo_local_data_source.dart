import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'photo.dart';

/// Function signature for resolving the cache directory (overridable in tests).
typedef DirectoryProvider = Future<Directory> Function();

/// Function signature for resolving the platform download directory.
typedef DownloadsDirectoryProvider = Future<Directory?> Function();

typedef FileDownloadHandler =
    Future<String?> Function({required String url, required String name});

/// Handles on-device caching and download persistence for photos.
class PhotoLocalDataSource {
  PhotoLocalDataSource({
    Dio? dio,
    DirectoryProvider? directoryProvider,
    DownloadsDirectoryProvider? downloadsDirectoryProvider,
    FileDownloadHandler? fileDownloadHandler,
  }) : _dio = dio ?? Dio(),
       _directoryProvider = directoryProvider ?? _defaultDirectoryProvider,
       _downloadsDirectoryProvider =
           downloadsDirectoryProvider ?? _defaultDownloadsDirectoryProvider,
       _fileDownloadHandler =
           fileDownloadHandler ?? _defaultFileDownloadHandler;

  static const _metadataFileName = 'photos-cache.json';
  static const _favoritesFileName = 'favorites.json';

  final Dio _dio;
  final DirectoryProvider _directoryProvider;
  final DownloadsDirectoryProvider _downloadsDirectoryProvider;
  final FileDownloadHandler _fileDownloadHandler;

  Directory? _cacheDirectory;
  File? _metadataFile;
  File? _favoritesFile;

  /// Reads cached photos from disk; returns null when nothing has been stored yet.
  Future<List<Photo>?> readPhotos() async {
    final metadataFile = await _ensureMetadataFile();
    if (!await metadataFile.exists()) {
      return null;
    }
    final content = await metadataFile.readAsString();
    if (content.trim().isEmpty) {
      return null;
    }
    final raw = jsonDecode(content) as List<dynamic>;
    return raw
        .map((item) => Photo.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Downloads remote photos, persists them to cache, and returns the updated list.
  Future<List<Photo>> savePhotos(
    List<Photo> photos, {
    bool overwriteExisting = false,
  }) async {
    final cacheDirectory = await _ensureCacheDirectory();
    final stored = <Photo>[];

    for (final photo in photos) {
      final fileName = _buildFileName(photo);
      final filePath = p.join(cacheDirectory.path, fileName);
      final file = File(filePath);

      if (overwriteExisting && await file.exists()) {
        await file.delete();
      }

      if (!await file.exists()) {
        await _downloadImage(photo.url, file);
      }

      stored.add(photo.copyWith(localImagePath: filePath));
    }

    await _writeMetadata(stored);
    return stored;
  }

  /// Removes cached files and metadata so the next request triggers a fresh download.
  Future<void> clear() async {
    final cacheDirectory = await _ensureCacheDirectory();
    if (await cacheDirectory.exists()) {
      await for (final entity in cacheDirectory.list()) {
        await entity.delete(recursive: true);
      }
    }
    final metadataFile = await _ensureMetadataFile();
    if (await metadataFile.exists()) {
      await metadataFile.delete();
    }
  }

  /// Downloads a single photo, updates metadata, and returns the record with a local path.
  Future<Photo> downloadPhoto(
    Photo photo, {
    bool overwriteExisting = false,
  }) async {
    final cacheDirectory = await _ensureCacheDirectory();
    final fileName = _buildFileName(photo);
    final cachePath = p.join(cacheDirectory.path, fileName);
    final cacheFile = File(cachePath);

    if (overwriteExisting && await cacheFile.exists()) {
      await cacheFile.delete();
    }

    if (!await cacheFile.exists()) {
      await _downloadImage(photo.url, cacheFile);
    }

    var persistedPath = cachePath;
    String? downloadedPath;
    if (Platform.isAndroid) {
      downloadedPath = await _fileDownloadHandler(
        url: photo.url,
        name: fileName,
      );
    }

    if (downloadedPath == null) {
      final downloadsDirectory = await _downloadsDirectoryProvider();
      if (downloadsDirectory != null) {
        if (!await downloadsDirectory.exists()) {
          await downloadsDirectory.create(recursive: true);
        }
        final downloadsFile = File(p.join(downloadsDirectory.path, fileName));
        await downloadsFile.writeAsBytes(
          await cacheFile.readAsBytes(),
          flush: true,
        );
        persistedPath = downloadsFile.path;
      }
    } else {
      persistedPath = downloadedPath;
    }

    final updatedPhoto = photo.copyWith(localImagePath: persistedPath);
    final existing = await readPhotos() ?? <Photo>[];
    final merged = <Photo>[];
    var replaced = false;
    for (final item in existing) {
      if (item.id == updatedPhoto.id) {
        merged.add(updatedPhoto);
        replaced = true;
      } else {
        merged.add(item);
      }
    }
    if (!replaced) {
      merged.add(updatedPhoto);
    }
    await _writeMetadata(merged);
    return updatedPhoto;
  }

  Future<Set<String>> readFavoriteIds() async {
    final file = await _ensureFavoritesFile();
    if (!await file.exists()) {
      return <String>{};
    }
    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      return <String>{};
    }
    final raw = jsonDecode(content) as List<dynamic>;
    return raw.map((id) => id as String).toSet();
  }

  Future<Set<String>> saveFavoriteIds(Set<String> favorites) async {
    final file = await _ensureFavoritesFile();
    final ordered = favorites.toList()..sort();
    await file.writeAsString(jsonEncode(ordered), flush: true);
    return Set<String>.unmodifiable(ordered);
  }

  Future<File> _ensureMetadataFile() async {
    _metadataFile ??= File(
      p.join((await _ensureCacheDirectory()).path, _metadataFileName),
    );
    return _metadataFile!;
  }

  Future<File> _ensureFavoritesFile() async {
    _favoritesFile ??= File(
      p.join((await _ensureCacheDirectory()).path, _favoritesFileName),
    );
    return _favoritesFile!;
  }

  Future<Directory> _ensureCacheDirectory() async {
    if (_cacheDirectory != null) {
      return _cacheDirectory!;
    }
    final directory = await _directoryProvider();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    _cacheDirectory = directory;
    return _cacheDirectory!;
  }

  Future<void> _downloadImage(String url, File file) async {
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw const PhotoCacheException(
          'Image download returned an empty payload',
        );
      }
      await file.writeAsBytes(bytes, flush: true);
    } on DioException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PhotoCacheException(error.message ?? 'Image download failed'),
        stackTrace,
      );
    }
  }

  String _buildFileName(Photo photo) {
    final uri = Uri.parse(photo.url);
    final original =
        uri.pathSegments.isNotEmpty ? uri.pathSegments.last : photo.id;
    final sanitizedId = photo.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final extension =
        p.extension(original).isEmpty ? '.jpg' : p.extension(original);
    return '$sanitizedId$extension';
  }

  Future<void> _writeMetadata(List<Photo> photos) async {
    final metadataFile = await _ensureMetadataFile();
    final serialized = photos
        .map((photo) => photo.toJson())
        .toList(growable: false);
    await metadataFile.writeAsString(jsonEncode(serialized), flush: true);
  }

  static Future<Directory> _defaultDirectoryProvider() async {
    final directory = await getApplicationSupportDirectory();
    return Directory(p.join(directory.path, 'photo_cache'));
  }

  static Future<Directory?> _defaultDownloadsDirectoryProvider() async {
    if (Platform.isAndroid) {
      final manual = Directory('/storage/emulated/0/Download');
      if (await manual.exists()) {
        return manual;
      }
    }
    try {
      final fallback = await getApplicationSupportDirectory();
      return Directory(p.join(fallback.path, 'downloads'));
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _defaultFileDownloadHandler({
    required String url,
    required String name,
  }) async {
    // Hand back null so the caller copies from cache into the target directory (avoids noisy logging).
    return null;
  }
}

/// Exception thrown when the local caching flow fails.
class PhotoCacheException implements Exception {
  const PhotoCacheException(this.message);

  final String message;

  @override
  String toString() => 'PhotoCacheException: $message';
}
