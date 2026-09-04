import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/formulas/model/formula_expression.dart';

/// The formula language is the one place in Quick AL where a user's typing
/// turns straight into a length someone cuts metal to. These tests hold it to
/// that: the arithmetic has to be the arithmetic they wrote, and anything it
/// cannot honour has to be refused rather than guessed at.
void main() {
  double eval(String source, [Map<String, double> vars = const <String, double>{}]) {
    return FormulaExpression.parse(source).evaluate(vars);
  }

  group('arithmetic', () {
    test('reads the sums the engine already uses', () {
      // ((h + 6) + cm) / feet, the commonest formula in the whole catalogue.
      const Map<String, double> vars = <String, double>{
        'h': 220.6,
        'cm': 0.5,
        'feet': 30.48,
      };
      expect(eval('((h + 6) + cm) / feet', vars), closeTo((220.6 + 6 + 0.5) / 30.48, 1e-12));
    });

    test('divides before it adds', () {
      expect(eval('1 + 6 / 2'), 4);
      expect(eval('(1 + 6) / 2'), 3.5);
    });

    test('subtracts left to right', () {
      // The one case where getting associativity wrong still parses: 10-3-2
      // is 5, not 9.
      expect(eval('10 - 3 - 2'), 5);
      expect(eval('20 / 2 / 5'), 2);
    });

    test('carries a leading minus', () {
      expect(eval('-4.2 + 10'), closeTo(5.8, 1e-12));
      expect(eval('-(3 + 2)'), -5);
      expect(eval('h * -2', <String, double>{'h': 3}), -6);
    });

    test('works the deep bracket nests the panel formulas use', () {
      // From SG_Win_f, centre-fix latch: the deepest real formula in the app.
      const Map<String, double> vars = <String, double>{
        'w': 182.5,
        'cm': 0.4,
        'feet': 30.48,
      };
      const String source = '((((((w - 20.32) / 2) - 5.08) / 2) + 8.5) + cm) / feet';
      final double expected = ((((((182.5 - 20.32) / 2) - 5.08) / 2) + 8.5) + 0.4) / 30.48;
      expect(eval(source, vars), closeTo(expected, 1e-12));
    });

    test('does not mind how the spacing falls', () {
      const Map<String, double> vars = <String, double>{'w': 100, 'cm': 1, 'feet': 30.48};
      final double tight = eval('((w-15.5)/2+cm)/feet', vars);
      final double loose = eval('  ( ( w - 15.5 ) / 2 + cm ) / feet  ', vars);
      expect(tight, loose);
    });
  });

  group('refusing what it cannot honour', () {
    test('an empty formula', () {
      expect(() => eval(''), throwsA(isA<FormulaError>()));
      expect(() => eval('   '), throwsA(isA<FormulaError>()));
    });

    test('a bracket left open', () {
      final FormulaError error = _errorOf('((h + 6) / feet');
      expect(error.message, contains('never closed'));
      expect(error.offset, 0);
    });

    test('a bracket with nothing opening it', () {
      expect(_errorOf('h + 6)').message, contains('nothing opening it'));
    });

    test('an operator with nothing after it', () {
      expect(() => eval('h + '), throwsA(isA<FormulaError>()));
    });

    test('characters that are not arithmetic', () {
      final FormulaError error = _errorOf('h ^ 2');
      expect(error.message, contains('"^"'));
      expect(error.offset, 2);
    });

    test('a measurement the window does not have', () {
      // This is the dangerous one: it parses perfectly.
      expect(() => eval('d + 6', <String, double>{'h': 1}), throwsA(isA<FormulaError>()));
    });

    test('dividing by zero', () {
      final Object error = _thrown(() => eval('h / 0', <String, double>{'h': 5}));
      expect((error as FormulaError).message, contains('divides by zero'));
    });

    test('a runaway nest rather than a stack overflow', () {
      final String deep = '${'(' * 500}h${')' * 500}';
      expect(() => eval(deep, <String, double>{'h': 1}), throwsA(isA<FormulaError>()));
    });
  });

  group('naming what it reads', () {
    test('lists the measurements in play', () {
      expect(
        FormulaExpression.parse('((h + 6) + cm) / feet').variables,
        <String>{'h', 'cm', 'feet'},
      );
      expect(FormulaExpression.parse('4 + 2').variables, isEmpty);
    });

    test('a formula is checked against what the window can offer', () {
      final FormulaCheck ok = FormulaCheck.of(
        '((h + 6) + cm) / feet',
        allowedVariables: <String>{'h', 'w', 'cm', 'feet'},
      );
      expect(ok.isUsable, isTrue);
      expect(ok.problem, isNull);

      final FormulaCheck strayName = FormulaCheck.of(
        '((height + 6) + cm) / feet',
        allowedVariables: <String>{'h', 'w', 'cm', 'feet'},
      );
      expect(strayName.isUsable, isFalse);
      expect(strayName.problem, contains('height'));

      final FormulaCheck broken = FormulaCheck.of(
        '((h + 6) + cm / feet',
        allowedVariables: <String>{'h', 'cm', 'feet'},
      );
      expect(broken.isUsable, isFalse);
      expect(broken.expression, isNull);
    });
  });

  group('writing itself back out', () {
    test('keeps only the brackets that change the answer', () {
      expect(FormulaExpression.parse('(h + 6) / feet').toString(), '(h + 6) / feet');
      expect(FormulaExpression.parse('h + (6 / feet)').toString(), 'h + 6 / feet');
      expect(FormulaExpression.parse('h - (a - b)').toString(), 'h - (a - b)');
      expect(FormulaExpression.parse('h - a - b').toString(), 'h - a - b');
    });

    test('drops a trailing zero but keeps a real decimal', () {
      expect(FormulaExpression.parse('6').toString(), '6');
      expect(FormulaExpression.parse('6.0').toString(), '6');
      expect(FormulaExpression.parse('4.2').toString(), '4.2');
      expect(FormulaExpression.parse('20.32').toString(), '20.32');
    });

    test('round-trips to the same number', () {
      const List<String> sources = <String>[
        '((h + 6) + cm) / feet',
        '((((w - 20.32) / 2) - 5.08) / 2 + 8.5 + cm) / feet',
        '(((w - 15.5) / 2) + cm) / feet',
        '-4.2 + h * 2 - 1',
        'h - (w - 3) / 2',
      ];
      const Map<String, double> vars = <String, double>{
        'h': 180.4,
        'w': 122.7,
        'cm': 0.6,
        'feet': 30.48,
      };
      for (final String source in sources) {
        final FormulaExpression first = FormulaExpression.parse(source);
        final FormulaExpression again = FormulaExpression.parse(first.toString());
        expect(
          again.evaluate(vars),
          closeTo(first.evaluate(vars), 1e-12),
          reason: 'rewriting "$source" as "${first.toString()}" changed the answer',
        );
      }
    });
  });

  group('lengths that cannot be cut', () {
    FormulaResult resultOf(String source, Map<String, double> vars) {
      return FormulaResult.of(FormulaExpression.parse(source), vars, label: 'HL');
    }

    test('a good length comes through', () {
      final FormulaResult result = resultOf(
        '((h + 6) + cm) / feet',
        <String, double>{'h': 220.6, 'cm': 0.5, 'feet': 30.48},
      );
      expect(result.isUsable, isTrue);
      expect(result.value, closeTo(7.451, 0.001));
    });

    test('a window smaller than its own deduction', () {
      // A 10cm window through a formula that takes 20.32 off it.
      final FormulaResult result = resultOf(
        '((w - 20.32) + cm) / feet',
        <String, double>{'w': 10, 'cm': 0, 'feet': 30.48},
      );
      expect(result.isUsable, isFalse);
      expect(result.problem, contains('longer than nothing'));
    });

    test('a slipped decimal point', () {
      final FormulaResult result = resultOf(
        'h / feet',
        <String, double>{'h': 500000, 'feet': 30.48},
      );
      expect(result.isUsable, isFalse);
      expect(result.problem, contains('longer than any stock length'));
    });

    test('rounds to the thousandth the optimizer counts in', () {
      final FormulaResult result = resultOf(
        'h / feet',
        <String, double>{'h': 100, 'feet': 30.48},
      );
      // 100 / 30.48 = 3.2808398950131235
      expect(result.asCutLength, 3.281);
    });
  });
}

FormulaError _errorOf(String source) {
  return _thrown(() => FormulaExpression.parse(source)) as FormulaError;
}

Object _thrown(void Function() body) {
  try {
    body();
  } catch (error) {
    return error;
  }
  throw StateError('expected this to throw, and it did not');
}
