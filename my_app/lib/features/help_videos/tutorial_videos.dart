import 'video_links_store.dart';

/// The name each screen goes by when it asks for its "how do I do this" video.
///
/// Only the names live here. The links themselves come from the server via
/// [VideoLinksStore], so recording a new video — or re-uploading one, which
/// changes its link — is a file edit rather than a release.
///
/// Named after the screen rather than the order they were added, so adding a
/// video later does not shuffle the rest.
///
/// No link yet is not a mistake: it means that video is not made, and the
/// button says so rather than opening nothing.

class TutorialVideos {
  const TutorialVideos._();

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
  ///
  /// Comes from [VideoLinksStore], which reads it from the server -- so a new
  /// or corrected link reaches people without a release.
  static String linkFor(String key) => VideoLinksStore.instance.linkFor(key);

  static bool hasLink(String key) => VideoLinksStore.instance.hasLink(key);
}
