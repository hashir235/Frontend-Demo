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

    test('the point turns into ½ the moment it is pressed', () {
      expect(type('5.'), '5½');
      expect(type('.'), '½');
      expect(type('0.'), '½');
      expect(type('5'), '5');
      expect(type(''), '');
    });

    test('nothing after the ½ is kept -- there is no other fraction', () {
      expect(type('5½7'), '5½');
      expect(type('5.5'), '5½');
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

    test('a point straight after the space is half a suter on its own', () {
      final TextEditingValue out = typeInto("34'' ", 5, '.');
      expect(out.text, "34'' ½'''");
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
