import 'package:flutter/material.dart';

class AppColors {
  // Brand Primary (Deep Royal Navy & Oceanic Blue)
  static const Color primary = Color(0xFF1E3A8A); // Blue 900
  static const Color primaryLight = Color(0xFF3B82F6); // Blue 500
  static const Color primaryDark = Color(0xFF172554); // Blue 950

  // Secondary & Accents (Teal / Emerald for association & finance vitality)
  static const Color secondary = Color(0xFF0D9488); // Teal 600
  static const Color secondaryLight = Color(0xFF14B8A6); // Teal 500
  static const Color secondaryDark = Color(0xFF0F766E); // Teal 700

  // Accent Gold (Dues, Membership, Mauritius sunshine)
  static const Color accentGold = Color(0xFFF59E0B);
  static const Color accentGoldDark = Color(0xFFD97706);

  // Status & Financial Indicators
  static const Color success = Color(0xFF10B981); // Validated, Paid, Active
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B); // Pending, Needs verification
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFEF4444); // Rejected, Overdue, Expense
  static const Color dangerLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // Neutral Colors (Light mode)
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textMutedLight = Color(0xFF94A3B8);
  static const Color textTertiaryLight = textMutedLight;
  static const Color borderLight = Color(0xFFE2E8F0);

  // Neutral Colors (Dark mode)
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color cardDark = Color(0xFF1E293B);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textMutedDark = Color(0xFF64748B);
  static const Color textTertiaryDark = textMutedDark;
  static const Color borderDark = Color(0xFF334155);

  // Modern Gradients (Inspired by the ocean, sun & AJRA seal)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF0284C7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0A2540), Color(0xFF1E3A8A), Color(0xFF0EA5E9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient oceanicGradient = LinearGradient(
    colors: [Color(0xFF0284C7), Color(0xFF0D9488)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient memberCardGradient = LinearGradient(
    colors: [Color(0xFF0B192C), Color(0xFF1E3A8A), Color(0xFF0F766E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF065F46), Color(0xFF0D9488)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Soft Modern Shadows & Ambient Elevations
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x080F172A),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x040F172A),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> elevatedCardShadow = [
    BoxShadow(
      color: Color(0x120F172A),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x060F172A),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> memberCardShadow = [
    BoxShadow(
      color: Color(0x3D0B192C),
      blurRadius: 30,
      offset: Offset(0, 14),
    ),
    BoxShadow(
      color: Color(0x1F0F766E),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];
}
