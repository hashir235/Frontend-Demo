/// A formula read, and written, in inches and suter.
///
/// A workshop that measures in inches thinks in inches. The formulas are kept
/// in centimetres on the fabrication side and in feet on the estimation side,
/// because that is what the engine reads -- and asking an inch shop to adjust
/// `HL - 4.2` asks it to convert in its head before it can change a thing
/// (Hashir, Oct 2026). So for a window measured in inches the same formula is
/// shown, and typed, the way the tape reads: `HL - 1'' 5'''`.
///
/// Only the reading changes. What is stored is still centimetres or feet, and
/// the margin and the feet conversion are still put back by [FormulaSlot].
/// A number nobody touched also keeps its exact stored value, even where its
/// inch reading is only the nearest half suter: opening a formula in inches
/// and changing one number in it must not nudge every other number in it by
/// up to a millimetre.
library;

import '../../../shared/format/suter_half.dart';
import 'formula_expression.dart';
import 'formula_slot.dart';

/// A length on an inchi tape, to its finest mark.
///
/// Counted in sixteenths of an inch -- half a suter -- so it is always a whole
/// number of marks and never a decimal that only looks like one.
class InchLength {
  const InchLength(this.sixteenths) : assert(sixteenths >= 0);

  /// Whole inches and suter, the suter in halves: `inches: 1, suter: 2.5`.
  factory InchLength.of({int inches = 0, double suter = 0}) =>
      InchLength(inches * 16 + (suter * 2).round());

  /// The nearest mark to [inches]. Never below nothing.
  factory InchLength.nearest(double inches) {
    final int marks = (inches * 16).round();
    return InchLength(marks < 0 ? 0 : marks);
  }

  /// Sixteenths of an inch -- half suter.
  final int sixteenths;

  /// Whole inches.
  int get inches => sixteenths ~/ 16;

  /// Suter past the whole inches, in halves: 0, 0.5 ... 7.5.
  double get suter => (sixteenths % 16) / 2;

  double get asInches => sixteenths / 16;

  /// The same length moved on by [marks] half suter, never below nothing.
  InchLength step(int marks) {
    final int moved = sixteenths + marks;
    return InchLength(moved < 0 ? 0 : moved);
  }

  /// As the tape is read: `6''`, `1'' 2½'''`, `3'''`, `0½'''`, `0''`.
  ///
  /// Half a suter on its own reads `0½`, as it does everywhere else a size
  /// is listed -- a bare ½ was being read as nothing (Oct 2026).
  String get text {
    final int halves = sixteenths % 16;
    if (sixteenths == 0) return "0''";
    final String suterText = "${SuterHalf.shown(halves / 2)}'''";
    if (inches == 0) return suterText;
    if (halves == 0) return "$inches''";
    return "$inches'' $suterText";
  }

  @override
  bool operator ==(Object other) =>
      other is InchLength && other.sixteenths == sixteenths;

  @override
  int get hashCode => sixteenths.hashCode;

  @override
  String toString() => text;
}

/// How a formula's own unit stands to the inch.
///
/// Fabrication's formulas work in centimetres and estimation's in feet; the
/// inch is only how they are read.
class FormulaInchUnit {
  const FormulaInchUnit({required this.isFabrication});

  final bool isFabrication;

  /// How far off a mark a value may be and still be that mark. Far finer
  /// than any tape, and far coarser than the rounding a value picks up on its
  /// way through a conversion and a saved string.
  static const double _onTheMark = 1e-4;

  /// [value], in the formula's unit, as inches.
  double inchesOf(double value) => isFabrication ? value / 2.54 : value * 12;

  /// The nearest mark to [value].
  InchLength nearest(double value) => InchLength.nearest(inchesOf(value));

  /// Whether [value] sits exactly on a half-suter mark.
  bool isOnTheMark(double value) {
    final double marks = inchesOf(value) * 16;
    return (marks - marks.roundToDouble()).abs() <= _onTheMark;
  }

  /// [length] in the formula's unit, as a clean decimal.
  ///
  /// A half suter is 0.15875 cm exactly, so every mark comes out in five
  /// decimal places or fewer; in feet it is 1/192, which never ends, and
  /// eight places are kept -- a twentieth of a micrometre. Either way the
  /// stored formula reads as a number, not a floating-point accident.
  double valueOf(InchLength length) {
    final double raw =
        isFabrication ? length.asInches * 2.54 : length.asInches / 12;
    return double.parse(raw.toStringAsFixed(isFabrication ? 6 : 8));
  }

  /// The unit's own name, said in full.
  String get unitName => isFabrication ? 'centimetres' : 'feet';

  /// [value] said in the formula's own unit: `15.5 cm`, `1 ft`.
  String say(double value) {
    String fixed = value.toStringAsFixed(isFabrication ? 4 : 6);
    if (fixed.contains('.')) {
      fixed = fixed
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
    }
    return '$fixed ${isFabrication ? 'cm' : 'ft'}';
  }
}

/// What a number in a formula is.
enum NumberRole {
  /// Something added or taken away -- a length, `4.2` in `HL - 4.2`.
  length,

  /// Something divided or multiplied by -- a plain count, `2` in `/ 2`.
  count,
}

/// Which numbers in a formula are lengths and which are counts.
///
/// Worked out from the shape of the arithmetic, the way a fabricator reads
/// it: whatever is added to or taken from a measurement is a length too, and
/// whatever a length is divided or multiplied by is a plain number. That is
/// what decides which numbers are shown in inches and which stay as they are
/// -- `(WT - 6'' 1''') / 2`, never `/ 2''`.
class FormulaRoles {
  const FormulaRoles._();

  /// The role of every number in [core], or null when [core] does not come
  /// out as a length at all -- a measurement multiplied by a measurement, or
  /// divided into something -- and so has no reading in inches.
  ///
  /// [marked] settles the one case the shape cannot: two plain numbers
  /// multiplied together, where either could be the length. Without it the
  /// first is taken for the length, the way `4 / 2` reads.
  static Map<FormulaNumber, NumberRole>? of(
    FormulaExpression core, {
    bool Function(FormulaNumber number)? marked,
  }) {
    final Map<FormulaNumber, NumberRole> roles =
        Map<FormulaNumber, NumberRole>.identity();
    return _assign(core, true, roles, marked) ? roles : null;
  }

  static bool _assign(
    FormulaExpression e,
    bool isLength,
    Map<FormulaNumber, NumberRole> roles,
    bool Function(FormulaNumber)? marked,
  ) {
    switch (e) {
      case FormulaNumber():
        roles[e] = isLength ? NumberRole.length : NumberRole.count;
        return true;
      case FormulaVariable():
        // A measurement is a length, and a length where a count belongs --
        // `100 / HL` -- is not something a tape can read.
        return isLength;
      case FormulaNegate(:final FormulaExpression operand):
        return _assign(operand, isLength, roles, marked);
      case FormulaBinary(
          :final String op,
          :final FormulaExpression left,
          :final FormulaExpression right,
        ):
        switch (op) {
          case '+':
          case '-':
            return _assign(left, isLength, roles, marked) &&
                _assign(right, isLength, roles, marked);
          case '/':
            return _assign(left, isLength, roles, marked) &&
                _assign(right, false, roles, marked);
          case '*':
            if (!isLength) {
              return _assign(left, false, roles, marked) &&
                  _assign(right, false, roles, marked);
            }
            final bool leftMeasures = left.variables.isNotEmpty;
            final bool rightMeasures = right.variables.isNotEmpty;
            if (leftMeasures && rightMeasures) return false;
            final bool rightIsLength = rightMeasures ||
                (!leftMeasures &&
                    marked != null &&
                    _anyMarked(right, marked) &&
                    !_anyMarked(left, marked));
            return _assign(left, !rightIsLength, roles, marked) &&
                _assign(right, rightIsLength, roles, marked);
        }
        return false;
    }
  }

  static bool _anyMarked(
    FormulaExpression e,
    bool Function(FormulaNumber) marked,
  ) {
    return numbersInOrder(e).any(marked);
  }

  /// Every number in [e], in the order it is written.
  static List<FormulaNumber> numbersInOrder(FormulaExpression e) {
    final List<FormulaNumber> found = <FormulaNumber>[];
    void walk(FormulaExpression node) {
      switch (node) {
        case FormulaNumber():
          found.add(node);
        case FormulaVariable():
          break;
        case FormulaNegate(:final FormulaExpression operand):
          walk(operand);
        case FormulaBinary(
            :final FormulaExpression left,
            :final FormulaExpression right,
          ):
          walk(left);
          walk(right);
      }
    }

    walk(e);
    return found;
  }
}

/// One piece of a formula as it is shown in inches.
sealed class InchPart {
  const InchPart();

  /// What it reads as, joined with the rest into the formula's text.
  String get text;
}

/// Operators, brackets and plain counts: ` - `, `) / 2 + `.
class InchWords extends InchPart {
  const InchWords(this.text);

  @override
  final String text;
}

/// The piece's own measurement -- where the window's size stands.
class InchMeasurement extends InchPart {
  const InchMeasurement(this.label);

  final String label;

  @override
  String get text => label;
}

/// A length in the formula, in inches and suter.
class InchLengthPart extends InchPart {
  const InchLengthPart(
    this.index,
    this.length, {
    required this.approximate,
    this.kept,
  });

  /// Which length this is, counting from the left from 0.
  final int index;

  final InchLength length;

  /// True when [length] is only the nearest mark to what is stored -- a
  /// shipped 4.2 cm is 1'' 5''' to the half suter, not exactly.
  final bool approximate;

  /// The exact value this number stands for, in the formula's own unit, when
  /// it is one the formula already had and is kept as it was.
  final double? kept;

  @override
  String get text => length.text;
}

/// What came of reading a formula typed in inches.
class InchReading {
  const InchReading._(this.edit, this.parts);

  factory InchReading._refused(String problem) =>
      InchReading._(FormulaEdit.refused(problem), null);

  /// The formula ready to save, or why it cannot be.
  final FormulaEdit edit;

  /// The formula as the screen shows it, number by number. Null when it
  /// cannot be used.
  final List<InchPart>? parts;

  bool get isUsable => edit.isUsable;

  /// The formula written out the one way the app writes it.
  String? get canonical => parts?.map((InchPart p) => p.text).join();
}

/// One piece's formula, seen through an inch tape.
///
/// Built on the formula the screen last put in the box -- the one it opened
/// with, or Quick AL's own after "put back" -- because that is what any
/// number left as it was has to be read back to.
class InchFormula {
  InchFormula._(this.slot, this.unit, this._reference, this.parts);

  /// [slot] read in inches, or null when its formula does not come out as a
  /// length -- `HL * HL` -- and can only be shown in the unit it is stored in.
  static InchFormula? of(FormulaSlot slot) {
    final FormulaInchUnit unit =
        FormulaInchUnit(isFabrication: slot.isFabrication);
    final FormulaExpression core = slot.displayExpression;
    final Map<FormulaNumber, NumberRole>? roles = FormulaRoles.of(core);
    if (roles == null) return null;

    final List<_Reference> reference = <_Reference>[];
    final List<InchPart> parts = _write(
      core,
      label: slot.label,
      number: (FormulaNumber n) {
        if (roles[n] != NumberRole.length) return InchWords(n.toString());
        final InchLength nearest = unit.nearest(n.value);
        final bool approximate = !unit.isOnTheMark(n.value);
        reference.add(_Reference(n.value, nearest, approximate));
        return InchLengthPart(
          reference.length - 1,
          nearest,
          approximate: approximate,
          kept: n.value,
        );
      },
    );
    return InchFormula._(slot, unit, reference, parts);
  }

  /// The formula this reading was made from.
  final FormulaSlot slot;

  final FormulaInchUnit unit;

  /// Its lengths, exact, in the order they are written.
  final List<_Reference> _reference;

  /// The formula as first shown.
  final List<InchPart> parts;

  /// The formula as first shown, as text: `(WT - 6'' 1''') / 2 + 3'' 3'''`.
  String get text => parts.map((InchPart p) => p.text).join();

  /// Whether any of its numbers is only shown to the nearest half suter.
  bool get hasApproximate => _reference.any((_Reference r) => r.approximate);

  /// Reads [typed] -- the formula in inches -- back into the catalogue's own
  /// names and unit, or says why it cannot be.
  InchReading read(String typed) {
    final _InchParser parser = _InchParser(typed);
    final FormulaExpression expression;
    try {
      expression = parser.parseWhole();
    } on FormulaError catch (error) {
      return InchReading._refused(error.message);
    }

    // A name this piece does not have says more than anything about the
    // numbers around it.
    final List<String> unknown = expression.variables
        .where((String name) => !slot.allowedDisplayVariables.contains(name))
        .toList(growable: false);
    if (unknown.isNotEmpty) {
      return InchReading._refused(
        unknown.length == 1
            ? '${unknown.first} is not a measurement this window has.'
            : '${unknown.join(', ')} are not measurements this window has.',
      );
    }

    final Map<FormulaNumber, NumberRole>? roles = FormulaRoles.of(
      expression,
      marked: parser.lengths.containsKey,
    );
    if (roles == null) {
      return InchReading._refused(
        'This does not come out as a length: ${slot.label} can have inches '
        'added or taken off, and be halved or doubled -- not be multiplied '
        'or divided by a measurement.',
      );
    }

    final List<FormulaNumber> numbers = FormulaRoles.numbersInOrder(expression);
    for (final FormulaNumber n in numbers) {
      final bool isLength = roles[n] == NumberRole.length;
      final bool isMarked = parser.lengths.containsKey(n);
      final String written = parser.written[n] ?? n.toString();
      if (isLength && !isMarked) {
        return InchReading._refused(
          '"$written" needs its marks: $written\'\' for inches, or '
          '$written\'\'\' for suter.',
        );
      }
      if (!isLength && isMarked) {
        return InchReading._refused(
          '"$written" divides or multiplies, so it is a plain number '
          'with no marks -- like / 2.',
        );
      }
    }

    // Each length, in order, read back to the exact value it stood for if
    // it is one the formula already had at that mark.
    final List<FormulaNumber> lengths =
        numbers.where(parser.lengths.containsKey).toList(growable: false);
    final List<_Reference?> matched = _match(
      lengths.map((FormulaNumber n) => parser.lengths[n]!).toList(),
    );
    final Map<FormulaNumber, int> order = Map<FormulaNumber, int>.identity();
    for (int i = 0; i < lengths.length; i++) {
      order[lengths[i]] = i;
    }

    final FormulaExpression inUnit = _mapNumbers(expression, (FormulaNumber n) {
      final int? i = order[n];
      if (i == null) return n;
      final _Reference? same = matched[i];
      return FormulaNumber(same?.exact ?? unit.valueOf(parser.lengths[n]!));
    });

    final FormulaEdit edit = slot.readDisplayExpression(inUnit);
    if (!edit.isUsable) return InchReading._(edit, null);

    final List<InchPart> parts = _write(
      expression,
      label: slot.label,
      number: (FormulaNumber n) {
        final int? i = order[n];
        if (i == null) return InchWords(n.toString());
        final _Reference? same = matched[i];
        return InchLengthPart(
          i,
          parser.lengths[n]!,
          approximate: same?.approximate ?? false,
          kept: same?.exact,
        );
      },
    );
    return InchReading._(edit, parts);
  }

  /// [typed] with its length number [index] set to [to], written out the one
  /// way the app writes a formula. [typed] as it was when it cannot be read.
  String replaceLength(String typed, int index, InchLength to) {
    final List<InchPart>? parts = read(typed).parts;
    if (parts == null) return typed;
    return parts
        .map(
          (InchPart p) =>
              p is InchLengthPart && p.index == index ? to.text : p.text,
        )
        .join();
  }

  /// Which of the formula's own lengths each typed length is, if any.
  ///
  /// By position first -- the third number left at its mark is the third
  /// number as it was -- and then by value, so a number that moved because
  /// another was put in front of it is still recognised. Each of the
  /// formula's own lengths is used once.
  List<_Reference?> _match(List<InchLength> typed) {
    final List<bool> used = List<bool>.filled(_reference.length, false);
    final List<_Reference?> found =
        List<_Reference?>.filled(typed.length, null);
    for (int i = 0; i < typed.length && i < _reference.length; i++) {
      if (_reference[i].nearest == typed[i]) {
        found[i] = _reference[i];
        used[i] = true;
      }
    }
    for (int i = 0; i < typed.length; i++) {
      if (found[i] != null) continue;
      for (int j = 0; j < _reference.length; j++) {
        if (!used[j] && _reference[j].nearest == typed[i]) {
          found[i] = _reference[j];
          used[j] = true;
          break;
        }
      }
    }
    return found;
  }
}

/// One of the formula's own lengths, as stored and as shown.
class _Reference {
  const _Reference(this.exact, this.nearest, this.approximate);

  /// As stored, in the formula's unit.
  final double exact;

  /// The nearest half-suter mark.
  final InchLength nearest;

  /// Whether [nearest] is not quite [exact].
  final bool approximate;
}

/// [e] written out piece by piece, bracketed only where brackets change the
/// answer -- the same way [FormulaExpression.toString] writes it, so a
/// formula reads the same in inches as in centimetres apart from its numbers.
List<InchPart> _write(
  FormulaExpression e, {
  required String label,
  required InchPart Function(FormulaNumber) number,
}) {
  final List<InchPart> out = <InchPart>[];

  void words(String text) {
    if (out.isNotEmpty && out.last is InchWords) {
      out[out.length - 1] = InchWords(out.last.text + text);
    } else {
      out.add(InchWords(text));
    }
  }

  int precedence(String op) => (op == '+' || op == '-') ? 1 : 2;

  late void Function(FormulaExpression) emit;

  void wrapped(FormulaExpression part, bool brackets) {
    if (brackets) words('(');
    emit(part);
    if (brackets) words(')');
  }

  emit = (FormulaExpression node) {
    switch (node) {
      case FormulaNumber():
        final InchPart part = number(node);
        if (part is InchWords) {
          words(part.text);
        } else {
          out.add(part);
        }
      case FormulaVariable(:final String name):
        if (name == label) {
          out.add(InchMeasurement(label));
        } else {
          words(name);
        }
      case FormulaNegate(:final FormulaExpression operand):
        words('-');
        wrapped(operand, operand is FormulaBinary);
      case FormulaBinary(
          :final String op,
          :final FormulaExpression left,
          :final FormulaExpression right,
        ):
        final int mine = precedence(op);
        // As FormulaBinary.toString: the left only when it binds looser, the
        // right for equal precedence too, because a - (b - c) is not a - b - c.
        wrapped(left, left is FormulaBinary && precedence(left.op) < mine);
        words(' $op ');
        wrapped(right, right is FormulaBinary && precedence(right.op) <= mine);
    }
  };

  emit(e);
  return out;
}

/// [e] with every number put through [f].
FormulaExpression _mapNumbers(
  FormulaExpression e,
  FormulaExpression Function(FormulaNumber) f,
) {
  return switch (e) {
    FormulaNumber() => f(e),
    FormulaVariable() => e,
    FormulaNegate(:final FormulaExpression operand) =>
      FormulaNegate(_mapNumbers(operand, f)),
    FormulaBinary(
      :final String op,
      :final FormulaExpression left,
      :final FormulaExpression right,
    ) =>
      FormulaBinary(op, _mapNumbers(left, f), _mapNumbers(right, f)),
  };
}

// ---------------------------------------------------------------------------
// Reading a formula typed in inches
// ---------------------------------------------------------------------------

/// A length said in a message, its inch and suter held together so the line
/// never breaks between them. Only for what is read, never for what is typed:
/// the parser does not take the joining space as a space.
String _held(String length) => length.replaceAll(' ', '\u00A0');

/// How deeply brackets may nest, as for a formula in centimetres.
const int _maxDepth = 64;

/// Reads a formula with its lengths written on the tape: `HL - 1'' 5'''`.
///
/// The same small language as [FormulaExpression.parse] -- numbers, the
/// piece's name, four operators and brackets -- with one addition: a number
/// followed by two marks is inches and by three is suter, and an inch and its
/// suter written together, `1'' 5'''`, are one length. Whether each number
/// was given its marks is kept, so it can be held against where it stands:
/// a length has to say which unit it is, and a count must not.
class _InchParser {
  _InchParser(this.source);

  final String source;
  int _pos = 0;
  int _depth = 0;

  /// Every number written with marks, and the length it says.
  final Map<FormulaNumber, InchLength> lengths =
      Map<FormulaNumber, InchLength>.identity();

  /// Every number as it was typed, for saying which one is wrong.
  final Map<FormulaNumber, String> written =
      Map<FormulaNumber, String>.identity();

  FormulaExpression parseWhole() {
    if (source.trim().isEmpty) {
      throw const FormulaError('This formula is empty.', offset: 0);
    }
    final FormulaExpression result = _parseSum();
    _skipSpace();
    if (_pos < source.length) throw _leftoverError();
    return result;
  }

  FormulaError _leftoverError() {
    final String ch = source[_pos];
    if (ch == ')') {
      return FormulaError(
        'There is a closing bracket here with nothing opening it.',
        offset: _pos,
        length: 1,
      );
    }
    if (ch == "'") {
      return FormulaError(
        "A mark goes straight after its number: 6'' or 3'''.",
        offset: _pos,
        length: 1,
      );
    }
    if (!_isDigit(ch) &&
        !_isLetter(ch) &&
        ch != '_' &&
        ch != '(' &&
        ch != '.' &&
        ch != SuterHalf.mark) {
      return FormulaError(
        '"$ch" is not something a formula can contain.',
        offset: _pos,
        length: 1,
      );
    }
    final String rest = source.substring(_pos);
    return FormulaError(
      'There is no + - * or / joining "$rest" to what comes before it.',
      offset: _pos,
      length: rest.length,
    );
  }

  FormulaExpression _parseSum() {
    FormulaExpression left = _parseProduct();
    while (true) {
      _skipSpace();
      final String? op = _peekOneOf(const <String>['+', '-']);
      if (op == null) return left;
      _pos++;
      left = FormulaBinary(op, left, _parseProduct());
    }
  }

  FormulaExpression _parseProduct() {
    FormulaExpression left = _parseUnary();
    while (true) {
      _skipSpace();
      final String? op = _peekOneOf(const <String>['*', '/']);
      if (op == null) return left;
      _pos++;
      left = FormulaBinary(op, left, _parseUnary());
    }
  }

  FormulaExpression _parseUnary() {
    _skipSpace();
    if (_peekOneOf(const <String>['-']) != null) {
      _pos++;
      return FormulaNegate(_parseUnary());
    }
    if (_peekOneOf(const <String>['+']) != null) {
      _pos++;
      return _parseUnary();
    }
    return _parseAtom();
  }

  FormulaExpression _parseAtom() {
    _skipSpace();
    if (_pos >= source.length) {
      throw FormulaError(
        'The formula stops before it says what to do here.',
        offset: source.length,
      );
    }

    final String ch = source[_pos];

    if (ch == '(') {
      if (++_depth > _maxDepth) {
        throw FormulaError(
          'There are too many brackets here for Quick AL to follow.',
          offset: _pos,
        );
      }
      final int open = _pos;
      _pos++;
      final FormulaExpression inner = _parseSum();
      _skipSpace();
      if (_pos >= source.length || source[_pos] != ')') {
        throw FormulaError(
          'This bracket is opened but never closed.',
          offset: open,
          length: 1,
        );
      }
      _pos++;
      _depth--;
      return inner;
    }

    if (ch == ')') {
      throw FormulaError(
        'There is a closing bracket here with nothing opening it.',
        offset: _pos,
        length: 1,
      );
    }

    if (ch == "'") {
      throw FormulaError(
        "A mark needs a number in front of it: 6'' or 3'''.",
        offset: _pos,
        length: 1,
      );
    }

    if (_isDigit(ch) || ch == '.' || ch == SuterHalf.mark) {
      return _parseNumberOrLength();
    }
    if (_isLetter(ch) || ch == '_') return _parseVariable();

    throw FormulaError(
      '"$ch" is not something a formula can contain.',
      offset: _pos,
      length: 1,
    );
  }

  /// A plain number, or a length with its marks.
  FormulaExpression _parseNumberOrLength() {
    final int start = _pos;
    final String number = _readNumber();
    final (int marks, int afterMarks) = _marksFrom(_pos);

    if (marks == 0) {
      if (number.contains(SuterHalf.mark)) {
        throw FormulaError(
          '"$number" -- ½ is half a suter, so it takes the suter marks: '
          "$number'''.",
          offset: start,
          length: number.length,
        );
      }
      final double? value = double.tryParse(number);
      if (value == null || !value.isFinite) {
        throw FormulaError(
          '"$number" is not a number Quick AL can use.',
          offset: start,
          length: number.length,
        );
      }
      final FormulaNumber node = FormulaNumber(value);
      written[node] = number;
      return node;
    }

    if (marks == 1) {
      throw FormulaError(
        "\"$number'\" -- one mark is feet. Inches take two marks and suter "
        "three: $number'' or $number'''.",
        offset: start,
        length: afterMarks - start,
      );
    }
    if (marks > 3) {
      throw FormulaError(
        "Too many marks after $number: two for inches ($number''), three "
        "for suter ($number''').",
        offset: start,
        length: afterMarks - start,
      );
    }

    int sixteenths;
    if (marks == 3) {
      _pos = afterMarks;
      sixteenths = _suterMarks(number, start);
    } else {
      _pos = afterMarks;
      sixteenths = _inchMarks(number, start) * 16;

      // The suter that goes with it, if one follows: `1'' 5'''` is one
      // length, said the way the tape is read.
      final int resume = _pos;
      _skipSpace();
      if (_pos < source.length &&
          (_isDigit(source[_pos]) || source[_pos] == SuterHalf.mark)) {
        final int suterStart = _pos;
        final String suter = _readNumber();
        final (int suterMarks, int afterSuter) = _marksFrom(_pos);
        if (suterMarks == 3) {
          _pos = afterSuter;
          sixteenths += _suterMarks(suter, suterStart);
        } else {
          throw FormulaError(
            "After $number'' comes the suter, with three marks: "
            '${_held("$number'' $suter'''")}.',
            offset: suterStart,
            length: afterSuter - suterStart,
          );
        }
      } else {
        _pos = resume;
      }
    }

    final FormulaNumber node = FormulaNumber(sixteenths / 16);
    lengths[node] = InchLength(sixteenths);
    written[node] = source.substring(start, _pos).trim();
    return node;
  }

  /// Whole inches, from a number written with two marks.
  int _inchMarks(String number, int start) {
    final int? inches =
        RegExp(r'^\d+$').hasMatch(number) ? int.tryParse(number) : null;
    if (inches != null && inches <= 100000) return inches;

    // A half inch, or 1.25'', is a real length -- just not one written the
    // way the tape is read. Say how it is written, when it is a mark at all.
    final double? asked = double.tryParse(SuterHalf.toDecimal(number));
    final String suggestion = asked != null &&
            asked.isFinite &&
            asked >= 0 &&
            asked < 100000 &&
            ((asked * 16) - (asked * 16).roundToDouble()).abs() < 1e-9
        ? ' Write ${_held(InchLength((asked * 16).round()).text)}.'
        : '';
    throw FormulaError(
      "\"$number''\" -- inches are whole, and the rest is suter.$suggestion",
      offset: start,
      length: _pos - start,
    );
  }

  /// Suter in sixteenths of an inch, from a number written with three marks.
  int _suterMarks(String number, int start) {
    final double? suter = SuterHalf.parse(number);
    if (suter == null || !suter.isFinite || suter < 0) {
      throw FormulaError(
        '"$number" is not a number Quick AL can use.',
        offset: start,
        length: number.length,
      );
    }
    final double halves = suter * 2;
    if ((halves - halves.roundToDouble()).abs() > 1e-9) {
      final int whole = suter.floor();
      throw FormulaError(
        "\"$number'''\" -- suter goes in halves: $whole''' or "
        "$whole${SuterHalf.mark}'''.",
        offset: start,
        length: _pos - start,
      );
    }
    if (suter >= 8) {
      final String asLength = suter < 100000
          ? ' Write ${_held(InchLength(halves.round()).text)}.'
          : '';
      throw FormulaError(
        "\"$number'''\" -- suter runs 0 to 7${SuterHalf.mark}; eight suter "
        'is the next inch.$asLength',
        offset: start,
        length: _pos - start,
      );
    }
    return halves.round();
  }

  /// Digits, a point and more digits, and a ½ at the end.
  String _readNumber() {
    final int start = _pos;
    while (_pos < source.length && _isDigit(source[_pos])) {
      _pos++;
    }
    if (_pos < source.length && source[_pos] == '.') {
      _pos++;
      while (_pos < source.length && _isDigit(source[_pos])) {
        _pos++;
      }
    }
    if (_pos < source.length && source[_pos] == SuterHalf.mark) _pos++;
    return source.substring(start, _pos);
  }

  /// How many marks follow [from], spaces allowed before them, and where
  /// they end. No marks: the end is [from] itself.
  (int, int) _marksFrom(int from) {
    int at = from;
    while (at < source.length && source[at] == ' ') {
      at++;
    }
    int marks = 0;
    while (at + marks < source.length && source[at + marks] == "'") {
      marks++;
    }
    return marks == 0 ? (0, from) : (marks, at + marks);
  }

  FormulaExpression _parseVariable() {
    final int start = _pos;
    while (_pos < source.length &&
        (_isLetter(source[_pos]) ||
            _isDigit(source[_pos]) ||
            source[_pos] == '_')) {
      _pos++;
    }
    return FormulaVariable(source.substring(start, _pos));
  }

  void _skipSpace() {
    while (_pos < source.length) {
      final int code = source.codeUnitAt(_pos);
      if (code == 0x20 || code == 0x09 || code == 0x0A || code == 0x0D) {
        _pos++;
        continue;
      }
      break;
    }
  }

  String? _peekOneOf(List<String> options) {
    if (_pos >= source.length) return null;
    final String ch = source[_pos];
    return options.contains(ch) ? ch : null;
  }

  static bool _isDigit(String ch) {
    final int c = ch.codeUnitAt(0);
    return c >= 0x30 && c <= 0x39;
  }

  static bool _isLetter(String ch) {
    final int c = ch.codeUnitAt(0);
    return (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);
  }
}
