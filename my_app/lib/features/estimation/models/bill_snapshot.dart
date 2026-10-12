import 'area_method.dart';
import 'extra_charge.dart';

class BillCustomer {
  final String name;
  final String phone;
  final String address;

  const BillCustomer({
    required this.name,
    required this.phone,
    required this.address,
  });

  factory BillCustomer.fromJson(Map<String, dynamic> json) {
    return BillCustomer(
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      address: json['address'] as String? ?? '',
    );
  }
}

class BillProject {
  final String name;
  final String location;

  const BillProject({required this.name, required this.location});

  factory BillProject.fromJson(Map<String, dynamic> json) {
    return BillProject(
      name: json['name'] as String? ?? '',
      location: json['location'] as String? ?? '',
    );
  }
}

class BillCompany {
  final String contractorName;
  final String workshopName;
  final String workshopPhone;
  final String workshopAddress;

  const BillCompany({
    required this.contractorName,
    required this.workshopName,
    required this.workshopPhone,
    required this.workshopAddress,
  });

  factory BillCompany.fromJson(Map<String, dynamic> json) {
    return BillCompany(
      contractorName: json['contractorName'] as String? ?? '',
      workshopName: json['workshopName'] as String? ?? '',
      workshopPhone: json['workshopPhone'] as String? ?? '',
      workshopAddress: json['workshopAddress'] as String? ?? '',
    );
  }
}

class BillRates {
  final double glassPerSqFt;
  final double laborPerSqFt;
  final double hardwarePerWindow;
  final double aluminiumDiscountPercent;

  const BillRates({
    required this.glassPerSqFt,
    required this.laborPerSqFt,
    required this.hardwarePerWindow,
    required this.aluminiumDiscountPercent,
  });

  factory BillRates.fromJson(Map<String, dynamic> json) {
    return BillRates(
      glassPerSqFt: (json['glassPerSqFt'] as num?)?.toDouble() ?? 0,
      laborPerSqFt: (json['laborPerSqFt'] as num?)?.toDouble() ?? 0,
      hardwarePerWindow: (json['hardwarePerWindow'] as num?)?.toDouble() ?? 0,
      aluminiumDiscountPercent:
          (json['aluminiumDiscountPercent'] as num?)?.toDouble() ?? 0,
    );
  }
}

class BillTotals {
  final int totalWindows;
  final double totalArea;
  final double glassCost;
  final double laborCost;
  final double hardwareCost;
  final double aluminiumOriginal;
  final double aluminiumDiscount;
  final double aluminiumAfterDiscount;
  final double extraCharges;
  final double advancePaid;
  final double grandTotal;
  final double remainingDue;

  const BillTotals({
    required this.totalWindows,
    required this.totalArea,
    required this.glassCost,
    required this.laborCost,
    required this.hardwareCost,
    required this.aluminiumOriginal,
    required this.aluminiumDiscount,
    required this.aluminiumAfterDiscount,
    required this.extraCharges,
    required this.advancePaid,
    required this.grandTotal,
    required this.remainingDue,
  });

  factory BillTotals.fromJson(Map<String, dynamic> json) {
    return BillTotals(
      totalWindows: (json['totalWindows'] as num?)?.toInt() ?? 0,
      totalArea: (json['totalArea'] as num?)?.toDouble() ?? 0,
      glassCost: (json['glassCost'] as num?)?.toDouble() ?? 0,
      laborCost: (json['laborCost'] as num?)?.toDouble() ?? 0,
      hardwareCost: (json['hardwareCost'] as num?)?.toDouble() ?? 0,
      aluminiumOriginal: (json['aluminiumOriginal'] as num?)?.toDouble() ?? 0,
      aluminiumDiscount: (json['aluminiumDiscount'] as num?)?.toDouble() ?? 0,
      aluminiumAfterDiscount:
          (json['aluminiumAfterDiscount'] as num?)?.toDouble() ?? 0,
      extraCharges: (json['extraCharges'] as num?)?.toDouble() ?? 0,
      advancePaid: (json['advancePaid'] as num?)?.toDouble() ?? 0,
      grandTotal: (json['grandTotal'] as num?)?.toDouble() ?? 0,
      remainingDue: (json['remainingDue'] as num?)?.toDouble() ?? 0,
    );
  }
}

class BillWindowSummary {
  final String type;
  final int quantity;
  final double areaSqFt;

  /// What the ironmongery for one of these cost, and for all of them.
  ///
  /// The engine has priced hardware per window type for a while, but the bill
  /// only ever showed the total. A customer's first question about a hardware
  /// figure is which windows it covers, and this is the answer.
  final double hardwareRate;
  final double hardwareCost;

  const BillWindowSummary({
    required this.type,
    required this.quantity,
    required this.areaSqFt,
    this.hardwareRate = 0,
    this.hardwareCost = 0,
  });

  factory BillWindowSummary.fromJson(Map<String, dynamic> json) {
    return BillWindowSummary(
      type: json['type'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      areaSqFt: (json['areaSqFt'] as num?)?.toDouble() ?? 0,
      hardwareRate: (json['hardwareRate'] as num?)?.toDouble() ?? 0,
      hardwareCost: (json['hardwareCost'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// The glazing of one glass, across the whole job.
class BillGlassSummary {
  final String color;
  final double areaSqFt;
  final double rate;
  final double cost;

  const BillGlassSummary({
    required this.color,
    required this.areaSqFt,
    required this.rate,
    required this.cost,
  });

  /// What a window with no glass of its own is filed under. Jobs quoted before
  /// glass was picked per window have one such group and no other.
  bool get isUnnamed => color.trim().isEmpty;

  factory BillGlassSummary.fromJson(Map<String, dynamic> json) {
    return BillGlassSummary(
      color: json['color'] as String? ?? '',
      areaSqFt: (json['areaSqFt'] as num?)?.toDouble() ?? 0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0,
      cost: (json['cost'] as num?)?.toDouble() ?? 0,
    );
  }
}

class BillSnapshot {
  final bool ok;
  final List<String> errors;

  /// The one gauge the request carried for the whole job. What the bill
  /// prints is [gaugesShown].
  final String gauge;

  /// Every gauge the job's windows are made in, thinnest first. Empty on a
  /// bill made before they were kept with it.
  final List<String> gauges;

  final String aluminiumColor;
  final String glassColor;
  final String aluminiumCompany;
  final BillCustomer customer;
  final BillProject project;
  final BillCompany company;
  final BillRates rates;
  final BillTotals totals;
  final List<BillWindowSummary> windowSummary;

  /// Glazing broken out by glass. One row per glass the job actually used.
  final List<BillGlassSummary> glassSummary;

  /// "running" for a bill made in running feet, '' for square feet.
  final String areaMethod;

  /// What [BillTotals.extraCharges] is made of, each line saying what it is
  /// for. Empty when there are none, or when they came as one figure.
  final List<ExtraCharge> extraChargeItems;

  /// "Rn.ft" or "sq.ft", for beside every figure of feet on this bill.
  String get areaUnit => areaUnitFor(areaMethod);

  /// The gauges to print: all of them, or the one the request carried on a
  /// bill made before they were kept.
  List<String> get gaugesShown {
    if (gauges.isNotEmpty) return gauges;
    final String one = gauge.trim();
    return one.isEmpty ? const <String>[] : <String>[one];
  }

  const BillSnapshot({
    required this.ok,
    required this.errors,
    required this.gauge,
    this.gauges = const <String>[],
    required this.aluminiumColor,
    required this.glassColor,
    this.aluminiumCompany = '',
    required this.customer,
    required this.project,
    required this.company,
    required this.rates,
    required this.totals,
    required this.windowSummary,
    this.glassSummary = const <BillGlassSummary>[],
    this.areaMethod = '',
    this.extraChargeItems = const <ExtraCharge>[],
  });

  factory BillSnapshot.fromJson(Map<String, dynamic> json) {
    final List<dynamic> summaryItems =
        json['windowSummary'] as List<dynamic>? ?? const <dynamic>[];

    return BillSnapshot(
      ok: json['ok'] as bool? ?? false,
      errors: (json['errors'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(),
      gauge: json['gauge'] as String? ?? '',
      gauges: (json['gauges'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .map((String g) => g.trim())
          .where((String g) => g.isNotEmpty)
          .toList(),
      aluminiumColor: json['aluminiumColor'] as String? ?? '',
      glassColor: json['glassColor'] as String? ?? '',
      aluminiumCompany: json['aluminiumCompany'] as String? ?? '',
      customer: BillCustomer.fromJson(
        json['customer'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      project: BillProject.fromJson(
        json['project'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      company: BillCompany.fromJson(
        json['company'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      rates: BillRates.fromJson(
        json['rates'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      totals: BillTotals.fromJson(
        json['totals'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      windowSummary: summaryItems
          .whereType<Map<String, dynamic>>()
          .map(BillWindowSummary.fromJson)
          .toList(),
      glassSummary:
          (json['glassSummary'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(BillGlassSummary.fromJson)
              .toList(),
      areaMethod: json['areaMethod'] as String? ?? '',
      extraChargeItems: ExtraCharge.listFromJson(json['extraChargeItems']),
    );
  }
}
