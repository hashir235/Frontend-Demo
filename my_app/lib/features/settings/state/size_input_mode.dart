/// How the sub-part of a size (inch in feet mode, suter in inches mode) is
/// entered on the estimation and fabrication input pages.
///
/// Kuch log tape-style wheel pasand karte hain, kuch seedha number likhna —
/// is liye dono option settings se available hain.
enum SizeInputMode {
  /// Tape-style wheel (default).
  wheel,

  /// Plain text box, value keyboard se likhi jati ha.
  keypad,
}
