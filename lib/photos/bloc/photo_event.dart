part of 'photo_bloc.dart';

/// Base class for all interactions handled by [PhotoBloc].
sealed class PhotoEvent extends Equatable {
  const PhotoEvent();

  @override
  List<Object?> get props => const [];
}

/// Triggered when the gallery should fetch a fresh list of photos.
class PhotoRequested extends PhotoEvent {
  const PhotoRequested();
}

/// Triggered by pull-to-refresh gestures.
class PhotoRefreshed extends PhotoEvent {
  const PhotoRefreshed();
}

/// Updates the search query in reaction to text-field input changes.
class PhotoSearchQueryChanged extends PhotoEvent {
  const PhotoSearchQueryChanged(this.query);

  /// The latest free-form keyword typed by the user.
  final String query;

  @override
  List<Object?> get props => [query];
}

/// Persists a search query into the recent history after submission.
class PhotoSearchSubmitted extends PhotoEvent {
  const PhotoSearchSubmitted(this.query);

  /// Search keyword committed by the user.
  final String query;

  @override
  List<Object?> get props => [query];
}

/// Toggles a location filter chip.
class PhotoLocationFilterToggled extends PhotoEvent {
  const PhotoLocationFilterToggled(this.location);

  /// Human readable location name.
  final String location;

  @override
  List<Object?> get props => [location];
}

/// Toggles a creator filter chip.
class PhotoCreatorFilterToggled extends PhotoEvent {
  const PhotoCreatorFilterToggled(this.creator);

  /// Photographer or uploader name.
  final String creator;

  @override
  List<Object?> get props => [creator];
}

/// Toggles the favorite status for a specific photo id.
class PhotoFavoriteToggled extends PhotoEvent {
  const PhotoFavoriteToggled(this.photoId);

  /// Identifier of the photo to toggle.
  final String photoId;

  @override
  List<Object?> get props => [photoId];
}

/// Downloads a single photo to local storage.
class PhotoDownloadRequested extends PhotoEvent {
  const PhotoDownloadRequested(this.photo);

  /// Photo metadata required to perform the download.
  final Photo photo;

  @override
  List<Object?> get props => [photo];
}

/// Requests a page change for the regular gallery listing.
class PhotoPageNumberChanged extends PhotoEvent {
  const PhotoPageNumberChanged(this.pageNumber);

  /// Zero-based page index.
  final int pageNumber;

  @override
  List<Object?> get props => [pageNumber];
}

/// Requests a page change for the favorites listing.
class PhotoFavoritePageNumberChanged extends PhotoEvent {
  const PhotoFavoritePageNumberChanged(this.pageNumber);

  /// Zero-based page index for favorites.
  final int pageNumber;

  @override
  List<Object?> get props => [pageNumber];
}

/// Switches between list and masonry layout modes.
class PhotoLayoutModeChanged extends PhotoEvent {
  const PhotoLayoutModeChanged(this.mode);

  /// Preferred gallery layout mode.
  final GalleryLayoutMode mode;

  @override
  List<Object?> get props => [mode];
}

/// Activates multi-select mode, optionally pre-selecting the photo that triggered it.
class PhotoSelectionModeStarted extends PhotoEvent {
  const PhotoSelectionModeStarted({this.anchorPhotoId});

  /// Optional photo id to include immediately when entering selection mode.
  final String? anchorPhotoId;

  @override
  List<Object?> get props => [anchorPhotoId];
}

/// Toggles the selection checkbox for a photo.
class PhotoSelectionToggled extends PhotoEvent {
  const PhotoSelectionToggled(this.photoId);

  /// Identifier of the photo to toggle.
  final String photoId;

  @override
  List<Object?> get props => [photoId];
}

/// Clears all selected items and exits selection mode.
class PhotoSelectionCleared extends PhotoEvent {
  const PhotoSelectionCleared();
}

/// Initiates a batch download for every currently selected photo.
class PhotoBatchDownloadRequested extends PhotoEvent {
  const PhotoBatchDownloadRequested();
}
