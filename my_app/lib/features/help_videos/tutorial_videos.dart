/// Where every "how do I do this" video lives.
///
/// One place on purpose. There is a button on seventeen screens, and links
/// scattered across seventeen files is how three of them end up pointing at
/// last year's video and nobody notices. Fill a link in here and the screen
/// picks it up.
///
/// A blank entry is not a mistake — it means that video has not been recorded
/// yet, and the button says so rather than opening nothing.
class TutorialVideos {
  const TutorialVideos._();

  /// Screen key -> YouTube link.
  ///
  /// Keys are named after the screen, not the order they were added, so adding
  /// a video later does not shuffle the rest.
  static const Map<String, String> _links = <String, String>{
    // --- Shared ---------------------------------------------------------
    home: '',

    // --- Estimation -----------------------------------------------------
    estimationMenu: '',
    estimationLibrary: '',
    estimationLengthOptimization: '',
    estimationMaterialSelection: '',
    estimationRates: '',
    estimationMaterialTable: '',
    estimationBillInputs: '',
    estimationFinalBill: '',

    // --- Fabrication ----------------------------------------------------
    fabricationMenu: '',
    fabricationLibrary: '',
    fabricationLengthOptimization: '',
    fabricationMaterialSelection: '',
    fabricationRates: '',
    fabricationMaterialTable: '',

    // --- Glass ----------------------------------------------------------
    glassSizeList: '',
    glassSheetLayout: '',
  };

  static const String home = 'home';

  static const String estimationMenu = 'estimation.menu';
  static const String estimationLibrary = 'estimation.library';
  static const String estimationLengthOptimization = 'estimation.lengths';
  static const String estimationMaterialSelection = 'estimation.material';
  static const String estimationRates = 'estimation.rates';
  static const String estimationMaterialTable = 'estimation.materialTable';
  static const String estimationBillInputs = 'estimation.billInputs';
  static const String estimationFinalBill = 'estimation.finalBill';

  static const String fabricationMenu = 'fabrication.menu';
  static const String fabricationLibrary = 'fabrication.library';
  static const String fabricationLengthOptimization = 'fabrication.lengths';
  static const String fabricationMaterialSelection = 'fabrication.material';
  static const String fabricationRates = 'fabrication.rates';
  static const String fabricationMaterialTable = 'fabrication.materialTable';

  static const String glassSizeList = 'glass.sizeList';
  static const String glassSheetLayout = 'glass.sheetLayout';

  /// The link for a screen, or empty when it has not been recorded yet.
  static String linkFor(String key) => _links[key] ?? '';

  static bool hasLink(String key) => linkFor(key).trim().isNotEmpty;
}
