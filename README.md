# Photo Gallery

**This is Jimmy Lee work for mobile assignment.**

Flutter application that displays a paginated photo gallery backed by a REST
API. State is orchestrated with `flutter_bloc`; the UI supports search,
filtering, favorites, multi-select downloads, and a masonry layout toggle.

## Supported Platforms
- Android (API 21+)
- iOS (iOS 13+)

## Key Dependencies
- `flutter_bloc`: State management for UI events and state snapshots.
- `dio`: HTTP client for network requests to fetch JSON payloads.
- `path_provider`: Provides access to platform-specific file system locations for local data storage.
- `cached_network_image`: Efficiently loads and caches images from the network.
- `flutter_staggered_grid_view`: Implements the masonry layout for photo display.
- `equatable`: Simplifies value equality comparisons for Dart objects.

## Environment
- Flutter 3.31.0-0.1.pre (channel beta)
- Dart ^3.0.5
- Android SDK 34+, Xcode 15+ (for iOS)

```bash
flutter --version
dart --version
```

## Architecture

```
Remote API --> PhotoApiClient --> PhotoRepository --> PhotoBloc --> Widgets
                     |                             |
                     +--> PhotoLocalDataSource <---+
```

- **PhotoApiClient** wraps `dio` to fetch the JSON payload.
- **PhotoRepository** chooses between in-memory cache, disk cache, and remote
  fetches; it also manages favorites and download requests.
- **PhotoLocalDataSource** persists images and metadata using `path_provider`
  directories. On Android it tries `/storage/emulated/0/Download`; on iOS it
  falls back to the App Support directory.
- **PhotoBloc** emits `PhotoState` snapshots in response to UI events.
- **PhotoPage** and related widgets consume the state via `BlocBuilder` and
  render list or masonry layouts.

## BLoC Workflow

| Event | Trigger | State impact |
| --- | --- | --- |
| `PhotoRequested` | Initial load / returning to screen | Sets `status=loading`, then populates `allPhotos`, `displayPhotos`, `favoriteIds`. |
| `PhotoRefreshed` | Pull-to-refresh | Forces a remote fetch and resets pagination, selection, download flags. |
| `PhotoSearchQueryChanged` | Text field changes | Updates `searchQuery`, recomputes filtered lists, resets to first page. |
| `PhotoSearchSubmitted` | Submit / keyboard action | Stores the keyword in `recentSearches` (max 3). |
| `PhotoLocationFilterToggled` / `PhotoCreatorFilterToggled` | Chip tap | Adds/removes filters and rebuilds lists + pagination. |
| `PhotoLayoutModeChanged` | Segmented control | Switches between list and masonry layouts (non-destructive). |
| `PhotoSelectionModeStarted` | Long press | Enables multi-select mode and optionally pre-selects the pressed item. |
| `PhotoSelectionToggled` | Checkbox tap | Toggles a photo inside `selectedPhotoIds`. |
| `PhotoSelectionCleared` | AppBar close | Exits multi-select mode and clears `selectedPhotoIds`. |
| `PhotoDownloadRequested` | Tile/detail download button | Adds the id to `downloadingPhotoIds`; on success, emits `infoMessage` with the saved path; on failure, emits `errorMessage`. |
| `PhotoBatchDownloadRequested` | AppBar batch download | Iterates over all selected photos, updates cache, summarizes successes and failures, then clears selection. |
| `PhotoFavoriteToggled` | Heart icon | Delegates to repository, refreshes `favoriteIds` and favorites listing. |
| `PhotoPageNumberChanged` / `PhotoFavoritePageNumberChanged` | Pagination controls | Moves through pages for gallery or favorites respectively. |

### Key State Fields
- `status`: `initial | loading | success | failure`
- `allPhotos`, `photos`, `displayPhotos`: base data, filtered list, current page
- `favoriteIds`, `filteredFavoritePhotos`, `favoriteDisplayPhotos`
- `searchQuery`, `selectedLocations`, `selectedCreators`, `recentSearches`
- `currentPage`, `totalPages`, `favoriteCurrentPage`, `favoriteTotalPages`
- `layoutMode`: list or masonry
- `isSelectionMode`, `selectedPhotoIds`, `downloadingPhotoIds`
- `infoMessage`, `errorMessage` for transient UI banners/snackbars

## Screens & Behaviour

### All Photos
- Default list layout with five items per page (adjust `_pageSize` in
  `PhotoBloc` to change).
- Search field filters by description, location, or creator; focusing the field
  reveals recent searches.
- Filter button opens a dialog with multi-select chips for locations and
  creators.
- Long press enters selection mode, showing a contextual AppBar with batch
  download capability.
- Tapping a tile navigates to the detail page unless selection mode is active.

### Favorites
- Renders only photos whose ids exist in `favoriteIds` using the same
  `PhotoCollectionView` widget.
- Shares search, filters, pagination, and selection logic with the main tab.

### Detail Page
- Displays description, location, creator, created/taken timestamps.
- Wraps the image in `InteractiveViewer` (pinch-to-zoom, double-tap zoom).
- Download button reflects progress based on `downloadingPhotoIds` and shows a
  snackbar once the download finishes or fails.

## Downloads & iOS Notes
- Android attempts the public Downloads folder (`/storage/emulated/0/Download`).
  On iOS the file is stored under the app support directory since iOS has no
  shared public Downloads location.
- Ensure the Xcode workspace is opened from `ios/Runner.xcworkspace`. Run
  `pod install` inside `ios/` if CocoaPods dependencies need to be refreshed.

## Running & Testing

```bash
# Fetch dependencies
flutter pub get

# Format source
dart format lib test

# Static analysis
flutter analyze

# Run unit and widget tests
flutter test

# Android debug build
flutter build apk --debug

# iOS debug build (requires macOS)
flutter build ios --debug

# Launch on a connected device or simulator
flutter run
```

## Troubleshooting
- **Download fails or path missing**: ensure the device grants storage access.
  When access is denied the app keeps a copy in its cache directory and shows
  an error message.
- **API unreachable**: the repository falls back to cached metadata when a
  network error is thrown.
- **iOS build warnings**: run `pod repo update` and `pod install` within the
  `ios/` directory, then retry `flutter build ios`.