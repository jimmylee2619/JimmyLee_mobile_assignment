import 'package:flutter/material.dart';
import 'package:photo_gallery/app_constants.dart';

class PaginationControls extends StatelessWidget {
  const PaginationControls({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacingSmall),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed:
                currentPage > 0 ? () => onPageChanged(currentPage - 1) : null,
          ),
          const SizedBox(width: AppSpacingLarge),
          _buildPageNumberButtons(
            context,
            currentPage,
            totalPages,
            onPageChanged,
          ),
          const SizedBox(width: AppSpacingLarge),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed:
                currentPage < totalPages - 1
                    ? () => onPageChanged(currentPage + 1)
                    : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPageNumberButtons(
    BuildContext context,
    int currentPage,
    int totalPages,
    ValueChanged<int> onPageChanged,
  ) {
    List<Widget> buttons = [];
    const int maxVisiblePages = 5;

    if (totalPages <= maxVisiblePages) {
      for (int i = 0; i < totalPages; i++) {
        buttons.add(_buildPageButton(context, i, currentPage, onPageChanged));
      }
    } else {
      buttons.add(_buildPageButton(context, 0, currentPage, onPageChanged));

      if (currentPage > 2) {
        buttons.add(const Text('...'));
      }

      int startPage = (currentPage - 1).clamp(1, totalPages - 2);
      int endPage = (currentPage + 1).clamp(1, totalPages - 2);

      if (currentPage <= 2) {
        startPage = 1;
        endPage = 3;
      } else if (currentPage >= totalPages - 3) {
        startPage = totalPages - 4;
        endPage = totalPages - 2;
      }

      for (int i = startPage; i <= endPage; i++) {
        buttons.add(_buildPageButton(context, i, currentPage, onPageChanged));
      }

      if (currentPage < totalPages - 3) {
        buttons.add(const Text('...'));
      }

      if (totalPages > 1) {
        buttons.add(
          _buildPageButton(context, totalPages - 1, currentPage, onPageChanged),
        );
      }
    }
    return Row(children: buttons);
  }

  Widget _buildPageButton(
    BuildContext context,
    int pageNumber,
    int currentPage,
    ValueChanged<int> onPageChanged,
  ) {
    final isSelected = currentPage == pageNumber;
    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          onPageChanged(pageNumber);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacingExtraSmall),
        padding: const EdgeInsets.all(AppSpacingSmall),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300],
          shape: BoxShape.circle,
        ),
        child: Text(
          '${pageNumber + 1}',
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
