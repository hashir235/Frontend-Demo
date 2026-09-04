/// Which set of formulas a given window is cut by.
///
/// The app and the engine name windows differently, and for good reason: a
/// fabricator picks "Panel Windows -> Center Slide", while the engine knows
/// that as the sliding-glass window with its window type set to 2. The same
/// goes for the corner windows, the two doors and the two arches. This is that
/// translation, in one place, so a formula screen and a cutting list can never
/// disagree about which window is on the bench.
library;

/// The engine window behind one of the app's window types, and the setting
/// that picks it out.
class _EngineWindow {
  const _EngineWindow(this.window, [this.dimension, this.value]);

  /// The engine's own name -- "SG_win", "D_win", and so on.
  final String window;

  /// Which configuration dimension the app's choice fixes, if any.
  ///
  /// Fabrication and estimation spell this differently for the same window:
  /// fabrication calls it windowType throughout, while estimation calls it
  /// `option` on the panel windows and `type` on the corner ones. The name is
  /// taken from the catalogue rather than assumed.
  final String? dimension;

  /// The value that dimension takes.
  final String? value;
}

/// Everything the app calls a window, and what the engine cuts it as.
///
/// Read off the dispatch in EstimationOptimizationService.cpp, and then held
/// against it: the round-trip test drives real windows through the API and
/// compares the pieces, so a wrong line here fails loudly rather than
/// producing a plausible cutting list for the wrong window.
const Map<String, _EngineWindow> _byAppCode = <String, _EngineWindow>{
  'S_win': _EngineWindow('S_win'),
  'MS_win': _EngineWindow('SM_win'),
  'F_win': _EngineWindow('F_win'),
  'FC_win': _EngineWindow('FC_win'),
  'O_win': _EngineWindow('O_win'),

  // Panel windows: centre fix, centre slide, three equal panels.
  'PF3_win': _EngineWindow('SG_win', 'windowType', '1'),
  'PS4_win': _EngineWindow('SG_win', 'windowType', '2'),
  'EF3_win': _EngineWindow('SG_win', 'windowType', '3'),
  'MPF3_win': _EngineWindow('SGM_win', 'windowType', '1'),
  'MPS4_win': _EngineWindow('SGM_win', 'windowType', '2'),
  'MEF3_win': _EngineWindow('SGM_win', 'windowType', '3'),

  // Sliding corner windows. Left and right are 4 and 3, in that order --
  // the engine numbers right before left.
  'SCF_win': _EngineWindow('SC_win', 'windowType', '1'),
  'SCS_win': _EngineWindow('SC_win', 'windowType', '2'),
  'SCR_win': _EngineWindow('SC_win', 'windowType', '3'),
  'SCL_win': _EngineWindow('SC_win', 'windowType', '4'),
  'MSCF_win': _EngineWindow('SCM_win', 'windowType', '1'),
  'MSCS_win': _EngineWindow('SCM_win', 'windowType', '2'),
  'MSCR_win': _EngineWindow('SCM_win', 'windowType', '3'),
  'MSCL_win': _EngineWindow('SCM_win', 'windowType', '4'),

  'Single_Door': _EngineWindow('D_win', 'doorType', '1'),
  'Double_Door': _EngineWindow('D_win', 'doorType', '2'),

  // A_win is the round arch, AR_win the rectangle -- the engine's ArchType
  // numbers Rectangle first.
  'A_win': _EngineWindow('A_win', 'archType', '2'),
  'AR_win': _EngineWindow('A_win', 'archType', '1'),
};

/// The estimation side's own names for the dimension that fabrication calls
/// `windowType`.
const Map<String, String> _estimationDimensionNames = <String, String>{
  'SG_win': 'option',
  'SGM_win': 'option',
  'SC_win': 'type',
  'SCM_win': 'type',
};

/// Everything about a window that decides which formulas cut it.
class FormulaWindowKey {
  const FormulaWindowKey._(this.context, this.window, this.config);

  /// 'fabrication' or 'estimation'.
  final String context;

  /// The engine's name for this window.
  final String window;

  /// The settings that pick out one set of formulas.
  final Map<String, String> config;

  /// Where this window's formulas live in the catalogue.
  String get windowKey => '$context/$window';

  /// The catalogue's name for this exact configuration.
  ///
  /// Sorted, because the catalogue was written sorted and a key assembled in
  /// a different order would simply not be found.
  String get configKey {
    final List<String> names = config.keys.toList()..sort();
    return names.map((String name) => '$name=${config[name]}').join('|');
  }

  /// Whether the app knows this window at all.
  static bool knows(String appWindowCode) => _byAppCode.containsKey(appWindowCode);

  /// Works out which formulas cut this window.
  ///
  /// [dimensions] is what the catalogue says this window's configuration is
  /// made of -- taken from the catalogue rather than assumed here, so a window
  /// that gains or loses a setting does not need this code changed. Anything
  /// the catalogue does not ask for is left out, and anything it asks for that
  /// the window cannot answer makes this return null rather than guess.
  static FormulaWindowKey? of({
    required String context,
    required String appWindowCode,
    required Set<String> dimensions,
    required int collarIndex,
    int? lockType,
    String? rubberType,
    bool addBottom = false,
    bool addTee = false,
    bool addNet = false,
    double backCollarCm = 1.7,
  }) {
    final _EngineWindow? engine = _byAppCode[appWindowCode];
    if (engine == null) return null;

    final Map<String, String> config = <String, String>{};

    for (final String dimension in dimensions) {
      final String? value = _valueFor(
        dimension: dimension,
        context: context,
        engine: engine,
        collarIndex: collarIndex,
        lockType: lockType,
        rubberType: rubberType,
        addBottom: addBottom,
        addTee: addTee,
        addNet: addNet,
        backCollarCm: backCollarCm,
      );
      if (value == null) return null;
      config[dimension] = value;
    }

    return FormulaWindowKey._(context, engine.window, config);
  }

  static String? _valueFor({
    required String dimension,
    required String context,
    required _EngineWindow engine,
    required int collarIndex,
    required int? lockType,
    required String? rubberType,
    required bool addBottom,
    required bool addTee,
    required bool addNet,
    required double backCollarCm,
  }) {
    // The dimension the app's window choice fixes, whatever the two sides
    // happen to call it.
    final String? ownName = context == 'estimation'
        ? (_estimationDimensionNames[engine.window] ?? engine.dimension)
        : engine.dimension;
    if (engine.dimension != null && dimension == ownName) {
      return engine.value;
    }

    switch (dimension) {
      case 'collarType':
        return '$collarIndex';
      case 'lockType':
        return lockType == null ? null : '$lockType';
      case 'rubberType':
        final String rubber = (rubberType ?? '').trim().toUpperCase();
        return (rubber == 'F' || rubber == 'U') ? rubber : null;
      case 'addBottom':
        return addBottom ? 'true' : 'false';
      case 'addTee':
        return addTee ? 'true' : 'false';
      case 'addNet':
        return addNet ? 'true' : 'false';
      case 'backCollarCm':
        // The engine only has the two collars, and reads anything from 2cm up
        // as the larger one.
        return backCollarCm >= 2.0 ? '2.0' : '1.7';
    }
    return null;
  }

  @override
  String toString() => '$windowKey [$configKey]';
}
