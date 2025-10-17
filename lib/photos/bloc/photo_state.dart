part of 'photo_bloc.dart';

/// High-level load states emitted by the gallery BLoC.
enum PhotoStatus { initial, loading, success, failure }

/// Presentation layout options for the gallery screen.
enum GalleryLayoutMode { list, masonry }

/// Immutable snapshot of the gallery state consumed by the UI.
class PhotoState extends Equatable {
  const PhotoState({
    this.status = PhotoStatus.initial,
    this.allPhotos = const [],
    this.photos = const [],
    this.searchQuery = '',
    this.selectedLocations = const <String>{},
    this.selectedCreators = const <String>{},
    this.favoriteIds = const <String>{},
    this.recentSearches = const <String>[],
    this.errorMessage,
    this.infoMessage,
    this.filteredFavoritePhotos = const [],
    this.currentPage = 0,
    this.totalPages = 0,
    this.displayPhotos = const [],
    this.favoriteCurrentPage = 0,
    this.favoriteTotalPages = 0,
    this.favoriteDisplayPhotos = const [],
    this.layoutMode = GalleryLayoutMode.list,
    this.isSelectionMode = false,
    this.selectedPhotoIds = const <String>{},
    this.downloadingPhotoIds = const <String>{},
  });

  final PhotoStatus status;
  final List<Photo> allPhotos;
  final List<Photo> photos;
  final String searchQuery;
  final Set<String> selectedLocations;
  final Set<String> selectedCreators;
  final Set<String> favoriteIds;
  final List<String> recentSearches;
  final String? errorMessage;
  final String? infoMessage;
  final List<Photo> filteredFavoritePhotos;
  final int currentPage;
  final int totalPages;
  final List<Photo> displayPhotos;
  final int favoriteCurrentPage;
  final int favoriteTotalPages;
  final List<Photo> favoriteDisplayPhotos;
  final GalleryLayoutMode layoutMode;
  final bool isSelectionMode;
  final Set<String> selectedPhotoIds;
  final Set<String> downloadingPhotoIds;

  PhotoState copyWith({
    PhotoStatus? status,
    List<Photo>? allPhotos,
    List<Photo>? photos,
    String? errorMessage,
    String? searchQuery,
    Set<String>? selectedLocations,
    Set<String>? selectedCreators,
    Set<String>? favoriteIds,
    List<String>? recentSearches,
    String? infoMessage,
    bool clearErrorMessage = false,
    bool clearInfoMessage = false,
    List<Photo>? filteredFavoritePhotos,
    int? currentPage,
    int? totalPages,
    List<Photo>? displayPhotos,
    int? favoriteCurrentPage,
    int? favoriteTotalPages,
    List<Photo>? favoriteDisplayPhotos,
    GalleryLayoutMode? layoutMode,
    bool? isSelectionMode,
    Set<String>? selectedPhotoIds,
    Set<String>? downloadingPhotoIds,
  }) {
    return PhotoState(
      status: status ?? this.status,
      allPhotos: allPhotos ?? this.allPhotos,
      photos: photos ?? this.photos,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedLocations: selectedLocations ?? this.selectedLocations,
      selectedCreators: selectedCreators ?? this.selectedCreators,
      favoriteIds: favoriteIds ?? this.favoriteIds,
      recentSearches: recentSearches ?? this.recentSearches,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      infoMessage: clearInfoMessage ? null : infoMessage ?? this.infoMessage,
      filteredFavoritePhotos:
          filteredFavoritePhotos ?? this.filteredFavoritePhotos,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      displayPhotos: displayPhotos ?? this.displayPhotos,
      favoriteCurrentPage: favoriteCurrentPage ?? this.favoriteCurrentPage,
      favoriteTotalPages: favoriteTotalPages ?? this.favoriteTotalPages,
      favoriteDisplayPhotos:
          favoriteDisplayPhotos ?? this.favoriteDisplayPhotos,
      layoutMode: layoutMode ?? this.layoutMode,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedPhotoIds: selectedPhotoIds ?? this.selectedPhotoIds,
      downloadingPhotoIds: downloadingPhotoIds ?? this.downloadingPhotoIds,
    );
  }

  bool get isDownloading => downloadingPhotoIds.isNotEmpty;

  @override
  List<Object?> get props => [
    status,
    List<Photo>.from(allPhotos)..sort((a, b) => a.id.compareTo(b.id)),
    List<Photo>.from(photos)..sort((a, b) => a.id.compareTo(b.id)),
    searchQuery,
    List<String>.from(selectedLocations)..sort(),
    List<String>.from(selectedCreators)..sort(),
    List<String>.from(favoriteIds)..sort(),
    recentSearches,
    errorMessage,
    infoMessage,
    List<Photo>.from(filteredFavoritePhotos)
      ..sort((a, b) => a.id.compareTo(b.id)),
    currentPage,
    totalPages,
    List<Photo>.from(displayPhotos)..sort((a, b) => a.id.compareTo(b.id)),
    favoriteCurrentPage,
    favoriteTotalPages,
    favoriteDisplayPhotos,
    layoutMode,
    isSelectionMode,
    List<String>.from(selectedPhotoIds)..sort(),
    List<String>.from(downloadingPhotoIds)..sort(),
  ];
}
