import '../models/fabrication_settings.dart';
import 'fabrication_settings_api_client.dart';
import 'fabrication_settings_repository.dart';

/// The two pair-cutting switches, as they are to be saved.
typedef PairCuttingSwitches = ({bool pairCutting, bool pairCuttingD29});

/// Saves the fabrication pair-cutting switches on their own, the moment one
/// is switched, so they stay as the workshop left them without a Save to
/// remember.
///
/// Only the switches change: everything else is saved back exactly as the
/// server has it, so a half-typed margin or length on the settings form is
/// neither saved by a switch nor lost to one.
class PairCuttingSaver {
  PairCuttingSaver(this._repository);

  final FabricationSettingsRepository _repository;
  Future<void> _last = Future<void>.value();

  /// Saves the switches as [current] reads them when the save's turn comes.
  ///
  /// Saves run one after another in the order asked, and each reads the
  /// switches afresh, so after two quick taps -- or a tap whose save failed
  /// and was switched back -- the server ends with what the screen shows.
  Future<FabricationSettingsModel> save(PairCuttingSwitches Function() current) {
    final Future<FabricationSettingsModel> result = _last.then(
      (_) => _save(current()),
    );
    _last = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<FabricationSettingsModel> _save(PairCuttingSwitches switches) async {
    final FabricationSettingsModel saved =
        await _repository.fetchFabricationSettings();
    if (saved.sectionLengths.isEmpty) {
      // Saving that back would empty the workshop's bar lengths.
      throw const FabricationSettingsApiException(
        'Fabrication settings did not load.',
      );
    }
    return _repository.saveFabricationSettings(
      saved.copyWithPairCutting(
        pairCutting: switches.pairCutting,
        pairCuttingD29: switches.pairCuttingD29,
      ),
    );
  }
}
