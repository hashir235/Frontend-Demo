import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/models/optimization_request.dart';
import 'package:my_app/features/estimation/models/window_material.dart';
import 'package:my_app/features/estimation/models/window_review_item.dart';

/// The engine keys its cutting piles and its rates on gauge and colour, so a
/// request that leaves them out asks for exactly the behaviour this feature
/// replaced: one pile per profile, one rate for the job.
///
/// This is the path that was broken. OptimizationWindowRequest is a separate
/// model from WindowReviewItem and copies fields one at a time, so putting the
/// material on the item was not enough -- it never reached the wire. These
/// tests look at the JSON that actually goes out.
void main() {
  WindowReviewItem window(int winNo, WindowMaterial material) {
    return WindowReviewItem(
      winNo: winNo,
      windowLabel: 'Sliding Window',
      windowCode: 'S_win',
      windowIndex: 1,
      collarIndex: 1,
      unitMode: UnitMode.inches,
      heightValue: '60.0',
      widthValue: '60.0',
      material: material,
    );
  }

  const WindowMaterial champagne12 = WindowMaterial(
    gauge: '1.2mm',
    color: 'H23/PC-RAL',
  );
  const WindowMaterial black2 = WindowMaterial(
    gauge: '2mm',
    color: 'BLACK/ MULTI',
  );

  List<Map<String, Object?>> windowsOf(OptimizationRequest request) {
    return (request.toJson()['windows']! as List<Object?>)
        .cast<Map<String, Object?>>();
  }

  test('each window carries its own material onto the wire', () {
    final OptimizationRequest request = OptimizationRequest.fromReviewItems(
      <WindowReviewItem>[window(1, champagne12), window(2, black2)],
      projectName: 'mixed',
      projectLocation: 'test',
    );

    final List<Map<String, Object?>> windows = windowsOf(request);
    expect(windows, hasLength(2));

    expect(windows[0]['gauge'], '1.2mm');
    expect(windows[0]['color'], 'H23/PC-RAL');
    expect(windows[1]['gauge'], '2mm');
    expect(windows[1]['color'], 'BLACK/ MULTI');
  });

  test('two windows in one stock send the same pair', () {
    final OptimizationRequest request = OptimizationRequest.fromReviewItems(
      <WindowReviewItem>[window(1, black2), window(2, black2)],
      projectName: 'uniform',
      projectLocation: 'test',
    );

    final List<Map<String, Object?>> windows = windowsOf(request);
    expect(windows[0]['gauge'], windows[1]['gauge']);
    expect(windows[0]['color'], windows[1]['color']);
    expect(windows[0]['gauge'], '2mm');
  });

  test('fabrication requests carry it too', () {
    final OptimizationRequest request = OptimizationRequest.fromReviewItems(
      <WindowReviewItem>[window(1, black2)],
      context: 'fabrication',
      projectName: 'fab',
      projectLocation: 'test',
    );

    expect(windowsOf(request)[0]['gauge'], '2mm');
    expect(windowsOf(request)[0]['color'], 'BLACK/ MULTI');
  });

  test('a window saved before stock existed sends empty, not a guess', () {
    // Empty tells the engine to use the job-wide pair the request also
    // carries. A guess of "1.2mm" here would re-specify a job that may have
    // been cut in 2mm.
    final WindowReviewItem legacy = WindowReviewItem.fromJson(
      <String, dynamic>{
        'winNo': 1,
        'windowLabel': 'Sliding Window',
        'windowCode': 'S_win',
        'windowIndex': 1,
        'collarIndex': 1,
        'unitMode': 'inches',
        'heightValue': '60.0',
        'widthValue': '60.0',
      },
    );

    expect(legacy.material.isSet, isFalse);
    expect(legacy.material.gauge, '');
    expect(legacy.material.color, '');
  });

  test('a window round-trips its material through JSON', () {
    final WindowReviewItem saved = window(3, black2);
    final WindowReviewItem loaded = WindowReviewItem.fromJson(
      Map<String, dynamic>.from(saved.toJson()),
    );

    expect(loaded.material.gauge, '2mm');
    expect(loaded.material.color, 'BLACK/ MULTI');
    expect(loaded.material.isSet, isTrue);
  });

  test('orElse fills only what is missing', () {
    const WindowMaterial nothing = WindowMaterial(gauge: '', color: '');
    expect(nothing.orElse(black2), black2);

    // Half-set: keep what is there, borrow the rest.
    const WindowMaterial halfSet = WindowMaterial(gauge: '2mm', color: '');
    final WindowMaterial filled = halfSet.orElse(champagne12);
    expect(filled.gauge, '2mm');
    expect(filled.color, 'H23/PC-RAL');

    // Fully set: untouched.
    expect(black2.orElse(champagne12), black2);
  });
}
