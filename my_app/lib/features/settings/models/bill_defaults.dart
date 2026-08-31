/// The glass a workshop actually fits, as it is asked for at the counter.
///
/// "Mercury" is the mirrored back; "Simple" is plain tinted. They are priced
/// differently, so they are separate entries rather than one colour with a
/// note.
class GlassTypes {
  const GlassTypes._();

  static const List<String> all = <String>[
    'Clear Glass',
    'Green Mercury',
    'Green Simple',
    'Brown Mercury',
    'Brown Simple',
    'Blue Mercury',
    'Blue Simple',
    'Gray Mercury',
    'Gray Simple',
    'Ocean Blue',
  ];

  /// Matches a glass name the user typed on a bill against this list, ignoring
  /// case and spacing, so "green mercury" finds its saved rate.
  static String? match(String typed) {
    final String needle = typed.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    if (needle.isEmpty) return null;
    for (final String type in all) {
      if (type.toLowerCase() == needle) return type;
    }
    return null;
  }
}

/// Rates a user would otherwise retype on every bill.
///
/// Held as the strings that were typed, never as numbers. A blank labour rate
/// has to arrive at the bill as an empty box for someone to fill in — turning
/// it into 0 on the way would price the labour on that job at nothing, and the
/// bill would look perfectly normal.
class BillDefaults {
  final String labourRate;
  final String hardwareRate;
  final String aluminiumDiscount;

  /// Rate per glass type. A type the user has not priced is simply absent.
  final Map<String, String> glass;

  /// Hardware rate per window type, keyed by the window's name in
  /// [WindowCatalog.allTypeNames].
  ///
  /// A sliding window and an openable one do not take the same ironmongery, so
  /// a shop that prices them together is wrong on at least one of them. A type
  /// left blank here falls back to [hardwareRate], which is what every bill
  /// used before this existed.
  final Map<String, String> hardware;

  const BillDefaults({
    this.labourRate = '',
    this.hardwareRate = '',
    this.aluminiumDiscount = '',
    this.glass = const <String, String>{},
    this.hardware = const <String, String>{},
  });

  const BillDefaults.empty() : this();

  bool get isEmpty =>
      labourRate.isEmpty &&
      hardwareRate.isEmpty &&
      aluminiumDiscount.isEmpty &&
      glass.values.every((String v) => v.isEmpty) &&
      hardware.values.every((String v) => v.isEmpty);

  /// The saved rate for a glass name typed on a bill, or null when there is
  /// none — null rather than '' so callers can tell "no rate saved" from "the
  /// user deliberately cleared it".
  String? rateForGlass(String typedName) {
    final String? type = GlassTypes.match(typedName);
    if (type == null) return null;
    final String? value = glass[type];
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }

  /// The saved hardware rate for a window type, or null when there is none.
  ///
  /// Null rather than '' for the same reason as [rateForGlass]: the caller has
  /// to be able to tell "nothing saved, fall back" from "deliberately blank".
  String? rateForWindowType(String typeName) {
    final String? value = hardware[typeName];
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }

  BillDefaults copyWith({
    String? labourRate,
    String? hardwareRate,
    String? aluminiumDiscount,
    Map<String, String>? glass,
    Map<String, String>? hardware,
  }) {
    return BillDefaults(
      labourRate: labourRate ?? this.labourRate,
      hardwareRate: hardwareRate ?? this.hardwareRate,
      aluminiumDiscount: aluminiumDiscount ?? this.aluminiumDiscount,
      glass: glass ?? this.glass,
      hardware: hardware ?? this.hardware,
    );
  }

  factory BillDefaults.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> rawGlass =
        (json['glass'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final Map<String, dynamic> rawHardware =
        (json['hardware'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    return BillDefaults(
      labourRate: (json['labourRate'] as String? ?? '').trim(),
      hardwareRate: (json['hardwareRate'] as String? ?? '').trim(),
      aluminiumDiscount: (json['aluminiumDiscount'] as String? ?? '').trim(),
      glass: <String, String>{
        for (final MapEntry<String, dynamic> e in rawGlass.entries)
          e.key: '${e.value}'.trim(),
      },
      hardware: <String, String>{
        for (final MapEntry<String, dynamic> e in rawHardware.entries)
          e.key: '${e.value}'.trim(),
      },
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'labourRate': labourRate,
      'hardwareRate': hardwareRate,
      'aluminiumDiscount': aluminiumDiscount,
      'glass': glass,
      'hardware': hardware,
    };
  }
}
