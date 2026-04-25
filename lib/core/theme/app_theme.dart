import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.violet,
      secondary: AppColors.cyan,
      surface: AppColors.bg,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 34, fontWeight: FontWeight.w800,
        letterSpacing: -1.0, color: Colors.white,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 28, fontWeight: FontWeight.w700,
        letterSpacing: -0.8, color: Colors.white,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 20, fontWeight: FontWeight.w700,
        letterSpacing: -0.5, color: Colors.white,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14, color: Colors.white,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12, color: Colors.white60,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}
