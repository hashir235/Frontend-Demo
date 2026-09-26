import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/presentation/input/size_entry_notation.dart';
import 'package:my_app/features/fabrication/models/glass_report.dart';
import 'package:my_app/shared/format/cut_length.dart';
import 'package:my_app/shared/format/suter_half.dart';

/// The half suter is shown and typed as ½, and stored as it always was.
void main() {
  group('a suter as it is shown', () {
    test('whole suters stay whole, halves take the mark', () {
      expect(SuterHalf.format(0), '0');
      expect(SuterHalf.format(3), '3');
      expect(SuterHalf.format(3.5), '3½');
      expect(SuterHalf.format(0.5), '½');
      expect(SuterHalf.format(7.5), '7½');
    });

    test('is read back either way', () {
      expect(SuterHalf.parse('3½'), 3.5);
      expect(SuterHalf.parse('½'), 0.5);
      expect(SuterHalf.parse('3.5'), 3.5);
      expect(SuterHalf.parse('3'), 3);
      expect(SuterHalf.parse(''), isNull);
      expect(SuterHalf.toDecimal('5½'), '5.5');
      expect(SuterHalf.fromDecimal('5.5'), '5½');
      expect(SuterHalf.fromDecimal(''), '');
    });

    test('sizes that arrive as text show their halves as ½', () {
      expect(SuterHalf.inText("34'' 4.5'''"), "34'' 4½'''");
      expect(SuterHalf.inText("2' 3'' 0.5'''"), "2' 3'' ½'''");
      expect(
        SuterHalf.inText("27'' 6.5''' x 58'' 0.5'''"),
        "27'' 6½''' x 58'' ½'''",
      );
      // Only a suter is touched: whole suters, feet, centimetres and the
      // stored notation are left exactly as they were.
      expect(SuterHalf.inText("34'' 4'''"), "34'' 4'''");
      expect(SuterHalf.inText('12.5 ft'), '12.5 ft');
      expect(SuterHalf.inText('44.55'), '44.55');
      expect(SuterHalf.inText('10.5 cm'), '10.5 cm');
    });
  });

  group('the suter box', () {
    String type(String text) => const SuterBoxFormatter()
        .formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          ),
        )
        .text;

    test('the point or the space turns into ½ the moment it is pressed', () {
      expect(type('5.'), '5½');
      expect(type('5 '), '5½');
      expect(type('5,'), '5½', reason: 'the comma some keyboards have instead');
      expect(type('0.'), '½');
      expect(type('5'), '5');
      expect(type(''), '');
    });

    test('with no suter in front, the key does nothing', () {
      // A second press straight after the inch box moved on here must not
      // become a half nobody asked for.
      expect(type('.'), '');
      expect(type(' '), '');
      // A ½ already in the box is the half it says.
      expect(type('½'), '½');
    });

    test('nothing after the ½ is kept -- there is no other fraction', () {
      expect(type('5½7'), '5½');
      expect(type('5.5'), '5½');
    });

    TextEditingValue add(String before, String key) =>
        const SuterBoxFormatter().formatEditUpdate(
          TextEditingValue(
            text: before,
            selection: TextSelection.collapsed(offset: before.length),
          ),
          TextEditingValue(
            text: '$before$key',
            selection: TextSelection.collapsed(offset: before.length + 1),
          ),
        );

    test('an 8 or a 9 is not a suter and is never typed', () {
      expect(add('', '8').text, '');
      expect(add('', '9').text, '');
      expect(add('', '7').text, '7');
      expect(add('', '0').text, '0');
    });

    test('a suter is one digit -- a second one is not typed', () {
      expect(add('5', '3').text, '5');
      expect(add('0', '5').text, '0');
      expect(add('5', '.').text, '5½');
    });
  });

  group('the boxes that take a plain number', () {
    TextEditingValue add(TextInputFormatter formatter, String before, String key) =>
        formatter.formatEditUpdate(
          TextEditingValue(
            text: before,
            selection: TextSelection.collapsed(offset: before.length),
          ),
          TextEditingValue(
            text: '$before$key',
            selection: TextSelection.collapsed(offset: before.length + 1),
          ),
        );

    test('cm: one digit after the point -- 34.9, never 34.10', () {
      const TypedSizeFormatter cm = TypedSizeFormatter(TypedSizeUnit.cm);
      expect(add(cm, '34', '.').text, '34.');
      expect(add(cm, '34.', '9').text, '34.9');
      expect(add(cm, '34.1', '0').text, '34.1',
          reason: 'ten millimetres are the next centimetre');
      expect(add(cm, '34.', '.').text, '34.', reason: 'one point only');
      expect(add(cm, '3', '4').text, '34');
    });

    test('inch.suter: 0 to 7 after the point, and one digit', () {
      const TypedSizeFormatter inches =
          TypedSizeFormatter(TypedSizeUnit.inchSuter);
      expect(add(inches, '45.', '7').text, '45.7');
      expect(add(inches, '45.', '8').text, '45.');
      expect(add(inches, '45.', '9').text, '45.');
      expect(add(inches, '45.7', '5').text, '45.7');
    });

    test('feet.inch: 0 to 11 after the point', () {
      const TypedSizeFormatter feet =
          TypedSizeFormatter(TypedSizeUnit.feetInch);
      expect(add(feet, '4.', '9').text, '4.9');
      expect(add(feet, '4.1', '0').text, '4.10');
      expect(add(feet, '4.1', '1').text, '4.11');
      expect(add(feet, '4.1', '2').text, '4.1', reason: 'twelve inches make a foot');
      expect(add(feet, '4.0', '5').text, '4.0');
      expect(add(feet, '4.9', '1').text, '4.9');
    });

    test('the inch box beside a feet box: 0 to 11', () {
      const FootInchBoxFormatter inch = FootInchBoxFormatter();
      expect(add(inch, '', '0').text, '0');
      expect(add(inch, '', '9').text, '9');
      expect(add(inch, '1', '1').text, '11');
      expect(add(inch, '1', '0').text, '10');
      expect(add(inch, '1', '2').text, '1');
      expect(add(inch, '0', '5').text, '0');
      expect(add(inch, '', '.').text, '');
    });
  });

  group('the inch box of two boxes', () {
    test('the point or the space moves on to the suter box and is not kept',
        () async {
      for (final String key in <String>['.', ' ', ',']) {
        int movedOn = 0;
        final InchBoxFormatter formatter = InchBoxFormatter(
          onNext: () => movedOn++,
        );
        final TextEditingValue out = formatter.formatEditUpdate(
          const TextEditingValue(
            text: '42',
            selection: TextSelection.collapsed(offset: 2),
          ),
          TextEditingValue(
            text: '42$key',
            selection: const TextSelection.collapsed(offset: 3),
          ),
        );
        expect(out.text, '42', reason: 'key "$key"');
        await Future<void>.delayed(Duration.zero);
        expect(movedOn, 1, reason: 'key "$key"');
      }
    });

    test('digits go in, and an empty box does not move on', () async {
      int movedOn = 0;
      final InchBoxFormatter formatter = InchBoxFormatter(
        onNext: () => movedOn++,
      );
      final TextEditingValue digits = formatter.formatEditUpdate(
        const TextEditingValue(text: '4'),
        const TextEditingValue(text: '42'),
      );
      expect(digits.text, '42');
      final TextEditingValue empty = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '.'),
      );
      expect(empty.text, '');
      await Future<void>.delayed(Duration.zero);
      expect(movedOn, 0);
    });
  });

  group('the merged size box', () {
    TextEditingValue typeInto(String before, int caret, String typed) {
      final String text =
          before.substring(0, caret) + typed + before.substring(caret);
      return const MergedSizeFormatter().formatEditUpdate(
        TextEditingValue(
          text: before,
          selection: TextSelection.collapsed(offset: caret),
        ),
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: caret + typed.length),
        ),
      );
    }

    test('a point after the suter shows as ½, the cursor after it', () {
      // "34'' 4'''" with the cursor after the 4, then the point.
      final TextEditingValue out = typeInto("34'' 4'''", 6, '.');
      expect(out.text, "34'' 4½'''");
      expect(out.selection.baseOffset, "34'' 4½".length);
    });

    test('a point straight after the space, with no suter yet, does nothing',
        () {
      // Two presses after the inch are a slip, not half a suter.
      final TextEditingValue out = typeInto("34'' ", 5, '.');
      expect(out.text, "34'' ");
      expect(out.selection.baseOffset, 5);
    });

    test('a digit typed after the ½ is dropped and the cursor stays put', () {
      final TextEditingValue out = typeInto("34'' 4½'''", "34'' 4½".length, '5');
      expect(out.text, "34'' 4½'''");
      expect(out.selection.baseOffset, "34'' 4½".length);
    });

    test('feet mode has no half suter and is left as it was', () {
      expect(SizeNotation.displayMerged('13 7', isFeet: true), "13' 7''");
    });

    test('what is typed is stored exactly as before', () {
      expect(
        SizeNotation.mergedToStored("34'' 4½'''", isFeet: false),
        '34.45',
      );
      expect(SizeNotation.mergedToStored("34'' ½'''", isFeet: false), '34.05');
      expect(SizeNotation.mergedToStored("34'' 4'''", isFeet: false), '34.4');
      // And an older box still holding the decimal reads the same.
      expect(
        SizeNotation.mergedToStored("34'' 4.5'''", isFeet: false),
        '34.45',
      );
    });

    test('a stored half opens with its ½', () {
      expect(SizeNotation.storedToMerged('44.55', isFeet: false), "44'' 5½'''");
      expect(SizeNotation.storedToMerged('34.05', isFeet: false), "34'' ½'''");
      expect(SizeNotation.storedToMerged('23.4', isFeet: false), "23'' 4'''");
    });

    test('checks the suter with its ½', () {
      expect(SizeNotation.validateMergedInches("44'' 5½'''"), isNull);
      expect(SizeNotation.validateMergedInches("44'' 7½'''"), isNull);
      expect(SizeNotation.validateMergedInches("44'' 9½'''"), isNotNull);
      expect(SizeNotation.combineInchSuter('44', '5½'), '44.55');
      expect(SizeNotation.combineInchSuter('44', '½'), '44.05');
    });
  });

  group('typed key by key, the point and the space are one key', () {
    const MergedSizeFormatter formatter = MergedSizeFormatter();

    // One key at the cursor, the way a keyboard sends it.
    TextEditingValue press(TextEditingValue v, String key) {
      final int at = v.selection.isValid ? v.selection.end : v.text.length;
      return formatter.formatEditUpdate(
        v,
        TextEditingValue(
          text: v.text.substring(0, at) + key + v.text.substring(at),
          selection: TextSelection.collapsed(offset: at + key.length),
        ),
      );
    }

    TextEditingValue backspace(TextEditingValue v) {
      final int at = v.selection.end;
      return formatter.formatEditUpdate(
        v,
        TextEditingValue(
          text: v.text.substring(0, at - 1) + v.text.substring(at),
          selection: TextSelection.collapsed(offset: at - 1),
        ),
      );
    }

    TextEditingValue typeKeys(List<String> keys, [TextEditingValue? from]) {
      TextEditingValue v = from ?? TextEditingValue.empty;
      for (final String key in keys) {
        v = press(v, key);
      }
      return v;
    }

    TextEditingValue at(String text, int caret) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret),
    );

    test("42'' 4½''' -- inch, point or space, suter, point or space", () {
      for (final List<String> keys in <List<String>>[
        <String>['4', '2', '.', '4', '.'],
        <String>['4', '2', ' ', '4', ' '],
        <String>['4', '2', '.', '4', ' '],
        <String>['4', '2', ' ', '4', '.'],
        <String>['4', '2', ',', '4', ','],
      ]) {
        final TextEditingValue v = typeKeys(keys);
        expect(v.text, "42'' 4½'''", reason: keys.join());
        expect(v.text.contains('.'), isFalse,
            reason: 'no point between the suter and its half');
        expect(v.selection.baseOffset, "42'' 4½".length,
            reason: 'the cursor sits after the ½');
        expect(SizeNotation.mergedToStored(v.text, isFeet: false), '42.45',
            reason: 'stored exactly as before');
      }
    });

    test('the point after the inch moves the cursor on to the suter', () {
      final TextEditingValue v = typeKeys(<String>['4', '2', '.']);
      expect(v.text, "42'' ");
      expect(v.selection.baseOffset, 5);
      final TextEditingValue suter = press(v, '4');
      expect(suter.text, "42'' 4'''");
      expect(SizeNotation.mergedToStored(suter.text, isFeet: false), '42.4');
    });

    test('half a suter on its own is 0 and then the point', () {
      final TextEditingValue v = typeKeys(<String>['4', '2', '.', '0', '.']);
      expect(v.text, "42'' ½'''");
      expect(SizeNotation.mergedToStored(v.text, isFeet: false), '42.05');
    });

    test('a second press straight after the inch is a slip, not a half', () {
      expect(typeKeys(<String>['4', '2', '.', '.']).text, "42'' ");
      expect(typeKeys(<String>['4', '2', ' ', '.']).text, "42'' ");
      expect(typeKeys(<String>['4', '2', '.', '.', '4']).text, "42'' 4'''");
    });

    test('a suter is one digit, 0 to 7 -- an 8 or 9 is never typed', () {
      expect(typeKeys(<String>['3', '4', '.', '8']).text, "34'' ");
      expect(typeKeys(<String>['3', '4', '.', '9']).text, "34'' ");
      expect(typeKeys(<String>['3', '4', '.', '7']).text, "34'' 7'''");
      expect(typeKeys(<String>['3', '4', '.', '0']).text, "34'' 0'''");
    });

    test('a second suter digit is not typed', () {
      final TextEditingValue v = typeKeys(<String>['3', '4', '.', '4', '5']);
      expect(v.text, "34'' 4'''");
      expect(v.selection.baseOffset, "34'' 4".length);
      expect(typeKeys(<String>['3', '4', '.', '0', '5']).text, "34'' 0'''");
    });

    test('a digit that does not fit leaves the size exactly as it was', () {
      // The cursor in front of the suter: a second digit there would push the
      // 4 out, and 34'' 7''' is not what was on the tape.
      final TextEditingValue v = press(at("34'' 4'''", 5), '7');
      expect(v.text, "34'' 4'''");
      expect(v.selection.baseOffset, 5);
    });

    test('a pasted size keeps only what is a size', () {
      final TextEditingValue v = const MergedSizeFormatter().formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '34 89',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      expect(v.text, "34'' ");
    });

    test('nothing is kept after the half', () {
      expect(
        typeKeys(<String>['4', '2', '.', '4', '.', '5', '.', ' ']).text,
        "42'' 4½'''",
      );
    });

    test('letters never reach the box', () {
      expect(typeKeys(<String>['4', 'a', '2', '-']).text, "42''");
    });

    test('a point in the middle of the inch changes nothing', () {
      final TextEditingValue v = press(at("42'' 4'''", 1), '.');
      expect(v.text, "42'' 4'''");
      expect(v.selection.baseOffset, 1);
    });

    test('a point at the end of the inch, with the suter begun, moves on to it',
        () {
      final TextEditingValue v = press(at("42'' 4'''", 2), '.');
      expect(v.text, "42'' 4'''", reason: 'the size is left as it was');
      expect(v.selection.baseOffset, "42'' 4".length);
      expect(press(v, '.').text, "42'' 4½'''");
    });

    test('a digit typed into the inch goes into the inch', () {
      final TextEditingValue v = press(at("42'' 4½'''", 1), '3');
      expect(v.text, "432'' 4½'''");
      expect(v.selection.baseOffset, 2);
    });

    test('backspace over the space never runs the suter into the inch', () {
      // 42 4 must not become 424, a size that looks right and is not: the
      // cursor steps back over the space instead.
      final TextEditingValue v = backspace(at("42'' 4'''", 5));
      expect(v.text, "42'' 4'''");
      expect(v.selection.baseOffset, 2);
      expect(backspace(v).text, "4'' 4'''");
    });

    test('backspace from the end takes the size apart one key at a time', () {
      TextEditingValue v = typeKeys(<String>['4', '2', '.', '4', '.']);
      v = backspace(v);
      expect(v.text, "42'' 4'''");
      v = backspace(v);
      expect(v.text, "42'' ");
      v = backspace(v);
      expect(v.text, "42''");
      v = backspace(v);
      expect(v.text, "4''");
      v = backspace(v);
      expect(v.text, '');
    });

    test('a stored size opens as it would be typed, and reads back the same',
        () {
      for (final (String stored, String shown) in <(String, String)>[
        ('42.45', "42'' 4½'''"),
        ('42.05', "42'' ½'''"),
        ('42.4', "42'' 4'''"),
        ('42.0', "42''"),
      ]) {
        final String opened = SizeNotation.storedToMerged(stored, isFeet: false);
        expect(opened, shown);
        expect(SizeNotation.mergedToStored(opened, isFeet: false), stored);
      }
    });
  });

  group('everywhere else a suter is shown', () {
    test('a cut length reads its half as ½', () {
      // 85 inches and a suter and a half.
      final CutLength length = CutLength.fromFeet((85 + 1.5 / 8) / 12);
      expect(length.inInchSuter, "85'' 1½'''");
      expect(length.inFeetInchSuter, "7' 1'' 1½'''");
    });

    test('a glass size goes to the server with its .5, and reads back either way',
        () {
      const GlassDimension half = GlassDimension(inches: 27, sutter: 6.5);
      expect(half.display, "27'' 6.5'''",
          reason: 'the server works the glass out from this string');
      final GlassDimension fromMark =
          GlassDimension.fromRow(display: "27'' 6½'''", cm: 0);
      expect(fromMark.inches, 27);
      expect(fromMark.sutter, 6.5);
      final GlassDimension fromLone =
          GlassDimension.fromRow(display: "27'' ½'''", cm: 0);
      expect(fromLone.sutter, 0.5);
    });
  });
}
