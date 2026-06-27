import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppTheme {
  // AWS CloudScape-inspired light color system
  static const Color primary = Color(0xFF0073BB);
  static const Color primaryDark = Color(0xFF005E99);
  static const Color primaryLight = Color(0xFF0073BB);
  static const Color secondary = Color(0xFF6B7280);
  static const Color accent = Color(0xFF037F4C);
  static const Color success = Color(0xFF037F4C);
  static const Color warning = Color(0xFFB26200);
  static const Color danger = Color(0xFFD91515);
  static const Color surface = Color(0xFFF8F9FA);
  static const Color cardBg = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color lowStockColor = Color(0xFFFFF3CD);
  static const Color outOfStockColor = Color(0xFFFFEBEB);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Poppins',
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: Colors.white,
        error: danger,
      ),
      scaffoldBackgroundColor: surface,

      // AppBar — white background, dark icons, no elevation
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        centerTitle: false,
        iconTheme: const IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
      ),

      // Cards — white with border, no shadow
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
          side: const BorderSide(color: divider, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: Size(double.infinity, 52.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          textStyle: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        hintStyle: TextStyle(
          color: textSecondary,
          fontSize: 14.sp,
          fontFamily: 'Poppins',
        ),
        labelStyle: TextStyle(
          color: textSecondary,
          fontSize: 14.sp,
          fontFamily: 'Poppins',
        ),
      ),

      // Bottom Navigation
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primary,
        unselectedItemColor: Color(0xFF9CA3AF),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
      ),

      // Tab bar
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: textSecondary,
        indicatorColor: primary,
      ),
    );
  }

  // Text styles
  static TextStyle get heading1 => TextStyle(
    fontSize: 20.sp,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    fontFamily: 'Poppins',
  );

  static TextStyle get heading2 => TextStyle(
    fontSize: 18.sp,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    fontFamily: 'Poppins',
  );

  static TextStyle get heading3 => TextStyle(
    fontSize: 16.sp,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    fontFamily: 'Poppins',
  );

  static TextStyle get body => TextStyle(
    fontSize: 14.sp,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    fontFamily: 'Poppins',
  );

  static TextStyle get caption => TextStyle(
    fontSize: 12.sp,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    fontFamily: 'Poppins',
  );

  static TextStyle get price => TextStyle(
    fontSize: 18.sp,
    fontWeight: FontWeight.w700,
    color: primary,
    fontFamily: 'Poppins',
  );
}
