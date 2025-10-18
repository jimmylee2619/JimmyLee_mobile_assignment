import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../data/photo.dart';
import '../data/photo_repository.dart';
import '../data/photo_sort_order.dart';

part 'photo_event.dart';
part 'photo_state.dart';

/// Manages photo loading, filtering, pagination, selection, and download flows.
class PhotoBloc extends Bloc<PhotoEvent, PhotoState> {
  PhotoBloc({required PhotoRepository repository})
    : _repository = repository,
      super(const PhotoState()) {
    on<PhotoRequested>(_onRequested);
    on<PhotoRefreshed>(_onRefreshed);
    on<PhotoSearchQueryChanged>(_onSearchQueryChanged);
    on<PhotoSearchSubmitted>(_onSearchSubmitted);
    on<PhotoLocationFilterToggled>(_onLocationFilterToggled);
    on<PhotoCreatorFilterToggled>(_onCreatorFilterToggled);
    on<PhotoFavoriteToggled>(_onFavoriteToggled);
    on<PhotoDownloadRequested>(_onDownloadRequested);
    on<PhotoPageNumberChanged>(_onPhotoPageNumberChanged);
    on<PhotoFavoritePageNumberChanged>(_onPhotoFavoritePageNumberChanged);
    on<PhotoLayoutModeChanged>(_onLayoutModeChanged);
    on<PhotoSelectionModeStarted>(_onSelectionModeStarted);
    on<PhotoSelectionToggled>(_onSelectionToggled);
    on<PhotoSelectionCleared>(_onSelectionCleared);
    on<PhotoBatchDownloadRequested>(_onBatchDownloadRequested);
    on<PhotoSortOrderToggled>(_onSortOrderToggled);
  }

  static const int _pageSize = 6; // Changed from 5 to 6

  final PhotoRepository _repository;
  Completer<void>? _refreshCompleter;
  Future<void>? get refreshCompleter => _refreshCompleter?.future;

  /// Filters photos by keyword and optional location/creator tags.
  List<Photo> _applyFilters(
    List<Photo> source, {
    required String query,
    required Set<String> locations,
    required Set<String> creators,
  }) {
    final keyword = query.trim().toLowerCase();
    Iterable<Photo> filtered = source;
    if (keyword.isNotEmpty) {
      filtered = filtered.where(
        (photo) =>
            photo.description.toLowerCase().contains(keyword) ||
            photo.location.toLowerCase().contains(keyword) ||
            photo.createdBy.toLowerCase().contains(keyword),
      );
    }
    if (locations.isNotEmpty || creators.isNotEmpty) {
      filtered = filtered.where(
        (photo) =>
            locations.contains(photo.location) ||
            creators.contains(photo.createdBy),
      );
    }
    return filtered.toList(growable: false);
  }

  int _totalPages(List<Photo> items) {
    if (items.isEmpty) {
      return 0;
    }
    return (items.length / _pageSize).ceil();
  }

  int _clampPageIndex(List<Photo> items, int requestedIndex) {
    final pageCount = _totalPages(items);
    if (pageCount == 0) {
      return 0;
    }
    return requestedIndex.clamp(0, pageCount - 1);
  }

  List<Photo> _pageSlice(List<Photo> items, int pageIndex) {
    if (items.isEmpty) {
      return const [];
    }
    final safePage = _clampPageIndex(items, pageIndex);
    final start = safePage * _pageSize;
    final end = (start + _pageSize).clamp(0, items.length);
    return items.sublist(start, end);
  }

  /// Loads photos from cache or remote source and refreshes derived slices.
  Future<void> _loadPhotos({
    required bool forceRefresh,
    required Emitter<PhotoState> emit,
  }) async {
    emit(
      state.copyWith(
        status: PhotoStatus.loading,
        clearErrorMessage: true,
        clearInfoMessage: true,
      ),
    );

    _refreshCompleter = Completer<void>(); // Move to here

    try {
      final photos = await _repository.fetchPhotos(forceRefresh: forceRefresh, sortOrder: state.sortOrder);
      final favorites = await _repository.getFavoriteIds();
      _emitSuccess(
        emit,
        allPhotos: List<Photo>.unmodifiable(photos),
        favoriteIds: Set<String>.unmodifiable(favorites),
        resetPagination: true,
        resetSelection: true,
        resetDownloads: true,
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: PhotoStatus.failure,
          errorMessage: error.toString(),
          clearInfoMessage: true,
        ),
      );
    }
    _refreshCompleter?.complete(); // Also add here
  }

  /// Rebuilds filtered results, pagination data, and optional overrides (selection/download state).
  void _emitSuccess(
    Emitter<PhotoState> emit, {
    required List<Photo> allPhotos,
    required Set<String> favoriteIds,
    String? searchQuery,
    Set<String>? selectedLocations,
    Set<String>? selectedCreators,
    int? currentPage,
    int? favoriteCurrentPage,
    bool resetPagination = false,
    bool resetSelection = false,
    bool resetDownloads = false,
    Set<String>? selectionOverride,
    Set<String>? downloadingOverride,
    String? infoMessage,
    String? errorMessage,
    PhotoSortOrder? sortOrder,
    List<Photo>? filteredFavoritePhotos, // Add this line
  }) {
    final keyword = searchQuery ?? state.searchQuery;
    final locations = selectedLocations ?? state.selectedLocations;
    final creators = selectedCreators ?? state.selectedCreators;

    final filtered = _applyFilters(
      allPhotos,
      query: keyword,
      locations: locations,
      creators: creators,
    );

    final favoritePhotos = allPhotos
        .where((photo) => favoriteIds.contains(photo.id))
        .toList(growable: false);
    final filteredFavorites = _applyFilters(
      favoritePhotos,
      query: keyword,
      locations: locations,
      creators: creators,
    );

    final resolvedPage =
        resetPagination ? 0 : (currentPage ?? state.currentPage);
    final resolvedFavoritePage =
        resetPagination
            ? 0
            : (favoriteCurrentPage ?? state.favoriteCurrentPage);

    final displayPhotos = _pageSlice(filtered, resolvedPage);
    final favoriteDisplayPhotos = _pageSlice(
      filteredFavorites,
      resolvedFavoritePage,
    );

    final availableIds = allPhotos.map((photo) => photo.id).toSet();
    final nextSelection =
        selectionOverride ??
        (resetSelection
            ? const <String>{}
            : state.selectedPhotoIds.where(availableIds.contains).toSet());
    final nextDownloading =
        downloadingOverride ??
        (resetDownloads
            ? const <String>{}
            : state.downloadingPhotoIds.where(availableIds.contains).toSet());

    emit(
      state.copyWith(
        status: PhotoStatus.success,
        allPhotos: allPhotos,
        photos: List<Photo>.unmodifiable(filtered),
        searchQuery: keyword,
        selectedLocations: Set<String>.unmodifiable(locations),
        selectedCreators: Set<String>.unmodifiable(creators),
        favoriteIds: Set<String>.unmodifiable(favoriteIds),
        filteredFavoritePhotos: List<Photo>.unmodifiable(filteredFavorites),
        currentPage: _clampPageIndex(filtered, resolvedPage),
        totalPages: _totalPages(filtered),
        displayPhotos: List<Photo>.unmodifiable(displayPhotos),
        favoriteCurrentPage: _clampPageIndex(
          filteredFavorites,
          resolvedFavoritePage,
        ),
        favoriteTotalPages: _totalPages(filteredFavorites),
        favoriteDisplayPhotos: List<Photo>.unmodifiable(favoriteDisplayPhotos),
        isSelectionMode: resetSelection ? false : state.isSelectionMode,
        selectedPhotoIds: Set<String>.unmodifiable(nextSelection),
        downloadingPhotoIds: Set<String>.unmodifiable(nextDownloading),
        clearErrorMessage: errorMessage == null,
        errorMessage: errorMessage ?? state.errorMessage,
        clearInfoMessage: infoMessage == null,
        infoMessage: infoMessage ?? state.infoMessage,
        sortOrder: sortOrder ?? state.sortOrder,
      ),
    );
  }

  void _onSortOrderToggled(
    PhotoSortOrderToggled event,
    Emitter<PhotoState> emit,
  ) {
    final nextSortOrder = state.sortOrder == PhotoSortOrder.ascending
        ? PhotoSortOrder.descending
        : PhotoSortOrder.ascending;

    final sortedAllPhotos = _repository.sorted(state.allPhotos, nextSortOrder);
    final sortedFavoritePhotos = _repository.sorted(state.filteredFavoritePhotos, nextSortOrder);

    _emitSuccess(
      emit,
      allPhotos: sortedAllPhotos,
      favoriteIds: state.favoriteIds,
      sortOrder: nextSortOrder,
      resetPagination: true,
      filteredFavoritePhotos: sortedFavoritePhotos,
    );
  }

  Future<void> _onRequested(
    PhotoRequested event,
    Emitter<PhotoState> emit,
  ) async {
    if (state.status == PhotoStatus.loading) {
      return;
    }

    await _loadPhotos(forceRefresh: false, emit: emit);
  }

  Future<void> _onRefreshed(
    PhotoRefreshed event,
    Emitter<PhotoState> emit,
  ) async {
    await _loadPhotos(forceRefresh: true, emit: emit);
  }

  void _onSearchQueryChanged(
    PhotoSearchQueryChanged event,
    Emitter<PhotoState> emit,
  ) {
    _emitSuccess(
      emit,
      allPhotos: state.allPhotos,
      favoriteIds: state.favoriteIds,
      searchQuery: event.query,
      resetPagination: true,
      infoMessage: null,
      errorMessage: null,
    );
  }

  void _onSearchSubmitted(
    PhotoSearchSubmitted event,
    Emitter<PhotoState> emit,
  ) {
    final trimmed = event.query.trim();
    var updatedHistory = state.recentSearches;
    if (trimmed.isNotEmpty) {
      final deduped = [
        trimmed,
        ...updatedHistory.where((item) => item != trimmed),
      ];
      updatedHistory = deduped.take(3).toList(growable: false);
    }
    emit(state.copyWith(recentSearches: updatedHistory));
  }

  void _onPhotoPageNumberChanged(
    PhotoPageNumberChanged event,
    Emitter<PhotoState> emit,
  ) {
    if (state.status == PhotoStatus.loading || state.photos.isEmpty) {
      emit(
        state.copyWith(
          currentPage: 0,
          displayPhotos: const [],
          clearInfoMessage: true,
        ),
      );
      return;
    }

    final pageNumber = _clampPageIndex(state.photos, event.pageNumber);
    final newDisplayPhotos = _pageSlice(state.photos, pageNumber);

    emit(
      state.copyWith(
        displayPhotos: List<Photo>.unmodifiable(newDisplayPhotos),
        currentPage: pageNumber,
        clearInfoMessage: true,
      ),
    );
  }

  void _onPhotoFavoritePageNumberChanged(
    PhotoFavoritePageNumberChanged event,
    Emitter<PhotoState> emit,
  ) {
    if (state.status == PhotoStatus.loading ||
        state.filteredFavoritePhotos.isEmpty) {
      emit(
        state.copyWith(
          favoriteCurrentPage: 0,
          favoriteDisplayPhotos: const [],
          clearInfoMessage: true,
        ),
      );
      return;
    }

    final pageNumber = _clampPageIndex(
      state.filteredFavoritePhotos,
      event.pageNumber,
    );
    final newDisplayPhotos = _pageSlice(
      state.filteredFavoritePhotos,
      pageNumber,
    );

    emit(
      state.copyWith(
        favoriteDisplayPhotos: List<Photo>.unmodifiable(newDisplayPhotos),
        favoriteCurrentPage: pageNumber,
        clearInfoMessage: true,
      ),
    );
  }

  void _onLocationFilterToggled(
    PhotoLocationFilterToggled event,
    Emitter<PhotoState> emit,
  ) {
    final updated = Set<String>.from(state.selectedLocations);
    if (!updated.add(event.location)) {
      updated.remove(event.location);
    }
    _emitSuccess(
      emit,
      allPhotos: state.allPhotos,
      favoriteIds: state.favoriteIds,
      selectedLocations: updated,
      resetPagination: true,
    );
  }

  void _onCreatorFilterToggled(
    PhotoCreatorFilterToggled event,
    Emitter<PhotoState> emit,
  ) {
    final updated = Set<String>.from(state.selectedCreators);
    if (!updated.add(event.creator)) {
      updated.remove(event.creator);
    }
    _emitSuccess(
      emit,
      allPhotos: state.allPhotos,
      favoriteIds: state.favoriteIds,
      selectedCreators: updated,
      resetPagination: true,
    );
  }

  Future<void> _onFavoriteToggled(
    PhotoFavoriteToggled event,
    Emitter<PhotoState> emit,
  ) async {
    final favorites = await _repository.toggleFavorite(event.photoId);
    _emitSuccess(
      emit,
      allPhotos: state.allPhotos,
      favoriteIds: Set<String>.unmodifiable(favorites),
      resetPagination: false,
    );
  }

  Future<void> _onDownloadRequested(
    PhotoDownloadRequested event,
    Emitter<PhotoState> emit,
  ) async {
    final photoId = event.photo.id;

    if (state.downloadingPhotoIds.contains(photoId)) {
      return;
    }

    final downloadingWithTarget = Set<String>.from(state.downloadingPhotoIds)
      ..add(photoId);
    // Mark current photo as downloading and clear prior banners.
    emit(
      state.copyWith(
        downloadingPhotoIds: Set<String>.unmodifiable(downloadingWithTarget),
        clearErrorMessage: true,
        clearInfoMessage: true,
      ),
    );

    try {
      final updatedPhoto = await _repository.downloadPhoto(event.photo);
      // Replace cached entry with the downloaded version and update flags.
      final updatedAll = state.allPhotos
          .map((photo) => photo.id == updatedPhoto.id ? updatedPhoto : photo)
          .toList(growable: false);
      final remaining = Set<String>.from(downloadingWithTarget)
        ..remove(photoId);

      _emitSuccess(
        emit,
        allPhotos: List<Photo>.unmodifiable(updatedAll),
        favoriteIds: Set<String>.unmodifiable(state.favoriteIds),
        downloadingOverride: remaining,
        infoMessage:
            updatedPhoto.localImagePath != null
                ? 'Saved to ${updatedPhoto.localImagePath}'
                : 'Download completed',
      );
    } catch (error) {
      // On failure, clear the download flag and pass the error message to the UI.
      final remaining = Set<String>.from(downloadingWithTarget)
        ..remove(photoId);
      emit(
        state.copyWith(
          downloadingPhotoIds: Set<String>.unmodifiable(remaining),
          errorMessage: error.toString(),
          clearInfoMessage: true,
        ),
      );
    }
  }

  void _onLayoutModeChanged(
    PhotoLayoutModeChanged event,
    Emitter<PhotoState> emit,
  ) {
    if (state.layoutMode == event.mode) {
      return;
    }

    emit(state.copyWith(layoutMode: event.mode, clearInfoMessage: true));
  }

  void _onSelectionModeStarted(
    PhotoSelectionModeStarted event,
    Emitter<PhotoState> emit,
  ) {
    final nextSelection = Set<String>.from(state.selectedPhotoIds);
    final anchor = event.anchorPhotoId;

    if (anchor != null && state.allPhotos.any((photo) => photo.id == anchor)) {
      nextSelection.add(anchor);
    }

    emit(
      state.copyWith(
        isSelectionMode: true,
        selectedPhotoIds: Set<String>.unmodifiable(nextSelection),
        clearInfoMessage: true,
      ),
    );
  }

  void _onSelectionToggled(
    PhotoSelectionToggled event,
    Emitter<PhotoState> emit,
  ) {
    if (!state.isSelectionMode) {
      return;
    }

    final nextSelection = Set<String>.from(state.selectedPhotoIds);
    if (!nextSelection.add(event.photoId)) {
      nextSelection.remove(event.photoId);
    }

    final filteredSelection =
        nextSelection
            .where((id) => state.allPhotos.any((photo) => photo.id == id))
            .toSet();

    emit(
      state.copyWith(
        selectedPhotoIds: Set<String>.unmodifiable(filteredSelection),
        clearInfoMessage: true,
      ),
    );
  }

  void _onSelectionCleared(
    PhotoSelectionCleared event,
    Emitter<PhotoState> emit,
  ) {
    emit(
      state.copyWith(
        isSelectionMode: false,
        selectedPhotoIds: const <String>{},
        clearInfoMessage: true,
      ),
    );
  }

  Future<void> _onBatchDownloadRequested(
    PhotoBatchDownloadRequested event,
    Emitter<PhotoState> emit,
  ) async {
    if (state.selectedPhotoIds.isEmpty) {
      return;
    }

    final targetPhotos = state.allPhotos
        .where((photo) => state.selectedPhotoIds.contains(photo.id))
        .toList(growable: false);

    if (targetPhotos.isEmpty) {
      emit(
        state.copyWith(
          isSelectionMode: false,
          selectedPhotoIds: const <String>{},
          infoMessage:
              'Selection cleared because items are no longer available.',
          clearErrorMessage: true,
          clearInfoMessage: false,
        ),
      );
      return;
    }

    final downloading = Set<String>.from(state.downloadingPhotoIds)
      ..addAll(targetPhotos.map((photo) => photo.id));
    // Mark all targets as downloading up front to prevent duplicate triggers.
    emit(
      state.copyWith(
        downloadingPhotoIds: Set<String>.unmodifiable(downloading),
        clearErrorMessage: true,
        clearInfoMessage: true,
      ),
    );

    var updatedAll = state.allPhotos;
    final errors = <String>[];

    // Process downloads sequentially: update cache on success and collect error summaries.
    for (final photo in targetPhotos) {
      try {
        final downloaded = await _repository.downloadPhoto(photo);
        updatedAll = updatedAll
            .map((item) => item.id == downloaded.id ? downloaded : item)
            .toList(growable: false);
      } catch (error) {
        final label =
            photo.description.isNotEmpty ? photo.description : photo.id;
        errors.add('$label: $error');
      }
    }

    final targetIds = targetPhotos.map((photo) => photo.id).toSet();
    final remaining = Set<String>.from(downloading)..removeAll(targetIds);

    final successCount = targetPhotos.length - errors.length;
    final infoParts = <String>[];
    if (successCount > 0) {
      infoParts.add(
        'Downloaded $successCount item${successCount == 1 ? '' : 's'}.',
      );
    }

    // Summarize any failures so the UI can surface them to the user.
    String? errorMessage;
    if (errors.isNotEmpty) {
      final preview = errors.take(2).join('; ');
      errorMessage =
          'Failed ${errors.length} item${errors.length == 1 ? '' : 's'}: $preview';
    }

    final infoMessage = infoParts.isEmpty ? null : infoParts.join(' ');

    _emitSuccess(
      emit,
      allPhotos: List<Photo>.unmodifiable(updatedAll),
      favoriteIds: Set<String>.unmodifiable(state.favoriteIds),
      resetSelection: true,
      downloadingOverride: remaining,
      infoMessage: infoMessage,
      errorMessage: errorMessage,
    );
  }
}
