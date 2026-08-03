import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Urdu text styles for the guided tutorial.
///
/// Two faces, on purpose. Nastaliq is the hand Urdu is actually written in and
/// it makes the headings feel like Urdu rather than translated English -- but
/// its strokes sweep well above and below the line, so it needs generous line
/// height or the letters clip. Naskh sits on a squarer grid and stays legible
/// at caption sizes, so the explanation text uses that.
class UrduText {
  const UrduText._();

  static const String nastaliq = 'NotoNastaliqUrdu';
  static const String naskh = 'NotoNaskhArabic';

  /// Nastaliq needs roughly twice the leading Latin type does. Anything less
  /// and the descenders of one line cut into the line under it.
  static const double _nastaliqHeight = 2.0;
  static const double _naskhHeight = 1.75;

  /// Big line at the top of a tutorial bubble.
  static TextStyle heading({Color? color, double fontSize = 21}) => TextStyle(
    fontFamily: nastaliq,
    fontWeight: FontWeight.w700,
    fontSize: fontSize,
    height: _nastaliqHeight,
    color: color ?? AppTheme.deepTeal,
  );

  /// Same, for bubbles drawn on a dark backdrop.
  static TextStyle headingOnDark({double fontSize = 21}) =>
      heading(color: Colors.white, fontSize: fontSize);

  /// The explanation paragraph.
  static TextStyle body({Color? color, double fontSize = 16}) => TextStyle(
    fontFamily: naskh,
    fontWeight: FontWeight.w600,
    fontSize: fontSize,
    height: _naskhHeight,
    color: color ?? AppTheme.textPrimary,
  );

  static TextStyle bodyOnDark({double fontSize = 16}) =>
      body(color: Colors.white.withValues(alpha: 0.94), fontSize: fontSize);

  /// Small print -- step counter, hints.
  static TextStyle caption({Color? color}) => TextStyle(
    fontFamily: naskh,
    fontWeight: FontWeight.w600,
    fontSize: 13,
    height: 1.6,
    color: color ?? AppTheme.textSecondary,
  );
}

/// Wraps [child] so Urdu lays out right-to-left.
///
/// Only the tutorial is wrapped -- the rest of the app is English and must stay
/// left-to-right, so this is deliberately not applied at the app root.
class UrduDirection extends StatelessWidget {
  final Widget child;

  const UrduDirection({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: child);
  }
}
