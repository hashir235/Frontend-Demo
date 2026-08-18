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

  /// Plain text box, value keyboard se likhi jati ha. The default: it is the
  /// faster of the two once you know the number you want, and most people do.
  keypad,
}
