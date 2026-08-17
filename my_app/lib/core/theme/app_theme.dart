import 'package:flutter/material.dart';

/// The colours that change between light and dark.
///
/// Everything in the app already asks AppTheme for its colours by name, so the
/// whole interface follows whichever palette is active -- cards, panels, chips
/// and page backgrounds included, because their decorations are built from
/// these same names.
class _Palette {
  final Color ice;
  final Color mist;
  final Color slate;
  final Color line;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceMuted;
  final Color textPrimary;
  final Color shadow;
  final LinearGradient pageGradient;
  final LinearGradient panelGradient;

  const _Palette({
    required this.ice,
    required this.mist,
    required this.slate,
    required this.line,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.shadow,
    required this.pageGradient,
    required this.panelGradient,
  });
}

const _Palette _lightPalette = _Palette(
  ice: Color(0xFFDCE9F1),
  mist: Color(0xFFF2F6F9),
  slate: Color(0xFF627787),
  line: Color(0xFFD7E2EA),
  surface: Colors.white,
  surfaceAlt: Color(0xFFF7FAFC),
  surfaceMuted: Color(0xFFF0F5F8),
  textPrimary: Color(0xFF0A2540),
  shadow: Color(0xFF0A2540),
  pageGradient: LinearGradient(
    colors: <Color>[Color(0xFFF5F9FC), Color(0xFFE6EEF5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  panelGradient: LinearGradient(
    colors: <Color>[Color(0xFFFEFFFF), Color(0xFFF4F8FB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
);

/// Dark is not the light palette inverted. A workshop reads this app in bright
/// daylight and at night, so the dark surfaces stay slightly blue rather than
/// pure black -- pure black next to the brand blue looks like a dead screen --
/// and text stops short of pure white, which glares.
const _Palette _darkPalette = _Palette(
  ice: Color(0xFF22303F),
  mist: Color(0xFF10151B),
  slate: Color(0xFF9BAAB8),
  line: Color(0xFF2C3742),
  surface: Color(0xFF161D25),
  surfaceAlt: Color(0xFF1B232C),
  surfaceMuted: Color(0xFF202832),
  textPrimary: Color(0xFFE8EEF4),
  shadow: Colors.black,
  pageGradient: LinearGradient(
    colors: <Color>[Color(0xFF0E141A), Color(0xFF161E27)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  panelGradient: LinearGradient(
    colors: <Color>[Color(0xFF1A222B), Color(0xFF151C24)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
);

class AppTheme {
  const AppTheme._();

  static _Palette _palette = _lightPalette;

  /// Flipped by the theme controller before the app rebuilds.
  static set isDark(bool value) {
    _palette = value ? _darkPalette : _lightPalette;
  }

  static bool get isDark => identical(_palette, _darkPalette);

  // Brand colours. These carry the identity and stay put in both modes -- they
  // are used on top of their own accent fills, where they read either way.
  static const Color royalBlue = Color(0xFF123B63);
  static const Color inkBlue = Color(0xFF0A2540);
  static const Color navy = royalBlue;
  static const Color violet = royalBlue;
  static const Color deepTeal = Color(0xFF103C44);
  static const Color tealAccent = Color(0xFF1D8C8C);
  static const Color amberAccent = Color(0xFFEE9A3A);
  static const Color sky = Color(0xFF78AFC3);

  /// Collar wali (double) external line — light blue.
  static const Color collarLine = Color(0xFF6FB1D6);

  /// Bagair collar wali (single) external line — light red.
  static const Color noCollarLine = Color(0xFFE08A8A);

  static const Color success = Color(0xFF127A5A);
  static const Color warning = Color(0xFFE08C2D);
  static const Color danger = Color(0xFFB43B45);

  // Surfaces and text follow the active palette.
  static Color get ice => _palette.ice;
  static Color get mist => _palette.mist;
  static Color get slate => _palette.slate;
  static Color get line => _palette.line;
  static Color get surface => _palette.surface;
  static Color get surfaceAlt => _palette.surfaceAlt;
  static Color get surfaceMuted => _palette.surfaceMuted;
  static Color get textPrimary => _palette.textPrimary;
  static Color get textSecondary => _palette.slate;
  static Color get shadowColor => _palette.shadow;

  static const double space2 = 4;
  static const double space3 = 8;
  static const double space4 = 12;
  static const double space5 = 16;
  static const double space6 = 20;
  static const double space7 = 24;
  static const double space8 = 32;

  static const double radiusSm = 14;
  static const double radiusMd = 20;
  static const double radiusLg = 28;
  static const double radiusXl = 36;

  static LinearGradient get pageGradient => _palette.pageGradient;

  static const LinearGradient brandGradient = LinearGradient(
    colors: <Color>[royalBlue, Color(0xFF1E558A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get panelGradient => _palette.panelGradient;

  /// Built for whichever palette is active.
  ///
  /// Deliberately not a theme/darkTheme pair: the palette above is one global
  /// that ~150 call sites read directly, so two ThemeData objects built at the
  /// same moment would both come out in the same colours. One theme, rebuilt
  /// when the mode changes, is the only version of this that stays honest.
  static ThemeData current() => _build();

  static ThemeData light() {
    isDark = false;
    return _build();
  }

  static ThemeData dark() {
    isDark = true;
    return _build();
  }

  static ThemeData _build() {
    final ColorScheme colorScheme =
        ColorScheme.fromSeed(
          seedColor: royalBlue,
          primary: royalBlue,
          secondary: tealAccent,
          tertiary: amberAccent,
          surface: surface,
          brightness: isDark ? Brightness.dark : Brightness.light,
        ).copyWith(
          primary: royalBlue,
          secondary: tealAccent,
          tertiary: amberAccent,
          surface: surface,
          onSurface: textPrimary,
          error: danger,
          onError: Colors.white,
        );

    final Typography typography = Typography.material2021();
    final TextTheme baseText = (isDark ? typography.white : typography.black)
        .apply(
      fontFamily: 'Lato',
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    final TextTheme textTheme = baseText.copyWith(
      displayLarge: baseText.displayLarge?.copyWith(
        fontSize: 44,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.6,
        height: 1.05,
      ),
      displayMedium: baseText.displayMedium?.copyWith(
        fontSize: 38,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.2,
        height: 1.08,
      ),
      headlineLarge: baseText.headlineLarge?.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.8,
        height: 1.08,
      ),
      headlineMedium: baseText.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      headlineSmall: baseText.headlineSmall?.copyWith(
        fontSize: 21,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: baseText.titleLarge?.copyWith(
        fontSize: 19,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
      titleMedium: baseText.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
      titleSmall: baseText.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: baseText.bodyLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.45,
      ),
      bodyMedium: baseText.bodyMedium?.copyWith(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: textSecondary,
        height: 1.45,
      ),
      bodySmall: baseText.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: textSecondary,
      ),
      labelLarge: baseText.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.1,
      ),
      labelMedium: baseText.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      labelSmall: baseText.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );

    OutlineInputBorder roundedBorder(Color color, {double width = 1.2}) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: mist,
      textTheme: textTheme,
      fontFamily: 'Lato',
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w900,
          color: textPrimary,
        ),
      ),
      cardColor: surface,
      dividerColor: line,
      iconTheme: IconThemeData(color: textPrimary),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: royalBlue,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: inkBlue,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLg)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: royalBlue,
        secondarySelectedColor: royalBlue,
        disabledColor: line,
        side: BorderSide(color: line),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(
          royalBlue.withValues(alpha: 0.07),
        ),
        headingTextStyle: textTheme.bodyMedium?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w800,
        ),
        dataTextStyle: textTheme.bodyMedium?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        dividerThickness: 0.4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: textSecondary.withValues(alpha: 0.72),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: textSecondary,
          fontWeight: FontWeight.w700,
        ),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(
          color: royalBlue,
          fontWeight: FontWeight.w800,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: space5,
          vertical: space5,
        ),
        enabledBorder: roundedBorder(line),
        focusedBorder: roundedBorder(royalBlue, width: 1.4),
        errorBorder: roundedBorder(danger),
        focusedErrorBorder: roundedBorder(danger, width: 1.4),
        border: roundedBorder(line),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          backgroundColor: royalBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          foregroundColor: textPrimary,
          side: BorderSide(color: line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: textTheme.labelLarge?.copyWith(color: textPrimary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: royalBlue,
          textStyle: textTheme.labelLarge?.copyWith(color: royalBlue),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith<Color>((
            Set<WidgetState> states,
          ) {
            return states.contains(WidgetState.selected)
                ? Colors.white
                : textPrimary;
          }),
          backgroundColor: WidgetStateProperty.resolveWith<Color>((
            Set<WidgetState> states,
          ) {
            return states.contains(WidgetState.selected)
                ? royalBlue
                : surfaceAlt;
          }),
          overlayColor: WidgetStatePropertyAll(
            royalBlue.withValues(alpha: 0.08),
          ),
          side: WidgetStateProperty.resolveWith<BorderSide>((
            Set<WidgetState> states,
          ) {
            return BorderSide(
              color: states.contains(WidgetState.selected) ? royalBlue : line,
            );
          }),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          fixedSize: const WidgetStatePropertyAll(Size.fromHeight(44)),
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStatePropertyAll(
            textTheme.labelLarge?.copyWith(height: 1.0),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          ),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((
          Set<WidgetState> states,
        ) {
          return states.contains(WidgetState.selected)
              ? royalBlue
              : textSecondary.withValues(alpha: 0.7);
        }),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textPrimary,
          backgroundColor: surface.withValues(alpha: 0.92),
          padding: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  static BoxDecoration pageDecoration() {
    return BoxDecoration(gradient: pageGradient);
  }

  static List<BoxShadow> softShadow() {
    return <BoxShadow>[
      BoxShadow(
        color: inkBlue.withValues(alpha: 0.06),
        blurRadius: 22,
        spreadRadius: 0,
        offset: const Offset(0, 14),
      ),
      BoxShadow(
        color: inkBlue.withValues(alpha: 0.03),
        blurRadius: 10,
        spreadRadius: 0,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static BoxDecoration shellDecoration() {
    return BoxDecoration(
      color: surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(radiusXl),
      border: Border.all(color: line),
      boxShadow: softShadow(),
    );
  }

  static BoxDecoration elevatedCardDecoration({
    bool selected = false,
    Color? accent,
  }) {
    final Color accentColor = accent ?? royalBlue;
    return BoxDecoration(
      gradient: panelGradient,
      borderRadius: BorderRadius.circular(radiusLg),
      border: Border.all(
        color: selected ? accentColor : line,
        width: selected ? 1.6 : 1,
      ),
      boxShadow: softShadow(),
    );
  }

  static BoxDecoration softPanelDecoration({double radius = radiusLg}) {
    return BoxDecoration(
      color: surface.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: line),
    );
  }

  static BoxDecoration accentPanelDecoration({double radius = radiusLg}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        colors: <Color>[
          royalBlue.withValues(alpha: 0.10),
          tealAccent.withValues(alpha: 0.08),
          amberAccent.withValues(alpha: 0.06),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: royalBlue.withValues(alpha: 0.10)),
    );
  }

  static BoxDecoration infoChipDecoration({bool emphasized = false}) {
    return BoxDecoration(
      color: emphasized ? royalBlue.withValues(alpha: 0.08) : surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: emphasized ? royalBlue.withValues(alpha: 0.20) : line,
      ),
    );
  }
}
