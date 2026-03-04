import 'package:flutter/material.dart';

class AppTheme {
  static const Color ice = Color(0xFFA9CFE0);
  static const Color navy = Color(0xFF123B63);
  static const Color violet = navy;
  static const Color deepTeal = Color(0xFF103C44);
  static const Color mist = Color(0xFFC7D6DE);
  static const Color sky = Color(0xFF78AFC3);
  static const Color slate = Color(0xFF6E8F99);

  static const LinearGradient pageGradient = LinearGradient(
    colors: <Color>[mist, ice],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData light() {
    final UnderlineInputBorder defaultBorder = UnderlineInputBorder(
      borderSide: BorderSide(
        color: sky.withValues(alpha: 0.75),
        width: 1,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: violet,
        secondary: sky,
        surface: Colors.white,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: deepTeal,
      ),
      scaffoldBackgroundColor: mist,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: deepTeal,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: deepTeal,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: deepTeal,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: deepTeal,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: deepTeal,
        ),
        bodyMedium: TextStyle(fontSize: 14, color: slate),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: sky.withValues(alpha: 0.65),
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        enabledBorder: defaultBorder,
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: violet.withValues(alpha: 0.85),
            width: 1.2,
          ),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Colors.red.shade400,
            width: 1,
          ),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Colors.red.shade600,
            width: 1.2,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: violet,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: deepTeal,
        ),
      ),

      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(
          deepTeal.withValues(alpha: 0.08),
        ),
        dataRowColor: const WidgetStatePropertyAll(Colors.transparent),
        dividerThickness: 0.6,
      ),
    );
  }

  static BoxDecoration pageDecoration() {
    return const BoxDecoration(gradient: pageGradient);
  }

  static BoxDecoration shellDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: sky.withValues(alpha: 0.8)),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: deepTeal.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  static BoxDecoration softPanelDecoration({double radius = 24}) {
    return BoxDecoration(
      color: mist.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: sky.withValues(alpha: 0.55)),
    );
  }

  static BoxDecoration accentPanelDecoration({double radius = 24}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        colors: <Color>[
          violet.withValues(alpha: 0.12),
          sky.withValues(alpha: 0.14),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }

  static BoxDecoration infoChipDecoration() {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.84),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: sky.withValues(alpha: 0.45)),
    );
  }
}

