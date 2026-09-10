import 'package:flutter/material.dart';

/// Central theme definition for UrbanEx.
/// Brand colour is a mid-green (matches the Figma "UrbanEx" wordmark)
/// with score colours for Good / Moderate / Bad states.
class AppColors {
  static const Color brand = Color(0xFF2E7D4F);
  static const Color brandDark = Color(0xFF1F5C39);
  static const Color good = Color(0xFF34A853);
  static const Color moderate = Color(0xFFF2A93B);
  static const Color bad = Color(0xFFE05252);

  // Used to tell "District A" and "District B" apart wherever two
  // districts are shown side by side (e.g. Compare Districts) - brand
  // green for the first pick, a complementary blue for the second.
  static const Color compareA = brand;
  static const Color compareB = Color(0xFF3B6FB4);

  static Color scoreColor(num score) {
    if (score >= 75) return good;
    if (score >= 50) return moderate;
    return bad;
  }

  static String scoreLabel(num score) {
    if (score >= 75) return 'Good';
    if (score >= 50) return 'Moderate';
    return 'Bad';
  }
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF5F6F5),
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.brand,
        secondary: AppColors.brand,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF5F6F5),
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ).copyWith(
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) return 8;
            if (states.contains(WidgetState.pressed)) return 2;
            return 4;
          }),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) return Colors.white.withOpacity(0.12);
            if (states.contains(WidgetState.pressed)) return Colors.white.withOpacity(0.2);
            return null;
          }),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF121212),
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.brand,
        secondary: AppColors.brand,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF121212),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(52),
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ).copyWith(
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) return 8;
            if (states.contains(WidgetState.pressed)) return 2;
            return 4;
          }),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) return Colors.black.withOpacity(0.08);
            if (states.contains(WidgetState.pressed)) return Colors.black.withOpacity(0.15);
            return null;
          }),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade800),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1E1E1E),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}


