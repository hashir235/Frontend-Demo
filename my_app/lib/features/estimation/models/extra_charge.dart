import 'package:flutter/foundation.dart';

/// One extra charge on a bill, and what it is for.
///
/// A shop adds things to a bill that no window accounts for -- transport,
/// extra silicon, a length of glass or section the job turned out to need --
/// and the customer asks what each one is (Hashir, Oct 2026). So an extra
/// charge is a line of its own with what it is for, not one lump; the bill's
/// Extra Charges total is these added up.
@immutable
class ExtraCharge {
  /// What the money is for. May be empty: the line then reads as "Extra
  /// Charges" on the screen and "Other Charges" on the PDF, as the single
  /// figure always did.
  final String description;
  final double amount;

  const ExtraCharge({required this.description, required this.amount});

  /// The longest description a line takes; the PDF wraps anything under it.
  static const int maxDescriptionLength = 80;

  /// The most lines one bill carries.
  static const int maxLines = 20;

  /// What this line is called on the bill: its description, or [fallback]
  /// when none was given.
  String labelOr(String fallback) {
    final String text = description.trim();
    return text.isEmpty ? fallback : text;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'description': description.trim(),
    'amount': amount,
  };

  /// The lines a bill came back with. Anything that is not a line with an
  /// amount is left out: a line of nothing is not a charge.
  static List<ExtraCharge> listFromJson(Object? raw) {
    if (raw is! List) return const <ExtraCharge>[];
    final List<ExtraCharge> out = <ExtraCharge>[];
    for (final Object? item in raw) {
      if (item is! Map) continue;
      final Object? amount = item['amount'];
      final double value = amount is num
          ? amount.toDouble()
          : double.tryParse('$amount') ?? 0;
      if (!value.isFinite || value <= 0) continue;
      out.add(
        ExtraCharge(
          description: (item['description'] ?? '').toString().trim(),
          amount: value,
        ),
      );
    }
    return out;
  }

  /// What [lines] come to: the bill's Extra Charges.
  static double totalOf(Iterable<ExtraCharge> lines) =>
      lines.fold<double>(0, (double sum, ExtraCharge line) => sum + line.amount);

  @override
  bool operator ==(Object other) =>
      other is ExtraCharge &&
      other.description == description &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(description, amount);

  @override
  String toString() => 'ExtraCharge($description, $amount)';
}
