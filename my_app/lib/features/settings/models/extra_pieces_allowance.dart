/// How many leftover ("offcut") bars a cutting plan is allowed to end up with.
///
/// `*` means the system decides for itself and may make as many as it takes.
/// That is the default, and almost always the right answer: full lengths are
/// always tried first, so leftovers only ever appear when nothing else fits.
/// A number pins it instead -- 1 being the classic "one extra piece at most" --
/// and the optimizer then refuses any plan that needs more.
class ExtraPiecesAllowance {
  static const String unlimitedText = '*';

  /// `null` means unlimited.
  final int? limit;

  const ExtraPiecesAllowance(this.limit);

  const ExtraPiecesAllowance.unlimited() : limit = null;

  /// Storage keeps this as a number plus a flag, because that is what the
  /// engine rules file has always carried. A cleared flag means unlimited,
  /// whatever number sits beside it.
  factory ExtraPiecesAllowance.fromSettings({
    required int maxExtraPieces,
    required bool enforce,
  }) {
    return enforce
        ? ExtraPiecesAllowance(maxExtraPieces)
        : const ExtraPiecesAllowance.unlimited();
  }

  /// Returns null when the text is neither `*` nor a whole number of pieces.
  static ExtraPiecesAllowance? tryParse(String raw) {
    final String text = raw.trim();
    if (text == unlimitedText) {
      return const ExtraPiecesAllowance.unlimited();
    }
    final int? value = int.tryParse(text);
    if (value == null || value < 0) {
      return null;
    }
    return ExtraPiecesAllowance(value);
  }

  bool get isUnlimited => limit == null;

  bool get enforce => !isUnlimited;

  String get text => isUnlimited ? unlimitedText : '$limit';

  /// The number written to storage. Unlimited still stores 1 so that turning
  /// the limit back on later starts from the familiar default.
  int get storedLimit => limit ?? 1;
}
