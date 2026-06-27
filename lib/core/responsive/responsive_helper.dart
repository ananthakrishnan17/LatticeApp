import 'dart:math' as math;

import 'package:flutter/widgets.dart';

enum DeviceType { mobile, tablet, desktop }

class ResponsiveBreakpoints {
  static const double tablet = 600;
  static const double largeTablet = 900;
  static const double baseDesignWidth = 390;
  static const double maxContentWidthTablet = 1000;
  static const double maxContentWidthDesktop = 1200;
}

class ResponsiveHelper {
  final double width;
  final double height;

  const ResponsiveHelper._({
    required this.width,
    required this.height,
  });

  factory ResponsiveHelper.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return ResponsiveHelper._(width: size.width, height: size.height);
  }

  factory ResponsiveHelper.fromConstraints(BoxConstraints constraints) {
    return ResponsiveHelper._(
      width: constraints.maxWidth,
      height: constraints.maxHeight,
    );
  }

  DeviceType get deviceType {
    if (width >= ResponsiveBreakpoints.largeTablet) return DeviceType.desktop;
    if (width >= ResponsiveBreakpoints.tablet) return DeviceType.tablet;
    return DeviceType.mobile;
  }

  bool get isMobile => width < ResponsiveBreakpoints.tablet;
  bool get isTablet => width >= ResponsiveBreakpoints.tablet && width < ResponsiveBreakpoints.largeTablet;
  bool get isDesktop => width >= ResponsiveBreakpoints.largeTablet;

  T value<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop) return desktop ?? tablet ?? mobile;
    if (isTablet) return tablet ?? mobile;
    return mobile;
  }

  int gridCount({
    required int mobile,
    required int tablet,
    required int desktop,
  }) {
    return value(mobile: mobile, tablet: tablet, desktop: desktop);
  }

  double font(double base) {
    // Uses 390 (base phone design width) to keep typography proportional
    // across small phones and tablets without aggressive text growth.
    final scale = (width / ResponsiveBreakpoints.baseDesignWidth).clamp(0.9, 1.25);
    return base * scale;
  }

  double spacing(double base) {
    // Uses the shorter edge so spacing stays stable in landscape mode.
    // A slightly higher max clamp lets tablet layouts breathe more than text.
    final scale = (math.min(width, height) / ResponsiveBreakpoints.baseDesignWidth).clamp(0.9, 1.35);
    return base * scale;
  }
}
