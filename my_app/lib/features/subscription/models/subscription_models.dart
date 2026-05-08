class SubscriptionPlan {
  final String id;
  final String productId;
  final String title;
  final String durationLabel;
  final int pricePkr;
  final String savingsLabel;
  final int sortOrder;
  final String channel;

  const SubscriptionPlan({
    required this.id,
    required this.productId,
    required this.title,
    required this.durationLabel,
    required this.pricePkr,
    required this.savingsLabel,
    required this.sortOrder,
    required this.channel,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: (json['id'] as String?) ?? '',
      productId: (json['productId'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      durationLabel: (json['durationLabel'] as String?) ?? '',
      pricePkr: (json['pricePkr'] as num?)?.round() ?? 0,
      savingsLabel: (json['savingsLabel'] as String?) ?? '',
      sortOrder: (json['sortOrder'] as num?)?.round() ?? 0,
      channel: (json['channel'] as String?) ?? 'google_play',
    );
  }

  String get fallbackPriceLabel => 'Rs $pricePkr';
}

class UserSubscription {
  final String id;
  final String planId;
  final String productId;
  final String provider;
  final String state;
  final bool autoRenewing;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final DateTime? lastVerifiedAt;

  const UserSubscription({
    required this.id,
    required this.planId,
    required this.productId,
    required this.provider,
    required this.state,
    required this.autoRenewing,
    this.startsAt,
    this.expiresAt,
    this.lastVerifiedAt,
  });

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? value) {
      return DateTime.tryParse((value as String?) ?? '');
    }

    return UserSubscription(
      id: (json['id'] as String?) ?? '',
      planId: (json['planId'] as String?) ?? '',
      productId: (json['productId'] as String?) ?? '',
      provider: (json['provider'] as String?) ?? '',
      state: (json['state'] as String?) ?? '',
      autoRenewing: (json['autoRenewing'] as bool?) ?? false,
      startsAt: parseDate(json['startsAt']),
      expiresAt: parseDate(json['expiresAt']),
      lastVerifiedAt: parseDate(json['lastVerifiedAt']),
    );
  }
}

class TrialStatus {
  final bool active;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final int daysRemaining;

  const TrialStatus({
    required this.active,
    this.startsAt,
    this.expiresAt,
    required this.daysRemaining,
  });

  factory TrialStatus.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? value) {
      return DateTime.tryParse((value as String?) ?? '');
    }

    return TrialStatus(
      active: (json['active'] as bool?) ?? false,
      startsAt: parseDate(json['startsAt']),
      expiresAt: parseDate(json['expiresAt']),
      daysRemaining: (json['daysRemaining'] as num?)?.round() ?? 0,
    );
  }
}

class SubscriptionStatus {
  final bool active;
  final String entitlement;
  final SubscriptionPlan? plan;
  final UserSubscription? subscription;
  final TrialStatus? trial;
  final int trialDays;
  final String enforcementMode;
  final bool googlePlayConfigured;
  final String packageName;

  const SubscriptionStatus({
    required this.active,
    required this.entitlement,
    this.plan,
    this.subscription,
    this.trial,
    required this.trialDays,
    required this.enforcementMode,
    required this.googlePlayConfigured,
    required this.packageName,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? rawPlan =
        (json['plan'] as Map?)?.cast<String, dynamic>();
    final Map<String, dynamic>? rawSubscription =
        (json['subscription'] as Map?)?.cast<String, dynamic>();
    final Map<String, dynamic>? rawTrial =
        (json['trial'] as Map?)?.cast<String, dynamic>();
    return SubscriptionStatus(
      active: (json['active'] as bool?) ?? false,
      entitlement: (json['entitlement'] as String?) ?? 'none',
      plan: rawPlan == null ? null : SubscriptionPlan.fromJson(rawPlan),
      subscription: rawSubscription == null
          ? null
          : UserSubscription.fromJson(rawSubscription),
      trial: rawTrial == null ? null : TrialStatus.fromJson(rawTrial),
      trialDays: (json['trialDays'] as num?)?.round() ?? 15,
      enforcementMode: (json['enforcementMode'] as String?) ?? 'preview',
      googlePlayConfigured: (json['googlePlayConfigured'] as bool?) ?? false,
      packageName: (json['packageName'] as String?) ?? 'com.quickal.app',
    );
  }

  bool get isStrict => enforcementMode == 'strict';
  bool get trialActive => entitlement == 'trial' && (trial?.active ?? false);
}

class SubscriptionCatalog {
  final List<SubscriptionPlan> plans;
  final bool googlePlayConfigured;
  final String packageName;
  final String enforcementMode;
  final int trialDays;
  final String channel;
  final DirectPaymentInfo? directPayment;

  const SubscriptionCatalog({
    required this.plans,
    required this.googlePlayConfigured,
    required this.packageName,
    required this.enforcementMode,
    required this.trialDays,
    required this.channel,
    this.directPayment,
  });

  factory SubscriptionCatalog.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawPlans = json['plans'] is List<dynamic>
        ? json['plans'] as List<dynamic>
        : <dynamic>[];
    final List<SubscriptionPlan> plans = rawPlans
        .whereType<Map<String, dynamic>>()
        .map(SubscriptionPlan.fromJson)
        .toList(growable: false)
      ..sort((SubscriptionPlan a, SubscriptionPlan b) {
        return a.sortOrder.compareTo(b.sortOrder);
      });
    return SubscriptionCatalog(
      plans: plans,
      googlePlayConfigured: (json['googlePlayConfigured'] as bool?) ?? false,
      packageName: (json['packageName'] as String?) ?? 'com.quickal.app',
      enforcementMode: (json['enforcementMode'] as String?) ?? 'preview',
      trialDays: (json['trialDays'] as num?)?.round() ?? 15,
      channel: (json['channel'] as String?) ?? 'google_play',
      directPayment: json['directPayment'] is Map
          ? DirectPaymentInfo.fromJson(
              (json['directPayment'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }
}

class DirectPaymentInfo {
  final String instructions;
  final String supportWhatsApp;

  const DirectPaymentInfo({
    required this.instructions,
    required this.supportWhatsApp,
  });

  factory DirectPaymentInfo.fromJson(Map<String, dynamic> json) {
    return DirectPaymentInfo(
      instructions: (json['instructions'] as String?) ?? '',
      supportWhatsApp: (json['supportWhatsApp'] as String?) ?? '',
    );
  }
}

class DirectPaymentRequest {
  final String id;
  final String planId;
  final String productId;
  final int amountPkr;
  final String paymentMethod;
  final String paymentReference;
  final String status;
  final String? adminNote;
  final DateTime? createdAt;

  const DirectPaymentRequest({
    required this.id,
    required this.planId,
    required this.productId,
    required this.amountPkr,
    required this.paymentMethod,
    required this.paymentReference,
    required this.status,
    this.adminNote,
    this.createdAt,
  });

  factory DirectPaymentRequest.fromJson(Map<String, dynamic> json) {
    return DirectPaymentRequest(
      id: (json['id'] as String?) ?? '',
      planId: (json['planId'] as String?) ?? '',
      productId: (json['productId'] as String?) ?? '',
      amountPkr: (json['amountPkr'] as num?)?.round() ?? 0,
      paymentMethod: (json['paymentMethod'] as String?) ?? '',
      paymentReference: (json['paymentReference'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      adminNote: json['adminNote'] as String?,
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? ''),
    );
  }
}
