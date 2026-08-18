/// The one place the support number is written down.
///
/// It appears in more than one corner of the app -- payment instructions, and
/// now the notice a user gets when their city has no rate list yet. A number
/// typed out twice is a number that eventually differs, and the half that is
/// wrong sends people nowhere.
class SupportContact {
  const SupportContact._();

  /// Shown to people. Full international form so it works from any phone,
  /// including one roaming abroad.
  static const String whatsApp = '+92 329 7590468';

  /// How Pakistanis actually dial it at home, which is how it should read on a
  /// message telling someone to ring the office.
  static const String local = '0329 7590468';

  /// wa.me wants digits only -- no plus, no spaces.
  static const String whatsAppUrl = 'https://wa.me/923297590468';
}
