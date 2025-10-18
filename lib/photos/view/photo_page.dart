import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/photo_bloc.dart';
import '../data/photo.dart';
import '../data/photo_repository.dart';
import '../data/photo_sort_order.dart';
import '../../app_constants.dart';
import '../widgets/pagination_controls.dart';
import '../widgets/photo_collection_view.dart';
import 'photo_detail_page.dart';

/// Hosts the gallery page and wires up the backing BLoC.
class PhotoPage extends StatelessWidget {
  const PhotoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (context) =>
              PhotoBloc(repository: context.read<PhotoRepository>())
                ..add(const PhotoRequested()),
      child: const PhotoHomeView(),
    );
  }
}

/// Navigation container that switches between All Photos and Favorites.
class PhotoHomeView extends StatefulWidget {
  const PhotoHomeView({super.key});

  @override
  State<PhotoHomeView> createState() => _PhotoHomeViewState();
}

class _PhotoHomeViewState extends State<PhotoHomeView> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return BlocListener<PhotoBloc, PhotoState>(
      listenWhen:
          (previous, current) =>
              previous.infoMessage != current.infoMessage &&
              (current.infoMessage?.isNotEmpty ?? false),
      listener: (context, state) {
        final message = state.infoMessage;
        if (message != null && message.isNotEmpty) {
          showAppSnackBar(context, message);
        }
      },
      child: BlocBuilder<PhotoBloc, PhotoState>(
        builder: (context, state) {
          final bloc = context.read<PhotoBloc>();
          final isSelectionMode = state.isSelectionMode;
          final selectedCount = state.selectedPhotoIds.length;
          final selectionTitle =
              'Selected $selectedCount item${selectedCount == 1 ? '' : 's'}';

          return Scaffold(
            appBar: AppBar(
              // Surface contextual actions when multi-select mode is active.
              leading:
                  isSelectionMode
                      ? IconButton(
                        tooltip: 'Exit selection mode',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          bloc.add(const PhotoSelectionCleared());
                        },
                      )
                      : null,
              title: Text(
                isSelectionMode
                    ? selectionTitle
                    : (_currentIndex == 0 ? 'All Photos' : 'Favorites'),
              ),
              actions:
                  isSelectionMode
                      ? [
                        IconButton(
                          tooltip:
                              selectedCount == 0
                                  ? 'No items selected'
                                  : 'Download selected photos',
                          onPressed:
                              selectedCount == 0 || state.isDownloading
                                  ? null
                                  : () {
                                    bloc.add(
                                      const PhotoBatchDownloadRequested(),
                                    );
                                  },
                          icon: const Icon(Icons.download),
                        ),
                      ]
                      : [
                        IconButton(
                          tooltip: 'Filter',
                          icon: const Icon(Icons.tune),
                          onPressed: () => _openFilterDialog(state),
                        ),
                      ],
            ),
            body: IndexedStack(
              index: _currentIndex,
              children: const [PhotoGalleryView(), PhotoFavoritesView()],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _currentIndex,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.photo),
                  label: 'All Photos',
                ),
                NavigationDestination(
                  icon: Icon(Icons.favorite),
                  label: 'Favorites',
                ),
              ],
              onDestinationSelected: (index) {
                setState(() => _currentIndex = index);
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _openFilterDialog(PhotoState state) async {
    final bloc = context.read<PhotoBloc>();

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return BlocProvider.value(
          value: bloc,
          child: BlocBuilder<PhotoBloc, PhotoState>(
            builder: (context, blocState) {
              final locations = _uniqueSorted(
                blocState.allPhotos.map((photo) => photo.location),
              );
              final creators = _uniqueSorted(
                blocState.allPhotos.map((photo) => photo.createdBy),
              );

              return AlertDialog(
                title: const Text('Filter options'),
                content: SingleChildScrollView(
                  child: TagFilterSection(
                    locations: locations,
                    creators: creators,
                    selectedLocations: blocState.selectedLocations,
                    selectedCreators: blocState.selectedCreators,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      for (final location
                          in blocState.selectedLocations.toList()) {
                        bloc.add(PhotoLocationFilterToggled(location));
                      }
                      for (final creator
                          in blocState.selectedCreators.toList()) {
                        bloc.add(PhotoCreatorFilterToggled(creator));
                      }
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('Clear'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Done'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  List<String> _uniqueSorted(Iterable<String> values) {
    final set = <String>{};
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        set.add(trimmed);
      }
    }
    final list = set.toList()..sort();
    return list;
  }
}

class PhotoGalleryView extends StatefulWidget {
  const PhotoGalleryView({super.key});

  @override
  State<PhotoGalleryView> createState() => _PhotoGalleryViewState();
}

class _PhotoGalleryViewState extends State<PhotoGalleryView> with AutomaticKeepAliveClientMixin {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController()..addListener(_onSearchChanged);
    _focusNode = FocusNode()..addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onSearchChanged);
    _controller.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final bloc = context.read<PhotoBloc>();
    final query = _controller.text;
    if (bloc.state.searchQuery != query) {
      bloc.add(PhotoSearchQueryChanged(query));
    }
  }

  void _onFocusChanged() => setState(() {});

  void _applyRecentSearch(String value) {
    _controller
      ..text = value
      ..selection = TextSelection.fromPosition(
        TextPosition(offset: value.length),
      );
    _onSearchChanged();
  }

  void _onSearchSubmitted(String value) {
    context.read<PhotoBloc>().add(PhotoSearchSubmitted(value));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocListener<PhotoBloc, PhotoState>(
      listenWhen:
          (previous, current) => previous.searchQuery != current.searchQuery,
      listener: (context, state) {
        if (_controller.text != state.searchQuery) {
          _controller
            ..text = state.searchQuery
            ..selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
        }
      },
      child: BlocListener<PhotoBloc, PhotoState>( // Nested BlocListener for precaching
        listenWhen: (previous, current) =>
            previous.displayPhotos != current.displayPhotos,
        listener: (context, state) {
          for (final photo in state.displayPhotos) {
            if (photo.localImagePath != null) {
              precacheImage(FileImage(File(photo.localImagePath!)), context);
            }
          }
        },
        child: BlocBuilder<PhotoBloc, PhotoState>(
          builder: (context, state) {
            switch (state.status) {
              case PhotoStatus.initial:
              case PhotoStatus.loading:
                return const _LoadingIndicator();
              case PhotoStatus.failure:
                return _ErrorView(message: state.errorMessage);
              case PhotoStatus.success:
                return _buildSuccessContent(context, state);
            }
          },
        ),
      ),
    );
  }

  /// Builds the main gallery content once data is available.
  Widget _buildSuccessContent(BuildContext context, PhotoState state) {
    final bloc = context.read<PhotoBloc>();
    return PhotoCollectionView(
      headerWidgets: _buildHeaderWidgets(state, bloc),
      footerWidgets: _buildFooterWidgets(state, bloc),
      photos: state.displayPhotos,
      layoutMode: state.layoutMode,
      isSelectionMode: state.isSelectionMode,
      selectedPhotoIds: state.selectedPhotoIds,
      downloadingPhotoIds: state.downloadingPhotoIds,
      isFavorite: (photo) => state.favoriteIds.contains(photo.id),
      onFavoritePressed: (photo) => bloc.add(PhotoFavoriteToggled(photo.id)),
      onPhotoTap: (photo) => _handlePhotoTap(context, bloc, photo),
      onPhotoLongPress: (photo) => _handlePhotoLongPress(bloc, photo),
      onPhotoSelectionToggle: (photo) => _handleSelectionToggle(bloc, photo),
      onRefresh: () async {
        bloc.add(const PhotoRefreshed());
        await bloc.refreshCompleter; // Use the public getter
      },
      emptyPlaceholder: const _EmptyView(
        message: 'No photos match the current filters.',
      ),
    );
  }

  /// Assembles search, filters, and pagination controls for the header.
  List<Widget> _buildHeaderWidgets(PhotoState state, PhotoBloc bloc) {
    final widgets = <Widget>[];
    widgets.add(
      Row(
        children: [
          LayoutModeToggle(
            layoutMode: state.layoutMode,
            onChanged: (mode) => bloc.add(PhotoLayoutModeChanged(mode)),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Toggle sort order',
            icon: Icon(
              state.sortOrder == PhotoSortOrder.ascending
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
            ),
            onPressed: () => bloc.add(const PhotoSortOrderToggled()),
          ),
        ],
      ),
    );
    widgets.add(
      _SearchField(
        controller: _controller,
        focusNode: _focusNode,
        hintText: 'Search by description, location, or creator',
        onSubmitted: _onSearchSubmitted,
      ),
    );

    if (_focusNode.hasFocus && state.recentSearches.isNotEmpty) {
      widgets.add(
        _RecentSearches(
          searches: state.recentSearches,
          onSelected: _applyRecentSearch,
        ),
      );
    }

    final activeFilters = _buildActiveFilters(state, bloc);
    if (activeFilters != null) {
      widgets.add(activeFilters);
    }

    if (state.totalPages > 1) {
      widgets.add(
        PaginationControls(
          key: const Key('galleryPaginationControlsTop'),
          currentPage: state.currentPage,
          totalPages: state.totalPages,
          onPageChanged: (page) => bloc.add(PhotoPageNumberChanged(page)),
        ),
      );
    }

    return widgets;
  }

  /// Adds footer pagination controls when multiple pages are available.
  List<Widget> _buildFooterWidgets(PhotoState state, PhotoBloc bloc) {
    if (state.totalPages <= 1) {
      return const <Widget>[];
    }
    return [
      PaginationControls(
        key: const Key('galleryPaginationControlsBottom'),
        currentPage: state.currentPage,
        totalPages: state.totalPages,
        onPageChanged: (page) => bloc.add(PhotoPageNumberChanged(page)),
      ),
    ];
  }

  /// Handles tap behaviour: toggle selection when active, otherwise open detail.
  void _handlePhotoTap(BuildContext context, PhotoBloc bloc, Photo photo) {
    if (bloc.state.isSelectionMode) {
      bloc.add(PhotoSelectionToggled(photo.id));
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (routeContext) => BlocProvider.value(
              value: bloc,
              child: PhotoDetailPage(photo: photo),
            ),
      ),
    );
  }

  /// Long press enters selection mode and triggers light haptic feedback.
  void _handlePhotoLongPress(PhotoBloc bloc, Photo photo) {
    bloc.add(PhotoSelectionModeStarted(anchorPhotoId: photo.id));
    HapticFeedback.lightImpact();
  }

  /// Adds or removes the photo from the multi-select set when toggled.
  void _handleSelectionToggle(PhotoBloc bloc, Photo photo) {
    bloc.add(PhotoSelectionToggled(photo.id));
  }

  /// Renders active location/creator filter chips.
  Widget? _buildActiveFilters(PhotoState state, PhotoBloc bloc) {
    final chips = <Widget>[];

    for (final location in state.selectedLocations) {
      chips.add(
        InputChip(
          label: Text('Location: $location'),
          onDeleted: () => bloc.add(PhotoLocationFilterToggled(location)),
          shape: RoundedRectangleBorder(borderRadius: AppBorderRadius),
        ),
      );
    }

    for (final creator in state.selectedCreators) {
      chips.add(
        InputChip(
          label: Text('Creator: $creator'),
          onDeleted: () => bloc.add(PhotoCreatorFilterToggled(creator)),
          shape: RoundedRectangleBorder(borderRadius: AppBorderRadius),
        ),
      );
    }

    if (chips.isEmpty) {
      return null;
    }

    return Wrap(spacing: AppSpacingSmall, runSpacing: AppSpacingSmall, children: chips);
  }
}

class PhotoFavoritesView extends StatefulWidget {
  const PhotoFavoritesView({super.key});

  @override
  State<PhotoFavoritesView> createState() => _PhotoFavoritesViewState();
}

class _PhotoFavoritesViewState extends State<PhotoFavoritesView> with AutomaticKeepAliveClientMixin {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController()..addListener(_onSearchChanged);
    _focusNode = FocusNode()..addListener(_onFocusChanged);
  }

  void _onSearchChanged() {
    final bloc = context.read<PhotoBloc>();
    final query = _controller.text;
    if (bloc.state.searchQuery != query) {
      bloc.add(PhotoSearchQueryChanged(query));
    }
  }

  void _onFocusChanged() => setState(() {});

  void _applyRecentSearch(String value) {
    _controller
      ..text = value
      ..selection = TextSelection.fromPosition(
        TextPosition(offset: value.length),
      );
    _onSearchChanged();
  }

  void _onSearchSubmitted(String value) {
    context.read<PhotoBloc>().add(PhotoSearchSubmitted(value));
  }

  @override
  void dispose() {
    _controller.removeListener(_onSearchChanged);
    _controller.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocListener<PhotoBloc, PhotoState>(
      listenWhen:
          (previous, current) => previous.searchQuery != current.searchQuery,
      listener: (context, state) {
        if (_controller.text != state.searchQuery) {
          _controller
            ..text = state.searchQuery
            ..selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
        }
      },
      child: BlocListener<PhotoBloc, PhotoState>( // Nested BlocListener for precaching
        listenWhen: (previous, current) =>
            previous.favoriteDisplayPhotos != current.favoriteDisplayPhotos,
        listener: (context, state) {
          for (final photo in state.favoriteDisplayPhotos) {
            if (photo.localImagePath != null) {
              precacheImage(FileImage(File(photo.localImagePath!)), context);
            }
          }
        },
        child: BlocBuilder<PhotoBloc, PhotoState>(
          builder: (context, state) {
            switch (state.status) {
              case PhotoStatus.initial:
              case PhotoStatus.loading:
                return const _LoadingIndicator();
              case PhotoStatus.failure:
                return _ErrorView(message: state.errorMessage);
              case PhotoStatus.success:
                return _buildSuccessContent(context, state);
            }
          },
        ),
      ),
    );
  }

  /// Builds the favorites view along with multi-select behaviour.
  Widget _buildSuccessContent(BuildContext context, PhotoState state) {
    final bloc = context.read<PhotoBloc>();
    final headerWidgets = _buildHeaderWidgets(state, bloc);
    final footerWidgets = _buildFooterWidgets(state, bloc);

    return PhotoCollectionView(
      headerWidgets: headerWidgets,
      footerWidgets: footerWidgets,
      photos: state.favoriteDisplayPhotos,
      layoutMode: state.layoutMode,
      isSelectionMode: state.isSelectionMode,
      selectedPhotoIds: state.selectedPhotoIds,
      downloadingPhotoIds: state.downloadingPhotoIds,
      isFavorite: (photo) => state.favoriteIds.contains(photo.id),
      onFavoritePressed: (photo) => bloc.add(PhotoFavoriteToggled(photo.id)),
      onPhotoTap: (photo) => _handlePhotoTap(context, bloc, photo),
      onPhotoLongPress: (photo) => _handlePhotoLongPress(bloc, photo),
      onPhotoSelectionToggle: (photo) => _handleSelectionToggle(bloc, photo),
      onRefresh: () async {
        bloc.add(const PhotoRefreshed());
      },
      emptyPlaceholder: const _EmptyView(message: 'No favorites yet.'),
    );
  }

  /// Header controls for the favorites tab.
  List<Widget> _buildHeaderWidgets(PhotoState state, PhotoBloc bloc) {
    final widgets = <Widget>[
      LayoutModeToggle(
        layoutMode: state.layoutMode,
        onChanged: (mode) => bloc.add(PhotoLayoutModeChanged(mode)),
      ),
      _SearchField(
        controller: _controller,
        focusNode: _focusNode,
        hintText: 'Search favorites by description, location, or creator',
        onSubmitted: _onSearchSubmitted,
      ),
    ];

    if (_focusNode.hasFocus && state.recentSearches.isNotEmpty) {
      widgets.add(
        _RecentSearches(
          searches: state.recentSearches,
          onSelected: _applyRecentSearch,
        ),
      );
    }

    final activeFilters = _buildActiveFilters(state, bloc);
    if (activeFilters != null) {
      widgets.add(activeFilters);
    }

    if (state.favoriteTotalPages > 1) {
      widgets.add(
        PaginationControls(
          key: const Key('favoritesPaginationControlsTop'),
          currentPage: state.favoriteCurrentPage,
          totalPages: state.favoriteTotalPages,
          onPageChanged:
              (page) => bloc.add(PhotoFavoritePageNumberChanged(page)),
        ),
      );
    }

    return widgets;
  }

  /// Footer pagination for the favorites tab.
  List<Widget> _buildFooterWidgets(PhotoState state, PhotoBloc bloc) {
    if (state.favoriteTotalPages <= 1) {
      return const <Widget>[];
    }
    return [
      PaginationControls(
        key: const Key('favoritesPaginationControlsBottom'),
        currentPage: state.favoriteCurrentPage,
        totalPages: state.favoriteTotalPages,
        onPageChanged: (page) => bloc.add(PhotoFavoritePageNumberChanged(page)),
      ),
    ];
  }

  /// Mirrors the main gallery tap logic for favorites.
  void _handlePhotoTap(BuildContext context, PhotoBloc bloc, Photo photo) {
    if (bloc.state.isSelectionMode) {
      bloc.add(PhotoSelectionToggled(photo.id));
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (routeContext) => BlocProvider.value(
              value: bloc,
              child: PhotoDetailPage(photo: photo),
            ),
      ),
    );
  }

  /// Enables multi-select within favorites via long press.
  void _handlePhotoLongPress(PhotoBloc bloc, Photo photo) {
    bloc.add(PhotoSelectionModeStarted(anchorPhotoId: photo.id));
    HapticFeedback.lightImpact();
  }

  /// Toggles selection state for favorites.
  void _handleSelectionToggle(PhotoBloc bloc, Photo photo) {
    bloc.add(PhotoSelectionToggled(photo.id));
  }

  /// Displays the active filter chips on the favorites tab.
  Widget? _buildActiveFilters(PhotoState state, PhotoBloc bloc) {
    final chips = <Widget>[];

    for (final location in state.selectedLocations) {
      chips.add(
        InputChip(
          label: Text('Location: $location'),
          onDeleted: () => bloc.add(PhotoLocationFilterToggled(location)),
        ),
      );
    }

    for (final creator in state.selectedCreators) {
      chips.add(
        InputChip(
          label: Text('Creator: $creator'),
          onDeleted: () => bloc.add(PhotoCreatorFilterToggled(creator)),
        ),
      );
    }

    if (chips.isEmpty) {
      return null;
    }

    return Wrap(spacing: AppSpacingSmall, runSpacing: AppSpacingSmall, children: chips);
  }
}

class LayoutModeToggle extends StatelessWidget {
  const LayoutModeToggle({
    super.key,
    required this.layoutMode,
    required this.onChanged,
  });

  final GalleryLayoutMode layoutMode;
  final ValueChanged<GalleryLayoutMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<GalleryLayoutMode>(
      segments: const [
        ButtonSegment<GalleryLayoutMode>(
          value: GalleryLayoutMode.list,
          label: Text('List'),
          icon: Icon(Icons.view_agenda),
        ),
        ButtonSegment<GalleryLayoutMode>(
          value: GalleryLayoutMode.masonry,
          label: Text('Masonry'),
          icon: Icon(Icons.grid_view),
        ),
      ],
      selected: <GalleryLayoutMode>{layoutMode},
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) {
          onChanged(selection.first);
        }
      },
    );
  }
}

/// Presents multi-select chips for locations and creators.
class TagFilterSection extends StatelessWidget {
  const TagFilterSection({
    super.key,
    required this.locations,
    required this.creators,
    required this.selectedLocations,
    required this.selectedCreators,
  });

  final List<String> locations;
  final List<String> creators;
  final Set<String> selectedLocations;
  final Set<String> selectedCreators;

  @override
  Widget build(BuildContext context) {
    if (locations.isEmpty && creators.isEmpty) {
      return const Text('No filters available yet.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (locations.isNotEmpty) ...[
          const Text('Filter by location (multi-select, OR logic)'),
          const SizedBox(height: AppSpacingSmall),
          _ChipWrap(
            values: locations,
            isSelected: (value) => selectedLocations.contains(value),
            onToggled: (value) {
              context.read<PhotoBloc>().add(PhotoLocationFilterToggled(value));
            },
          ),
          const SizedBox(height: AppSpacingMedium),
        ],
        if (creators.isNotEmpty) ...[
          const Text('Filter by creator (multi-select, OR logic)'),
          const SizedBox(height: AppSpacingSmall),
          _ChipWrap(
            values: creators,
            isSelected: (value) => selectedCreators.contains(value),
            onToggled: (value) {
              context.read<PhotoBloc>().add(PhotoCreatorFilterToggled(value));
            },
          ),
        ],
      ],
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({
    required this.values,
    required this.isSelected,
    required this.onToggled,
  });

  final List<String> values;
  final bool Function(String value) isSelected;
  final void Function(String value) onToggled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacingSmall,
      runSpacing: AppSpacingSmall,
      children: values
          .map((value) {
            final selected = isSelected(value);
            return FilterChip(
              label: Text(value),
              selected: selected,
              onSelected: (_) => onToggled(value),
              shape: RoundedRectangleBorder(borderRadius: AppBorderRadius),
            );
          })
          .toList(growable: false),
    );
  }
}

class _RecentSearches extends StatelessWidget {
  const _RecentSearches({required this.searches, required this.onSelected});

  final List<String> searches;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacingSmall,
      runSpacing: AppSpacingSmall,
      children: searches
          .map(
            (term) => ActionChip(
              label: Text(term),
              onPressed: () => onSelected(term),
              shape: RoundedRectangleBorder(borderRadius: AppBorderRadius),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    this.hintText = 'Search by description, location, or creator',
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: hintText,
        border: OutlineInputBorder(borderRadius: AppBorderRadius),
      ),
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
    );
  }
}

/// Convenience widget that displays a centred loader.
class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({this.message = 'No photos match the current filters.'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacingExtraLarge),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacingExtraLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message ?? 'Failed to load photos',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacingLarge),
            OutlinedButton.icon(
              onPressed: () {
                context.read<PhotoBloc>().add(const PhotoRequested());
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
