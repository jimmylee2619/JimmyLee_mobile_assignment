import 'package:flutter/material.dart';

const BorderRadius AppBorderRadius = BorderRadius.all(Radius.circular(8.0));

// Font Sizes
const double AppFontSizeSmall = 12.0;

// Icon Sizes
const double AppIconSizeSmall = 16.0;
const double AppIconSizeMedium = 20.0;
const double AppIconSizeLarge = 24.0; // Used for progress indicator size

// Spacing, Padding, and Margins
const double AppSpacingExtraSmall = 4.0;
const double AppSpacingSmall = 8.0;
const double AppSpacingMedium = 12.0;
const double AppSpacingLarge = 16.0;
const double AppSpacingExtraLarge = 24.0;
const double AppSpacingXSmall = 6.0; // Newly added

// Component Sizes
const double AppCircularProgressIndicatorSize = 32.0;
const double AppCircleAvatarRadius = 18.0;
const double AppSplashRadius = 20.0;
const double AppStrokeWidthSmall = 2.5; // Newly added
const double AppStrokeWidthMedium = 3.0; // Newly added

/// Displays a standardized SnackBar notification.
void showAppSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: AppSpacingSmall),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        shape: RoundedRectangleBorder(borderRadius: AppBorderRadius),
        behavior: SnackBarBehavior.floating,
      ),
    );
}
