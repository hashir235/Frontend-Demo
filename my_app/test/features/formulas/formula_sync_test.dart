import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_app/features/formulas/data/formula_book_loader.dart';
import 'package:my_app/features/formulas/data/formula_overrides_store.dart';
import 'package:my_app/features/formulas/data/formula_sync_api_client.dart';
import 'package:my_app/features/formulas/model/formula_overrides.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Getting a formula onto a phone that already has one.
///
/// Most workshops cannot set their own formulas -- they ring up and read them
/// down the phone, and they get set for them. The rule that used to govern
/// this only filled an empty device, which meant it reached everybody except
/// the people who had changed a formula and got it wrong. Those are the people
/// who ring.
///
/// So the server's copy is taken when it is newer, and left alone when it is
/// not. These tests run the real store and the real client against a stubbed
/// server, because the failure that matters here is silent: a formula that was
/// set from the office and simply never arrives, with a cutting sheet carrying
/// the old one and nothing to say so.
void main() {
  const FormulaPieceRef piece = FormulaPieceRef(
    windowKey: 'fabrication/S_win',
    configKey: 'collarType=2|lockType=1|rubberType=F|windowType=1',
    section: 'DC30C',
    index: 0,
  );

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  FormulaOverrides withFormula(String formula) {
    final FormulaOverrides overrides = FormulaOverrides.empty();
    overrides.set(piece, formula);
    return overrides;
  }

  /// A server holding [formula] at [revision]; null formula means it holds
  /// nothing. Records every write it is sent.
  FormulaSyncApiClient serverAt({
    String? formula,
    required int revision,
    bool omitRevision = false,
    List<String>? writes,
    int putStatus = 200,
  }) {
    return FormulaSyncApiClient(
      baseUrl: 'https://api.example.invalid',
      httpClient: MockClient((http.Request request) async {
        if (request.method == 'PUT') {
          writes?.add(request.body);
          if (putStatus >= 300) {
            return http.Response('{"error":"nope"}', putStatus,
                headers: <String, String>{'content-type': 'application/json'});
          }
          return http.Response(
            jsonEncode(<String, Object?>{'ok': true, 'revision': revision + 1}),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode(<String, Object?>{
            'ok': true,
            'formulas': formula == null
                ? <String, Object?>{'version': 1, 'windows': <String, Object?>{}}
                : withFormula(formula).toJson(),
            if (!omitRevision) 'revision': revision,
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );
  }

  Future<String?> onDevice() async {
    return (await const FormulaOverridesStore().load()).formulaFor(piece);
  }

  test('a formula set from the office reaches a phone that has its own', () async {
    // The workshop changed this themselves and got it wrong; revision 3 is
    // where the server stood when they did.
    await const FormulaOverridesStore()
        .save(withFormula('(h + 99 + cm) / feet'), revision: 3);

    // The office sets it right. That write moved the server to 4.
    await FormulaBookLoader(sync: serverAt(formula: '(h + 6 + cm) / feet', revision: 4))
        .syncFromServer();

    expect(await onDevice(), '(h + 6 + cm) / feet');
    expect(await const FormulaOverridesStore().revision(), 4);
  });

  test('a phone that is already up to date keeps what it has', () async {
    await const FormulaOverridesStore()
        .save(withFormula('(h + 6 + cm) / feet'), revision: 4);

    // Same revision: the server has nothing this device has not already seen.
    // Its payload is deliberately different, so taking it would show.
    await FormulaBookLoader(sync: serverAt(formula: '(h + 1 + cm) / feet', revision: 4))
        .syncFromServer();

    expect(await onDevice(), '(h + 6 + cm) / feet');
  });

  test('an unsynced change is not overwritten by an older server', () async {
    // Saved on the device while offline: the server never took it, so the
    // device is still on revision 3 and the server is behind at 2.
    await const FormulaOverridesStore()
        .save(withFormula('(h + 42 + cm) / feet'), revision: 3);

    await FormulaBookLoader(sync: serverAt(formula: '(h + 6 + cm) / feet', revision: 2))
        .syncFromServer();

    expect(await onDevice(), '(h + 42 + cm) / feet');
  });

  test('a new phone is filled from the server, as before', () async {
    // The case the old rule existed for, which must keep working.
    await FormulaBookLoader(sync: serverAt(formula: '(h + 6 + cm) / feet', revision: 7))
        .syncFromServer();

    expect(await onDevice(), '(h + 6 + cm) / feet');
    expect(await const FormulaOverridesStore().revision(), 7);
  });

  test('a reset made from the office reaches the phone too', () async {
    await const FormulaOverridesStore()
        .save(withFormula('(h + 99 + cm) / feet'), revision: 3);

    // Putting a formula back is a write like any other: the server holds
    // nothing for this piece now, at a higher revision.
    await FormulaBookLoader(sync: serverAt(revision: 4)).syncFromServer();

    expect(await onDevice(), isNull, reason: 'back to the shipped formula');
  });

  test('a server too old to send a revision changes nothing', () async {
    await const FormulaOverridesStore()
        .save(withFormula('(h + 42 + cm) / feet'), revision: 3);

    await FormulaBookLoader(
      sync: serverAt(formula: '(h + 6 + cm) / feet', revision: 9, omitRevision: true),
    ).syncFromServer();

    expect(await onDevice(), '(h + 42 + cm) / feet',
        reason: 'a missing field must not be read as "the server is newer"');
  });

  test('an unreachable server leaves the device alone', () async {
    await const FormulaOverridesStore()
        .save(withFormula('(h + 6 + cm) / feet'), revision: 3);

    final FormulaBookLoader loader = FormulaBookLoader(
      sync: FormulaSyncApiClient(
        baseUrl: 'https://api.example.invalid',
        httpClient: MockClient((http.Request request) async {
          throw http.ClientException('no route');
        }),
      ),
    );

    await loader.syncFromServer(); // must not throw
    expect(await onDevice(), '(h + 6 + cm) / feet');
    expect(await const FormulaOverridesStore().revision(), 3);
  });

  test('saving records the revision the server gave it', () async {
    final List<String> writes = <String>[];
    final String? error = await FormulaBookLoader(sync: serverAt(revision: 6, writes: writes))
        .save(withFormula('(h + 6 + cm) / feet'));

    expect(error, isNull);
    expect(writes, hasLength(1));
    expect(await onDevice(), '(h + 6 + cm) / feet');
    expect(await const FormulaOverridesStore().revision(), 7);
  });

  test('a save the server refused keeps the formula and the old revision', () async {
    await const FormulaOverridesStore().save(FormulaOverrides.empty(), revision: 3);

    final String? error = await FormulaBookLoader(sync: serverAt(revision: 6, putStatus: 500))
        .save(withFormula('(h + 42 + cm) / feet'));

    expect(error, isNotNull, reason: 'the workshop is told it is not backed up');
    expect(await onDevice(), '(h + 42 + cm) / feet', reason: 'the change is still theirs');
    // Still 3, so the next sync sees a server that has not caught up and does
    // not treat its older copy as the newer word.
    expect(await const FormulaOverridesStore().revision(), 3);
  });
}
