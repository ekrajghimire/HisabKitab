import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class EdgeToEdgeUtils {
  /// Configure the app for edge-to-edge display
  static void configureEdgeToEdge() {
    if (Platform.isAndroid) {
      // Dynamic edge-to-edge support for all Android versions
      // Use edge-to-edge mode which works across all Android versions
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

      // Set basic system UI overlay style that works on all Android versions
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );
    } else {
      // For other platforms, use the traditional approach
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );

      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  /// Get safe area padding for edge-to-edge content
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return EdgeInsets.only(
      top: mediaQuery.padding.top,
      bottom: mediaQuery.padding.bottom,
      left: mediaQuery.padding.left,
      right: mediaQuery.padding.right,
    );
  }

  /// Create a widget that respects system insets
  static Widget withSystemInsets({required Widget child, EdgeInsets? padding}) {
    return Builder(
      builder: (context) {
        final safeArea = getSafeAreaPadding(context);
        final additionalPadding = padding ?? EdgeInsets.zero;

        return Padding(
          padding: EdgeInsets.only(
            top: safeArea.top + additionalPadding.top,
            bottom: safeArea.bottom + additionalPadding.bottom,
            left: safeArea.left + additionalPadding.left,
            right: safeArea.right + additionalPadding.right,
          ),
          child: child,
        );
      },
    );
  }
}
