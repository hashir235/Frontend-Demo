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

  const BillWindowSummary({
    required this.type,
    required this.quantity,
    required this.areaSqFt,
  });

  factory BillWindowSummary.fromJson(Map<String, dynamic> json) {
    return BillWindowSummary(
      type: json['type'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      areaSqFt: (json['areaSqFt'] as num?)?.toDouble() ?? 0,
    );
  }
}

class BillSnapshot {
  final bool ok;
  final List<String> errors;
  final String gauge;
  final String aluminiumColor;
  final String glassColor;
  final BillCustomer customer;
  final BillProject project;
  final BillCompany company;
  final BillRates rates;
  final BillTotals totals;
  final List<BillWindowSummary> windowSummary;

  const BillSnapshot({
    required this.ok,
    required this.errors,
    required this.gauge,
    required this.aluminiumColor,
    required this.glassColor,
    required this.customer,
    required this.project,
    required this.company,
    required this.rates,
    required this.totals,
    required this.windowSummary,
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
      aluminiumColor: json['aluminiumColor'] as String? ?? '',
      glassColor: json['glassColor'] as String? ?? '',
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
    );
  }
}
