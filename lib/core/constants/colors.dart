import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const violet = Color(0xFF7C3AED);
  static const cyan   = Color(0xFF00B4D8);
  static const green  = Color(0xFF10B981);
  static const amber  = Color(0xFFF59E0B);
  static const rose   = Color(0xFFEC4899);
  static const blue   = Color(0xFF0082C9);
  static const orange = Color(0xFFEA580C);

  // Background
  static const bg         = Color(0xFF02030C);
  static const bgOrb1     = Color(0xFF180B60);
  static const bgOrb2     = Color(0xFF0B3560);
  static const bgOrb3     = Color(0xFF053520);
  static const bgOrb4     = Color(0xFF38055C);

  // Glass layers
  static Color glassLight  = Colors.white.withOpacity(0.08);
  static Color glassMid    = Colors.white.withOpacity(0.10);
  static Color glassHeavy  = Colors.white.withOpacity(0.13);
  static Color glassBorder = Colors.white.withOpacity(0.18);
  static Color sheen       = Colors.white.withOpacity(0.14);

  // Status
  static const online  = Color(0xFF4ADE80);
  static const offline = Color(0xFF475569);
  static const warning = Color(0xFFFBBF24);
}

class AppGradients {
  AppGradients._();

  static LinearGradient violetCyan = const LinearGradient(
    colors: [AppColors.violet, AppColors.cyan],
  );

  static LinearGradient streaming = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.cyan.withOpacity(0.10),
      AppColors.violet.withOpacity(0.07),
    ],
  );

  static LinearGradient newsletter = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.violet.withOpacity(0.20),
      AppColors.blue.withOpacity(0.06),
    ],
  );
}
