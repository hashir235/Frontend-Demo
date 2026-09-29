
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/settings/data/fabrication_settings_api_client.dart';
import 'package:my_app/features/settings/data/fabrication_settings_repository.dart';
import 'package:my_app/features/settings/data/pair_cutting_saver.dart';
import 'package:my_app/features/settings/models/fabrication_settings.dart';

/// The pair-cutting switches are saved the moment they are turned, and stay
/// until turned again -- no Save button to forget.
void main() {
  const FabricationSettingsModel onServer = FabricationSettingsModel(
    cuttingMarginCm: 0.8,
    sectionLengths: <String, List<int>>{
      'M23': <int>[14, 16, 18],
      'DC30F': <int>[15, 17, 19],
    },
    maxExtraPieces: 3,
    enforceMaxExtraPieces: true,
    redZoneEven: 11,
    redZoneOdd: 12.5,
  );

  test('only the switches change; the rest goes back as the server has it', () async {
    final _FakeRepository repository = _FakeRepository(onServer);
    await PairCuttingSaver(repository).save(
      () => (pairCutting: true, pairCuttingD29: false),
    );

    final FabricationSettingsModel saved = repository.stored;
    expect(saved.pairCutting, isTrue);
    expect(saved.pairCuttingD29, isFalse);
    expect(saved.cuttingMarginCm, 0.8);
    expect(saved.sectionLengths, onServer.sectionLengths);
    expect(saved.maxExtraPieces, 3);
    expect(saved.enforceMaxExtraPieces, isTrue);
    expect(saved.redZoneEven, 11);
    expect(saved.redZoneOdd, 12.5);
  });

  test('two quick taps: saved one after the other, the last one wins', () async {
    final _FakeRepository repository = _FakeRepository(onServer)
      ..saveDelay = const Duration(milliseconds: 20);
    final PairCuttingSaver saver = PairCuttingSaver(repository);
    bool m23 = false;
    bool d29 = false;

    m23 = true;
    final Future<void> first = saver.save(() => (pairCutting: m23, pairCuttingD29: d29));
    d29 = true;
    final Future<void> second = saver.save(() => (pairCutting: m23, pairCuttingD29: d29));
    await Future.wait(<Future<void>>[first, second]);

    expect(repository.maxInFlight, 1, reason: 'never two saves at once');
    expect(repository.stored.pairCutting, isTrue);
    expect(repository.stored.pairCuttingD29, isTrue);
  });

  test('a failed save does not stop the next, which saves what is shown', () async {
    final _FakeRepository repository = _FakeRepository(onServer)..failNextSave = true;
    final PairCuttingSaver saver = PairCuttingSaver(repository);
    bool m23 = true;

    await expectLater(
      saver.save(() => (pairCutting: m23, pairCuttingD29: false)),
      throwsA(isA<FabricationSettingsApiException>()),
    );
    m23 = false; // the screen puts the switch back
    await saver.save(() => (pairCutting: m23, pairCuttingD29: true));
    expect(repository.stored.pairCutting, isFalse);
    expect(repository.stored.pairCuttingD29, isTrue);
  });

  test('never saves over the bar lengths with nothing', () async {
    final _FakeRepository repository = _FakeRepository(
      const FabricationSettingsModel(cuttingMarginCm: 1.2),
    );
    await expectLater(
      PairCuttingSaver(repository).save(() => (pairCutting: true, pairCuttingD29: true)),
      throwsA(isA<FabricationSettingsApiException>()),
    );
    expect(repository.saves, 0);
  });
}

class _FakeRepository extends FabricationSettingsRepository {
  _FakeRepository(this.stored);

  FabricationSettingsModel stored;
  Duration saveDelay = Duration.zero;
  bool failNextSave = false;
  int saves = 0;
  int _inFlight = 0;
  int maxInFlight = 0;

  @override
  Future<FabricationSettingsModel> fetchFabricationSettings() async => stored;

  @override
  Future<FabricationSettingsModel> saveFabricationSettings(
    FabricationSettingsModel settings,
  ) async {
    _inFlight++;
    if (_inFlight > maxInFlight) maxInFlight = _inFlight;
    try {
      await Future<void>.delayed(saveDelay);
      if (failNextSave) {
        failNextSave = false;
        throw const FabricationSettingsApiException('offline');
      }
      saves++;
      stored = settings;
      return settings;
    } finally {
      _inFlight--;
    }
  }
}
