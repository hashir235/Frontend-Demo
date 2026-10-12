import 'cost_table.dart';
import 'extra_charge.dart';

class EstimateMaterialSelection {
  final String gaugeValue;
  final String colorValue;

  const EstimateMaterialSelection({
    required this.gaugeValue,
    required this.colorValue,
  });

  bool get isComplete =>
      gaugeValue.trim().isNotEmpty && colorValue.trim().isNotEmpty;

  EstimateMaterialSelection copyWith({String? gaugeValue, String? colorValue}) {
    return EstimateMaterialSelection(
      gaugeValue: gaugeValue ?? this.gaugeValue,
      colorValue: colorValue ?? this.colorValue,
    );
  }
}

/// One extra charge line as typed on Bill Inputs: what it is for, and the
/// amount as the box holds it.
class ExtraChargeDraft {
  final String description;
  final String amount;

  const ExtraChargeDraft({this.description = '', this.amount = ''});

  bool get isEmpty => description.trim().isEmpty && amount.trim().isEmpty;
}

class EstimateBillDraft {
  final String glassRatePerSqFt;
  final String laborRatePerSqFt;
  final String hardwareRatePerWindow;
  final String aluminiumDiscountPercent;

  /// The extra charges' total. Kept for a bill whose charges came as one
  /// figure: Bill Inputs shows it as one line when [extraChargeLines] is
  /// empty.
  final String extraCharges;

  /// The extra charges line by line, each with what it is for.
  final List<ExtraChargeDraft> extraChargeLines;

  final String advancePaid;
  final String glassColor;
  final String aluminiumCompany;
  final String customerName;
  final String customerPhone;
  final String customerAddress;

  const EstimateBillDraft({
    this.glassRatePerSqFt = '',
    this.laborRatePerSqFt = '',
    this.hardwareRatePerWindow = '',
    this.aluminiumDiscountPercent = '',
    this.extraCharges = '',
    this.extraChargeLines = const <ExtraChargeDraft>[],
    this.advancePaid = '',
    this.glassColor = '',
    this.aluminiumCompany = '',
    this.customerName = '',
    this.customerPhone = '',
    this.customerAddress = '',
  });

  bool get hasAnyValue =>
      glassRatePerSqFt.trim().isNotEmpty ||
      laborRatePerSqFt.trim().isNotEmpty ||
      hardwareRatePerWindow.trim().isNotEmpty ||
      aluminiumDiscountPercent.trim().isNotEmpty ||
      extraCharges.trim().isNotEmpty ||
      extraChargeLines.any((ExtraChargeDraft line) => !line.isEmpty) ||
      advancePaid.trim().isNotEmpty ||
      glassColor.trim().isNotEmpty ||
      aluminiumCompany.trim().isNotEmpty ||
      customerName.trim().isNotEmpty ||
      customerPhone.trim().isNotEmpty ||
      customerAddress.trim().isNotEmpty;

  EstimateBillDraft copyWith({
    String? glassRatePerSqFt,
    String? laborRatePerSqFt,
    String? hardwareRatePerWindow,
    String? aluminiumDiscountPercent,
    String? extraCharges,
    List<ExtraChargeDraft>? extraChargeLines,
    String? advancePaid,
    String? glassColor,
    String? aluminiumCompany,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
  }) {
    return EstimateBillDraft(
      glassRatePerSqFt: glassRatePerSqFt ?? this.glassRatePerSqFt,
      laborRatePerSqFt: laborRatePerSqFt ?? this.laborRatePerSqFt,
      hardwareRatePerWindow:
          hardwareRatePerWindow ?? this.hardwareRatePerWindow,
      aluminiumDiscountPercent:
          aluminiumDiscountPercent ?? this.aluminiumDiscountPercent,
      extraCharges: extraCharges ?? this.extraCharges,
      extraChargeLines: extraChargeLines ?? this.extraChargeLines,
      advancePaid: advancePaid ?? this.advancePaid,
      glassColor: glassColor ?? this.glassColor,
      aluminiumCompany: aluminiumCompany ?? this.aluminiumCompany,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
    );
  }
}

EstimateMaterialSelection? estimateMaterialSelectionFromProjectOutputs(
  Map<String, dynamic>? outputs,
) {
  final Map<String, dynamic>? costTable = _asMap(outputs?['costTable']);
  final Map<String, dynamic>? rateReview = _asMap(outputs?['rateReview']);
  final Map<String, dynamic>? billResult = _asMap(outputs?['billResult']);

  final Map<String, dynamic>? preferredRequest =
      _asMap(costTable?['request']) ?? _asMap(rateReview?['request']);
  final String requestGauge = _normalizeString(preferredRequest?['gauge']);
  final String requestColor = _normalizeString(preferredRequest?['color']);
  if (requestGauge.isNotEmpty || requestColor.isNotEmpty) {
    return EstimateMaterialSelection(
      gaugeValue: requestGauge,
      colorValue: requestColor,
    );
  }

  final String billGauge = _normalizeString(billResult?['gauge']);
  final String billColor = _normalizeString(billResult?['aluminiumColor']);
  if (billGauge.isEmpty && billColor.isEmpty) {
    return null;
  }

  return EstimateMaterialSelection(
    gaugeValue: billGauge,
    colorValue: billColor,
  );
}

List<RateOverrideInput> estimateRateOverridesFromProjectOutputs(
  Map<String, dynamic>? outputs,
) {
  final Map<String, dynamic>? costTable = _asMap(outputs?['costTable']);
  final Map<String, dynamic>? request = _asMap(costTable?['request']);
  final List<dynamic> rawOverrides = request?['overrides'] is List<dynamic>
      ? request!['overrides'] as List<dynamic>
      : const <dynamic>[];

  return rawOverrides
      .whereType<Map>()
      .map((Map<dynamic, dynamic> raw) {
        final Map<String, dynamic> json = raw.cast<String, dynamic>();
        final String section = _normalizeString(json['section']);
        final double rate = _asDouble(json['rate']);
        return section.isEmpty
            ? null
            : RateOverrideInput(section: section, rate: rate);
      })
      .whereType<RateOverrideInput>()
      .toList(growable: false);
}

EstimateBillDraft? estimateBillDraftFromProjectOutputs(
  Map<String, dynamic>? outputs,
) {
  final Map<String, dynamic>? billResult = _asMap(outputs?['billResult']);
  if (billResult == null) {
    return null;
  }

  final Map<String, dynamic>? rates = _asMap(billResult['rates']);
  final Map<String, dynamic>? totals = _asMap(billResult['totals']);
  final Map<String, dynamic>? customer = _asMap(billResult['customer']);

  final EstimateBillDraft draft = EstimateBillDraft(
    glassRatePerSqFt: _formatNumericValue(rates?['glassPerSqFt']),
    laborRatePerSqFt: _formatNumericValue(rates?['laborPerSqFt']),
    hardwareRatePerWindow: _formatNumericValue(rates?['hardwarePerWindow']),
    aluminiumDiscountPercent: _formatNumericValue(
      rates?['aluminiumDiscountPercent'],
    ),
    extraCharges: _formatNumericValue(totals?['extraCharges']),
    extraChargeLines: extraChargeDraftsOf(
      ExtraCharge.listFromJson(billResult['extraChargeItems']),
    ),
    advancePaid: _formatNumericValue(totals?['advancePaid']),
    glassColor: _normalizeString(billResult['glassColor']),
    aluminiumCompany: _normalizeString(billResult['aluminiumCompany']),
    customerName: _normalizeString(customer?['name']),
    customerPhone: _normalizeString(customer?['phone']),
    customerAddress: _normalizeString(customer?['address']),
  );

  return draft.hasAnyValue ? draft : null;
}

/// [items] as Bill Inputs shows them again, amounts written the way the
/// other boxes are.
List<ExtraChargeDraft> extraChargeDraftsOf(List<ExtraCharge> items) {
  return <ExtraChargeDraft>[
    for (final ExtraCharge item in items)
      ExtraChargeDraft(
        description: item.description,
        amount: _formatNumericValue(item.amount),
      ),
  ];
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, dynamic>();
  }
  return null;
}

String _normalizeString(Object? value) {
  if (value == null) {
    return '';
  }
  return value.toString().trim();
}

double _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse('$value') ?? 0;
}

String _formatNumericValue(Object? value) {
  if (value == null) {
    return '';
  }
  final double? parsed = value is num
      ? value.toDouble()
      : double.tryParse('$value');
  if (parsed == null) {
    return _normalizeString(value);
  }
  final String fixed = parsed.toStringAsFixed(
    parsed == parsed.truncateToDouble() ? 0 : 2,
  );
  if (!fixed.contains('.')) {
    return fixed;
  }
  return fixed
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
