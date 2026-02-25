import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/models/window_type.dart';
import 'package:my_app/features/estimation/presentation/input/window_input_handler.dart';

void main() {
  const WindowType mSectionNode = WindowType(
    label: 'Sliding Window M_Section',
    graphicKey: 'sliding_basic',
    children: <WindowType>[],
    displayIndex: 2,
    codeName: 'MS_win',
  );

  test('MS_win collar 1 sections include M-codes and exclude D29', () {
    final WindowInputHandler handler = handlerForWindow(mSectionNode);
    final List<String> collar1 = handler.sectionsForCollar(1);

    expect(collar1, contains('M30F'));
    expect(collar1, contains('M26F'));
    expect(collar1, isNot(contains('D29')));
  });

  test('MS_win collar 2 sections include M30 and M26', () {
    final WindowInputHandler handler = handlerForWindow(mSectionNode);
    final List<String> collar2 = handler.sectionsForCollar(2);

    expect(collar2, contains('M30'));
    expect(collar2, contains('M26'));
    expect(collar2, isNot(contains('D29')));
  });

  test('MS_win collar 13 sections include M30 and M26F', () {
    final WindowInputHandler handler = handlerForWindow(mSectionNode);
    final List<String> collar13 = handler.sectionsForCollar(13);

    expect(collar13, contains('M30'));
    expect(collar13, contains('M26F'));
    expect(collar13, isNot(contains('D29')));
  });
}
