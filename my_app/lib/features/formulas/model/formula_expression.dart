/// Arithmetic the way a fabricator writes it on paper.
///
/// Every cut length in Quick AL comes from a short sum over the window's own
/// measurements -- `((h + 6) + cm) / feet` and its like. Those sums used to
/// live inside the engine where only we could read them, and every workshop
/// that measures differently had to take ours on trust. Here they are text a
/// person can read, change, and hand back.
///
/// The language is deliberately small: numbers, named measurements, the four
/// operators and brackets. Nothing here can loop, call out, or reach anything
/// but the numbers it was handed, because a formula is read by a saw operator
/// with metal already bought and the only useful answer is a length.
library;

import 'dart:math' as math;

/// Something the person typing can be told, and can act on.
///
/// Carries where in the text it happened so the editor can put the caret
/// there: being told "unexpected )" without being shown which one is barely
/// better than being told nothing.
class FormulaError implements Exception {
  const FormulaError(this.message, {this.offset, this.length = 0});

  /// Said to a fabricator, not a programmer. "d is not a measurement you can
  /// use here", never "undefined identifier".
  final String message;

  /// Where in the formula text the trouble is, if it can be pinned down.
  final int? offset;

  /// How much of the text the trouble covers, for underlining it.
  final int length;

  @override
  String toString() => message;
}

/// A parsed formula, ready to be evaluated as often as needed.
///
/// Parsing is done once when the formula is saved; a project with three
/// hundred windows evaluates the same handful of formulas over and over, and
/// re-reading the text each time would be work done for nothing.
sealed class FormulaExpression {
  const FormulaExpression();

  /// Reads [source] as a formula.
  ///
  /// Throws [FormulaError] with the position of the trouble if it cannot be
  /// read. It never returns a half-understood formula: a length that is
  /// almost right is worse than one that refuses to be saved.
  static FormulaExpression parse(String source) => _Parser(source).parseWhole();

  /// Reads [source], or returns null rather than throwing.
  ///
  /// For the places that are only asking "would this parse?" -- live
  /// validation as someone types, where a throw on every half-typed formula
  /// would be noise.
  static FormulaExpression? tryParse(String source) {
    try {
      return parse(source);
    } on FormulaError {
      return null;
    }
  }

  /// Works out the number, given what each measurement stands for.
  ///
  /// Throws [FormulaError] if the formula names something [variables] does not
  /// hold, or if it divides by zero.
  double evaluate(Map<String, double> variables);

  /// Every measurement this formula reads, in the order it first names them.
  ///
  /// The editor uses it to show which of the window's numbers a formula
  /// actually depends on, and the catalogue check uses it to be sure no
  /// formula quietly reads something the window cannot supply.
  Set<String> get variables {
    final Set<String> found = <String>{};
    _collectVariables(found);
    return found;
  }

  void _collectVariables(Set<String> into);

  /// The formula written back out, bracketed only where the brackets change
  /// the answer.
  ///
  /// What someone typed is kept as they typed it; this is for formulas built
  /// or rewritten by the app, so they read like something a person wrote
  /// rather than a tree that has been flattened.
  @override
  String toString();
}

/// A plain number.
class FormulaNumber extends FormulaExpression {
  const FormulaNumber(this.value);

  final double value;

  @override
  double evaluate(Map<String, double> variables) => value;

  @override
  void _collectVariables(Set<String> into) {}

  @override
  String toString() {
    // 6 rather than 6.0, but 4.2 keeps its tail. A formula reads as arithmetic,
    // and arithmetic on paper does not carry a trailing zero.
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toStringAsFixed(0);
    }
    return value.toString();
  }
}

/// One of the window's measurements, by name.
class FormulaVariable extends FormulaExpression {
  const FormulaVariable(this.name);

  final String name;

  @override
  double evaluate(Map<String, double> variables) {
    final double? value = variables[name];
    if (value == null) {
      throw FormulaError('$name is not a measurement this window has.');
    }
    return value;
  }

  @override
  void _collectVariables(Set<String> into) => into.add(name);

  @override
  String toString() => name;
}

/// Arithmetic between two parts.
class FormulaBinary extends FormulaExpression {
  const FormulaBinary(this.op, this.left, this.right);

  /// One of `+`, `-`, `*`, `/`.
  final String op;
  final FormulaExpression left;
  final FormulaExpression right;

  @override
  double evaluate(Map<String, double> variables) {
    final double a = left.evaluate(variables);
    final double b = right.evaluate(variables);
    switch (op) {
      case '+':
        return a + b;
      case '-':
        return a - b;
      case '*':
        return a * b;
      case '/':
        if (b == 0) {
          throw const FormulaError('This formula divides by zero.');
        }
        return a / b;
    }
    throw FormulaError('$op is not something this formula can do.');
  }

  @override
  void _collectVariables(Set<String> into) {
    left._collectVariables(into);
    right._collectVariables(into);
  }

  @override
  String toString() {
    final int mine = _precedenceOf(op);
    // The left side only needs brackets when it binds looser than we do.
    // The right side needs them for equal precedence too, because a - (b - c)
    // is not a - b - c.
    final String l = _wrap(left, mine, strict: false);
    final String r = _wrap(right, mine, strict: true);
    return '$l $op $r';
  }

  static String _wrap(FormulaExpression part, int outer, {required bool strict}) {
    if (part is! FormulaBinary) return part.toString();
    final int inner = _precedenceOf(part.op);
    final bool needs = inner < outer || (strict && inner == outer);
    return needs ? '(${part.toString()})' : part.toString();
  }
}

/// A leading minus, as in `-4.2 + h`.
class FormulaNegate extends FormulaExpression {
  const FormulaNegate(this.operand);

  final FormulaExpression operand;

  @override
  double evaluate(Map<String, double> variables) => -operand.evaluate(variables);

  @override
  void _collectVariables(Set<String> into) => operand._collectVariables(into);

  @override
  String toString() {
    if (operand is FormulaBinary) return '-(${operand.toString()})';
    return '-${operand.toString()}';
  }
}

int _precedenceOf(String op) => (op == '+' || op == '-') ? 1 : 2;

// ---------------------------------------------------------------------------
// Reading the text
// ---------------------------------------------------------------------------

/// How deeply brackets may nest.
///
/// Real formulas reach five or six; anything past this is a runaway paste
/// rather than arithmetic, and refusing it keeps a bad formula from taking the
/// parser down with it.
const int _maxDepth = 64;

class _Parser {
  _Parser(this.source);

  final String source;
  int _pos = 0;
  int _depth = 0;

  FormulaExpression parseWhole() {
    if (source.trim().isEmpty) {
      throw const FormulaError('This formula is empty.', offset: 0);
    }
    final FormulaExpression result = _parseSum();
    _skipSpace();
    if (_pos < source.length) {
      // The sum ended but the text did not. What is left over says why far
      // better than the leftovers themselves do: a stray ")" is a bracket
      // problem and "^" is an operator this language does not have, and
      // telling someone only that the tail "could not be read" leaves them to
      // work out which.
      throw _leftoverError();
    }
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
    if (!_isDigit(ch) && !_isLetter(ch) && ch != '_' && ch != '(' && ch != '.') {
      return FormulaError(
        '"$ch" is not something a formula can contain.',
        offset: _pos,
        length: 1,
      );
    }
    // Something readable, just with no operator joining it on -- "h 6", or a
    // measurement written next to a bracket.
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
    // A written-out plus, as in "+6", means the number as it stands.
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

    if (_isDigit(ch) || ch == '.') return _parseNumber();
    if (_isLetter(ch) || ch == '_') return _parseVariable();

    throw FormulaError(
      '"$ch" is not something a formula can contain.',
      offset: _pos,
      length: 1,
    );
  }

  FormulaExpression _parseNumber() {
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
    final String text = source.substring(start, _pos);
    final double? value = double.tryParse(text);
    if (value == null || !value.isFinite) {
      throw FormulaError(
        '"$text" is not a number Quick AL can use.',
        offset: start,
        length: text.length,
      );
    }
    return FormulaNumber(value);
  }

  FormulaExpression _parseVariable() {
    final int start = _pos;
    while (_pos < source.length &&
        (_isLetter(source[_pos]) || _isDigit(source[_pos]) || source[_pos] == '_')) {
      _pos++;
    }
    return FormulaVariable(source.substring(start, _pos));
  }

  void _skipSpace() {
    while (_pos < source.length) {
      final int code = source.codeUnitAt(_pos);
      // Space, tab, newline, carriage return.
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

// ---------------------------------------------------------------------------
// Checking a formula before it is trusted
// ---------------------------------------------------------------------------

/// What a formula was found to be, before anyone cuts to it.
class FormulaCheck {
  const FormulaCheck._(this.expression, this.error, this.unknownVariables);

  /// The formula, if it could be read at all.
  final FormulaExpression? expression;

  /// Why it cannot be used, if it cannot.
  final FormulaError? error;

  /// Measurements it names that this window does not have.
  final List<String> unknownVariables;

  bool get isUsable => error == null && unknownVariables.isEmpty;

  /// Reads [source] and holds it against the measurements a window can offer.
  ///
  /// Both halves matter and neither implies the other: `h + ` will not parse,
  /// and `d + 6` parses perfectly while naming a measurement that does not
  /// exist. Either one would reach the saw as a wrong length.
  static FormulaCheck of(String source, {required Set<String> allowedVariables}) {
    final FormulaExpression parsed;
    try {
      parsed = FormulaExpression.parse(source);
    } on FormulaError catch (error) {
      return FormulaCheck._(null, error, const <String>[]);
    }

    final List<String> unknown = parsed.variables
        .where((String name) => !allowedVariables.contains(name))
        .toList(growable: false);

    return FormulaCheck._(parsed, null, unknown);
  }

  /// One sentence naming what is wrong, or null when nothing is.
  String? get problem {
    if (error != null) return error!.message;
    if (unknownVariables.isEmpty) return null;
    if (unknownVariables.length == 1) {
      return '${unknownVariables.first} is not a measurement this window has.';
    }
    final String list = unknownVariables.join(', ');
    return '$list are not measurements this window has.';
  }
}

/// A length that came out of a formula, and whether it can be cut.
///
/// A formula can be perfectly well written and still produce something no saw
/// can make -- a negative length from a window smaller than the deduction, or
/// a number so large it can only be a slipped decimal point. Those are caught
/// here rather than at the saw.
class FormulaResult {
  const FormulaResult._(this.value, this.problem);

  /// The length, in whatever unit the formula works in.
  final double? value;

  /// Why the length cannot be used, if it cannot.
  final String? problem;

  bool get isUsable => problem == null;

  /// No aluminium section in the trade comes near this. A formula reaching it
  /// has a misplaced decimal point or a measurement in the wrong unit.
  static const double _implausibleFeet = 1000;

  static FormulaResult of(
    FormulaExpression expression,
    Map<String, double> variables, {
    required String label,
  }) {
    final double value;
    try {
      value = expression.evaluate(variables);
    } on FormulaError catch (error) {
      return FormulaResult._(null, error.message);
    }

    if (value.isNaN) {
      return FormulaResult._(null, '$label does not work out to a number.');
    }
    if (!value.isFinite) {
      return FormulaResult._(null, '$label works out too large to cut.');
    }
    if (value <= 0) {
      return FormulaResult._(
        null,
        '$label works out to ${value.toStringAsFixed(2)} -- a piece has to be longer than nothing.',
      );
    }
    if (value > _implausibleFeet) {
      return FormulaResult._(
        null,
        '$label works out to ${value.toStringAsFixed(1)}ft, which is longer than any stock length.',
      );
    }
    return FormulaResult._(value, null);
  }

  /// Rounded the way the engine rounds, so a length worked out in the app and
  /// the same length worked out on the server agree to the last digit that
  /// matters. The optimizer counts in thousandths of a foot; anything finer
  /// than that is noise either way.
  double? get asCutLength {
    final double? raw = value;
    if (raw == null) return null;
    return (raw * 1000).roundToDouble() / 1000;
  }

  static final double _epsilon = math.pow(2, -40).toDouble();

  /// Whether two lengths are the same to the precision anyone can cut to.
  static bool sameLength(double a, double b) => (a - b).abs() <= _epsilon * math.max(1, a.abs());
}
