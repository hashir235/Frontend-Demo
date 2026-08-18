/// The cities Quick AL keeps rates for.
///
/// Aluminium is not one price across Pakistan -- a section costs one thing in
/// Gujrat and another in Karachi -- so a workshop's city is what decides which
/// rate list they start from. That is why this list exists here rather than as
/// free text: a typed "Lahore " or "lahor" would quietly miss its rate list.
///
/// Kept to the trading centres where aluminium and glass work actually
/// happens. Anyone whose town is not on it picks the city they buy from, which
/// is the city whose rates apply to them anyway.
class PakistanCities {
  const PakistanCities._();

  static const List<String> all = <String>[
    'Abbottabad',
    'Bahawalpur',
    'Dera Ghazi Khan',
    'Faisalabad',
    'Gujranwala',
    'Gujrat',
    'Hyderabad',
    'Islamabad',
    'Jhelum',
    'Karachi',
    'Kasur',
    'Lahore',
    'Larkana',
    'Mardan',
    'Mirpur (AJK)',
    'Multan',
    'Muzaffarabad',
    'Okara',
    'Peshawar',
    'Quetta',
    'Rahim Yar Khan',
    'Rawalpindi',
    'Sahiwal',
    'Sargodha',
    'Sheikhupura',
    'Sialkot',
    'Sukkur',
    'Wah Cantt',
  ];

  /// The city a workshop is put on until it says otherwise.
  static const String fallback = 'Gujrat';

  /// Whether a stored value is one this build still recognises.
  ///
  /// A city read back from an older install, or from a list that has since
  /// changed, must not silently become something else -- callers use this to
  /// decide whether to show it as chosen or ask again.
  static bool isKnown(String city) => all.contains(city.trim());

  /// The filename-safe form used to find a city's master rate list on the
  /// server: "Rahim Yar Khan" -> "rahim-yar-khan", "Mirpur (AJK)" -> "mirpur-ajk".
  static String slug(String city) {
    final String lower = city.trim().toLowerCase();
    final String cleaned = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return cleaned.replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
