/// How the sub-part of a size (inch in feet mode, suter in inches mode) is
/// entered — on the window pages and on glass entry alike.
///
/// Kuch log tape-style wheel pasand karte hain, kuch seedha number likhna —
/// is liye dono option settings se available hain. One setting covers both
/// kinds of entry: someone who has decided how they like typing sizes should
/// not have to decide again on a different screen.
enum SizeInputMode {
  /// Tape-style wheel.
  wheel,

  /// Plain text box, value keyboard se likhi jati ha -- inch in one box and
  /// the suter in another.
  keypad,

  /// One box for the whole size, the way cm is entered: the inch, a space,
  /// then the suter -- `23 4`, or `44 5.5` when it lands on a half.
  ///
  /// The default. Two boxes per dimension means two taps to move between them
  /// and four fields on screen for a height and a width; a fitter reading a
  /// tape says "twenty-three four" and can now type it that way.
  mergedKeypad,
}
