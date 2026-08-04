import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../../../core/config/api_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_screen_shell.dart';
import '../../../shared/widgets/social_links_card.dart';
import '../data/subscription_api_client.dart';
import '../models/subscription_models.dart';
import 'safepay_checkout_screen.dart';

class SubscriptionGateScreen extends StatefulWidget {
  final Widget? child;

  /// Manage mode ("Billing & Plans" from Settings): always shows the current
  /// plan status and purchase options, even while a trial or subscription is
  /// active — so users can buy during the trial and see when their plan ends.
  final bool manage;

  const SubscriptionGateScreen({super.key, required Widget this.child})
    : manage = false;

  const SubscriptionGateScreen.manage({super.key})
    : child = null,
      manage = true;

  @override
  State<SubscriptionGateScreen> createState() => _SubscriptionGateScreenState();
}

class _SubscriptionGateScreenState extends State<SubscriptionGateScreen> {
  final SubscriptionApiClient _apiClient = SubscriptionApiClient();
  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  SubscriptionCatalog? _catalog;
  SubscriptionStatus? _status;
  final Map<String, ProductDetails> _products = <String, ProductDetails>{};
  final TextEditingController _paymentReferenceController =
      TextEditingController();
  final TextEditingController _payerNameController = TextEditingController();
  final TextEditingController _payerPhoneController = TextEditingController();
  final TextEditingController _paymentNotesController = TextEditingController();

  bool _loading = true;
  bool _iapAvailable = false;
  bool _purchaseBusy = false;
  bool _previewBypass = false;
  String? _selectedProductId;
  String _paymentMethod = 'bank_transfer';
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!ApiConfig.isDirectWebsiteBuild) {
      _purchaseSubscription = _iap.purchaseStream.listen(
        _handlePurchaseUpdates,
        onError: (Object error) {
          if (!mounted) return;
          setState(() {
            _purchaseBusy = false;
            _error = 'Purchase update failed. Please try again.';
          });
        },
      );
    }
    _loadSubscriptionState();
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    _paymentReferenceController.dispose();
    _payerNameController.dispose();
    _payerPhoneController.dispose();
    _paymentNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SubscriptionStatus? status = _status;
    if (!widget.manage &&
        ((status != null && status.active) || _previewBypass)) {
      return widget.child!;
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.manage ? 'Billing & Plans' : 'Quick AL'),
      ),
      body: AppScreenShell(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadSubscriptionState,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: <Widget>[
                    if (widget.manage)
                      _CurrentPlanCard(status: status)
                    else
                      _Header(status: status),
                    const SizedBox(height: AppTheme.space6),
                    if (_error != null) ...<Widget>[
                      _StateBanner(
                        icon: Icons.error_outline_rounded,
                        color: AppTheme.danger,
                        text: _error!,
                      ),
                      const SizedBox(height: AppTheme.space5),
                    ],
                    if (_message != null) ...<Widget>[
                      _StateBanner(
                        icon: Icons.info_outline_rounded,
                        color: AppTheme.royalBlue,
                        text: _message!,
                      ),
                      const SizedBox(height: AppTheme.space5),
                    ],
                    ..._planCards(),
                    // Manual bank-transfer fields only appear when the owner has
                    // turned the option on; otherwise users only pay online.
                    if (ApiConfig.isDirectWebsiteBuild &&
                        (_catalog?.manualPaymentEnabled ?? false)) ...<Widget>[
                      const SizedBox(height: AppTheme.space2),
                      _DirectPaymentForm(
                        catalog: _catalog,
                        paymentMethod: _paymentMethod,
                        paymentReferenceController: _paymentReferenceController,
                        payerNameController: _payerNameController,
                        payerPhoneController: _payerPhoneController,
                        notesController: _paymentNotesController,
                        onPaymentMethodChanged: (String value) {
                          setState(() {
                            _paymentMethod = value;
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: AppTheme.space6),
                    _ActionBar(
                      busy: _purchaseBusy,
                      selected: _selectedProductId != null,
                      canBuy: ApiConfig.isDirectWebsiteBuild
                          ? _selectedProductId != null
                          : _canBuySelectedPlan,
                      // The "Continue" bypass exists only so Google Play's
                      // closed-testing reviewers can reach the app without
                      // buying. The direct/website build must never offer it:
                      // once the trial ends there, paying is the only way in.
                      previewMode:
                          !ApiConfig.isDirectWebsiteBuild &&
                          !widget.manage &&
                          status?.enforcementMode != 'strict',
                      directMode: ApiConfig.isDirectWebsiteBuild,
                      manualEnabled: _catalog?.manualPaymentEnabled ?? false,
                      canPayOnline:
                          !_purchaseBusy && _selectedProductId != null,
                      onBuy: ApiConfig.isDirectWebsiteBuild
                          ? _submitDirectPaymentRequest
                          : _buySelectedPlan,
                      onPayOnline: _payOnlineWithSafepay,
                      onRestore: _restorePurchases,
                      onPreviewContinue: () {
                        setState(() {
                          _previewBypass = true;
                        });
                      },
                    ),
                    const SizedBox(height: AppTheme.space5),
                    const PaymentHelpCard(),
                    const SizedBox(height: AppTheme.space5),
                    Text(
                      'All payments are final and non-refundable. If the app '
                      'does not work after payment due to a problem on our '
                      'side, email quickal.dev@gmail.com within 7 days for a '
                      'refund review.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  List<Widget> _planCards() {
    final List<SubscriptionPlan> plans =
        _catalog?.plans ?? <SubscriptionPlan>[];
    if (plans.isEmpty) {
      return <Widget>[
        _StateBanner(
          icon: Icons.payments_rounded,
          color: AppTheme.warning,
          text: 'Subscription plans are not available yet.',
        ),
      ];
    }

    return plans
        .map((SubscriptionPlan plan) {
          final ProductDetails? product = _products[plan.productId];
          final bool selected = _selectedProductId == plan.productId;
          final bool direct = ApiConfig.isDirectWebsiteBuild;
          final bool available = direct || (product != null && _iapAvailable);
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.space5),
            child: _PlanCard(
              plan: plan,
              priceLabel: direct
                  ? plan.fallbackPriceLabel
                  : product?.price ?? plan.fallbackPriceLabel,
              selected: selected,
              available: available,
              onTap: () {
                setState(() {
                  _selectedProductId = plan.productId;
                  _error = null;
                  if (direct) {
                    _message =
                        'Pay locally, then submit your payment reference for approval.';
                  } else if (!_iapAvailable) {
                    _message =
                        'Google Play billing is not available on this install.';
                  } else if (product == null) {
                    _message =
                        'This plan is not active in Google Play Console yet.';
                  } else {
                    _message = null;
                  }
                });
              },
            ),
          );
        })
        .toList(growable: false);
  }

  bool get _canBuySelectedPlan {
    final String? productId = _selectedProductId;
    return !_purchaseBusy &&
        _iapAvailable &&
        productId != null &&
        _products.containsKey(productId);
  }

  Future<void> _loadSubscriptionState() async {
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    try {
      final SubscriptionCatalog catalog = await _apiClient.fetchPlans();
      final SubscriptionStatus status = await _apiClient.fetchStatus();
      final bool direct = ApiConfig.isDirectWebsiteBuild;
      final bool available = direct ? false : await _iap.isAvailable();
      final Map<String, ProductDetails> products = <String, ProductDetails>{};

      if (!direct && available && catalog.plans.isNotEmpty) {
        final ProductDetailsResponse response = await _iap.queryProductDetails(
          catalog.plans.map((SubscriptionPlan plan) => plan.productId).toSet(),
        );
        for (final ProductDetails product in response.productDetails) {
          products[product.id] = product;
        }
      }

      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _status = status;
        _iapAvailable = available;
        _products
          ..clear()
          ..addAll(products);
        _selectedProductId = _selectDefaultProductId(catalog, products);
        _loading = false;
        if (direct) {
          _message = 'Direct website access uses local payment approval.';
        } else if (!available) {
          _message = 'Install from Google Play to activate billing.';
        } else if (products.isEmpty) {
          _message = 'Google Play plans are waiting for Play Console setup.';
        }
      });
    } on SubscriptionApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Subscription setup failed unexpectedly.';
      });
    }
  }

  String? _selectDefaultProductId(
    SubscriptionCatalog catalog,
    Map<String, ProductDetails> products,
  ) {
    if (_selectedProductId != null &&
        catalog.plans.any(
          (SubscriptionPlan plan) => plan.productId == _selectedProductId,
        )) {
      return _selectedProductId;
    }
    if (catalog.plans.isEmpty) {
      return null;
    }
    // Pre-select the popular plan (3 months) to nudge it; fall back to the
    // first plan if none is flagged.
    final SubscriptionPlan preferred = catalog.plans.firstWhere(
      (SubscriptionPlan plan) => plan.popular,
      orElse: () => catalog.plans.firstWhere(
        (SubscriptionPlan plan) => plan.id == 'quarterly',
        orElse: () => catalog.plans.first,
      ),
    );
    return preferred.productId;
  }

  // Safepay hosted checkout (website/direct builds). Opens Safepay's page in a
  // WebView; entitlement is granted server-side by Safepay's signed webhook, so
  // on return we poll our own status rather than trusting the redirect.
  Future<void> _payOnlineWithSafepay() async {
    final String? productId = _selectedProductId;
    SubscriptionPlan? plan;
    for (final SubscriptionPlan candidate
        in _catalog?.plans ?? <SubscriptionPlan>[]) {
      if (candidate.productId == productId) {
        plan = candidate;
        break;
      }
    }
    if (plan == null) {
      setState(() => _error = 'Select a plan first.');
      return;
    }

    setState(() {
      _purchaseBusy = true;
      _error = null;
      _message = null;
    });

    try {
      final SafepayCheckout checkout = await _apiClient.createSafepayCheckout(
        planId: plan.id,
      );
      if (!mounted) return;
      if (checkout.checkoutUrl.isEmpty) {
        setState(() {
          _purchaseBusy = false;
          _error = 'Could not start the online payment. Please try again.';
        });
        return;
      }

      final SafepayCheckoutResult? result = await Navigator.of(context)
          .push<SafepayCheckoutResult>(
            MaterialPageRoute<SafepayCheckoutResult>(
              builder: (BuildContext context) => SafepayCheckoutScreen(
                checkoutUrl: checkout.checkoutUrl,
                returnUrlPrefix: ApiConfig.resolveUrl(
                  '/api/subscription/safepay/return',
                ),
                cancelUrlPrefix: ApiConfig.resolveUrl(
                  '/api/subscription/safepay/cancel',
                ),
              ),
            ),
          );
      if (!mounted) return;

      if (result == SafepayCheckoutResult.paid) {
        setState(() => _message = 'Confirming your payment…');
        await _awaitSafepayActivation();
        return;
      }

      setState(() {
        _purchaseBusy = false;
        _message = result == SafepayCheckoutResult.cancelled
            ? 'Payment cancelled. No amount was charged.'
            : null;
      });
    } on SubscriptionApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _purchaseBusy = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _purchaseBusy = false;
        _error = 'Online payment could not be started.';
      });
    }
  }

  // The webhook lands a moment after the customer is redirected back, so give
  // it a few seconds before deciding anything is wrong. Never conclude failure
  // outright — a slow webhook is not a failed payment.
  Future<void> _awaitSafepayActivation() async {
    const List<int> delaysMs = <int>[1200, 1800, 2500, 3500, 5000];
    for (final int delay in delaysMs) {
      await Future<void>.delayed(Duration(milliseconds: delay));
      if (!mounted) return;
      try {
        final SubscriptionStatus status = await _apiClient.fetchStatus();
        if (!mounted) return;
        if (status.entitlement == 'subscription') {
          setState(() {
            _status = status;
            _purchaseBusy = false;
            _error = null;
            _message = 'Payment successful — your subscription is active.';
          });
          return;
        }
        setState(() => _status = status);
      } catch (_) {
        // Keep polling; a transient read failure is not a payment failure.
      }
    }

    if (!mounted) return;
    setState(() {
      _purchaseBusy = false;
      _message =
          'Your payment was received. Activation is taking a moment — pull down '
          'to refresh, or contact support if it does not appear shortly.';
    });
  }

  Future<void> _submitDirectPaymentRequest() async {
    final String? productId = _selectedProductId;
    SubscriptionPlan? plan;
    for (final SubscriptionPlan candidate
        in _catalog?.plans ?? <SubscriptionPlan>[]) {
      if (candidate.productId == productId) {
        plan = candidate;
        break;
      }
    }
    final String reference = _paymentReferenceController.text.trim();
    if (plan == null) {
      setState(() {
        _error = 'Select a direct plan first.';
      });
      return;
    }
    if (reference.isEmpty) {
      setState(() {
        _error = 'Enter your bank or wallet payment reference.';
      });
      return;
    }

    setState(() {
      _purchaseBusy = true;
      _error = null;
      _message = null;
    });

    try {
      final result = await _apiClient.submitDirectPaymentRequest(
        planId: plan.id,
        paymentMethod: _paymentMethod,
        paymentReference: reference,
        payerName: _payerNameController.text,
        payerPhone: _payerPhoneController.text,
        amountPkr: plan.pricePkr,
        notes: _paymentNotesController.text,
      );
      if (!mounted) return;
      setState(() {
        _status = result.status;
        _purchaseBusy = false;
        _message =
            'Payment reference submitted. Support will approve it after verification.';
        _error = null;
      });
    } on SubscriptionApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _purchaseBusy = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _purchaseBusy = false;
        _error = 'Direct payment request failed.';
      });
    }
  }

  Future<void> _buySelectedPlan() async {
    final String? productId = _selectedProductId;
    if (productId == null || !_products.containsKey(productId)) {
      setState(() {
        _error = 'Select an available plan first.';
      });
      return;
    }

    final ProductDetails product = _products[productId]!;
    setState(() {
      _purchaseBusy = true;
      _error = null;
      _message = null;
    });

    try {
      final PurchaseParam purchaseParam;
      if (product is GooglePlayProductDetails) {
        purchaseParam = GooglePlayPurchaseParam(
          productDetails: product,
          offerToken: product.offerToken,
        );
      } else {
        purchaseParam = PurchaseParam(productDetails: product);
      }
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _purchaseBusy = false;
        _error = 'Google Play purchase could not be started.';
      });
    }
  }

  Future<void> _restorePurchases() async {
    setState(() {
      _purchaseBusy = true;
      _error = null;
      _message = null;
    });
    try {
      await _iap.restorePurchases();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _purchaseBusy = false;
        _error = 'Restore failed. Please try again.';
      });
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final PurchaseDetails purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        if (!mounted) continue;
        setState(() {
          _purchaseBusy = true;
          _message = 'Payment is pending.';
        });
        continue;
      }

      if (purchase.status == PurchaseStatus.error) {
        if (!mounted) continue;
        setState(() {
          _purchaseBusy = false;
          _error = purchase.error?.message ?? 'Purchase failed.';
        });
        continue;
      }

      if (purchase.status == PurchaseStatus.canceled) {
        if (!mounted) continue;
        setState(() {
          _purchaseBusy = false;
          _message = 'Purchase canceled.';
        });
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _verifyPurchase(purchase);
      }
    }
  }

  Future<void> _verifyPurchase(PurchaseDetails purchase) async {
    final String token = purchase.verificationData.serverVerificationData;
    if (token.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _purchaseBusy = false;
        _error = 'Google Play did not return a purchase token.';
      });
      return;
    }

    try {
      final SubscriptionStatus status = await _apiClient
          .verifyGooglePlayPurchase(
            productId: purchase.productID,
            purchaseToken: token,
            packageName: _catalog?.packageName,
          );
      if (purchase.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(purchase);
        } catch (_) {
          // Backend verification is already saved; Play can retry completion.
        }
      }
      if (!mounted) return;
      setState(() {
        _status = status;
        _purchaseBusy = false;
        _message = status.active
            ? 'Subscription active.'
            : 'Subscription saved.';
        _error = null;
      });
    } on SubscriptionApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _purchaseBusy = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _purchaseBusy = false;
        _error = 'Purchase verification failed.';
      });
    }
  }
}

/// "Your Plan" summary shown in manage mode: free trial vs paid plan, which
/// plan is active, and exactly when it ends.
class _CurrentPlanCard extends StatelessWidget {
  final SubscriptionStatus? status;

  const _CurrentPlanCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final SubscriptionStatus? current = status;
    final String entitlement = current?.entitlement ?? 'none';
    final UserSubscription? subscription = current?.subscription;
    final TrialStatus? trial = current?.trial;
    final SubscriptionPlan? plan = current?.plan;

    final String title;
    final String detail;
    final IconData icon;
    final Color accent;
    String sourceLabel = '';

    if (entitlement == 'subscription' && subscription != null) {
      title = plan != null
          ? '${plan.title} — ${plan.durationLabel}'
          : subscription.planId.isEmpty
          ? 'Paid plan'
          : subscription.planId;
      final String expires = formatQuickAlDate(subscription.expiresAt);
      detail = subscription.autoRenewing
          ? 'Active — renews on $expires'
          : 'Active — valid until $expires';
      icon = Icons.verified_rounded;
      accent = AppTheme.success;
      sourceLabel = subscription.provider == 'direct_website'
          ? 'Website plan'
          : subscription.provider == 'google_play'
          ? 'Google Play plan'
          : '';
    } else if (entitlement == 'trial' && (trial?.active ?? false)) {
      final int days = trial?.daysRemaining ?? 0;
      title = 'Free Trial';
      detail = days > 0
          ? '$days ${days == 1 ? 'day' : 'days'} left — ends ${formatQuickAlDate(trial?.expiresAt)}'
          : 'Ends today (${formatQuickAlDate(trial?.expiresAt)})';
      icon = Icons.timer_rounded;
      accent = AppTheme.warning;
      sourceLabel = 'Buy a plan below to continue after the trial.';
    } else {
      title = 'No active plan';
      detail = 'Choose a plan below to keep full access to Quick AL.';
      icon = Icons.lock_open_rounded;
      accent = AppTheme.danger;
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.space6),
      decoration: AppTheme.accentPanelDecoration(radius: AppTheme.radiusLg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.line),
            ),
            child: Icon(icon, color: accent, size: 30),
          ),
          const SizedBox(width: AppTheme.space5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Your Plan',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: AppTheme.space2),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppTheme.space2),
                Text(
                  detail,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (sourceLabel.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppTheme.space2),
                  Text(
                    sourceLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final SubscriptionStatus? status;

  const _Header({required this.status});

  @override
  Widget build(BuildContext context) {
    final TrialStatus? trial = status?.trial;
    final bool trialActive = trial?.active ?? false;
    final int daysLeft = trial?.daysRemaining ?? 0;

    String headline;
    if (trialActive) {
      headline = daysLeft > 0
          ? '$daysLeft ${daysLeft == 1 ? 'day' : 'days'} left in your free trial'
          : 'Your free trial ends today';
    } else {
      headline = 'Your free trial has ended';
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.space6),
      decoration: AppTheme.accentPanelDecoration(radius: AppTheme.radiusLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.line),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppTheme.royalBlue,
                  size: 30,
                ),
              ),
              const SizedBox(width: AppTheme.space5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Go Pro with Quick AL',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: AppTheme.space2),
                    Text(
                      headline,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.royalBlue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space5),
          Wrap(
            spacing: AppTheme.space3,
            runSpacing: AppTheme.space3,
            children: const <Widget>[
              _BenefitChip(
                icon: Icons.calculate_rounded,
                label: 'Unlimited estimates',
              ),
              _BenefitChip(
                icon: Icons.picture_as_pdf_rounded,
                label: 'PDF reports',
              ),
              _BenefitChip(
                icon: Icons.auto_awesome_mosaic_rounded,
                label: 'Glass optimization',
              ),
              _BenefitChip(
                icon: Icons.devices_rounded,
                label: 'Secure on your device',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BenefitChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BenefitChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AppTheme.tealAccent),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final String priceLabel;
  final bool selected;
  final bool available;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.priceLabel,
    required this.selected,
    required this.available,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool popular = plan.popular;
    final Color accent = selected
        ? AppTheme.royalBlue
        : popular
        ? AppTheme.amberAccent
        : AppTheme.tealAccent;
    final Color borderColor = selected
        ? AppTheme.royalBlue
        : popular
        ? AppTheme.amberAccent.withValues(alpha: 0.55)
        : AppTheme.line;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: borderColor,
              width: (selected || popular) ? 2 : 1,
            ),
            boxShadow: AppTheme.softShadow(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (popular)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: const BoxDecoration(
                    color: AppTheme.amberAccent,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(AppTheme.radiusLg),
                      topRight: Radius.circular(AppTheme.radiusLg),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(
                        Icons.star_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        plan.badgeLabel.isNotEmpty
                            ? plan.badgeLabel
                            : 'MOST POPULAR',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(AppTheme.space6),
                child: Row(
                  children: <Widget>[
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: accent,
                    ),
                    const SizedBox(width: AppTheme.space5),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  plan.title,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                              ),
                              if (!popular &&
                                  plan.badgeLabel.isNotEmpty) ...<Widget>[
                                const SizedBox(width: AppTheme.space3),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.tealAccent.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    plan.badgeLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: AppTheme.deepTeal,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: AppTheme.space2),
                          Text(
                            plan.durationLabel,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (plan.savingsLabel.isNotEmpty) ...<Widget>[
                            const SizedBox(height: AppTheme.space3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.danger,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                plan.savingsLabel,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppTheme.space4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        if (plan.hasDiscount)
                          Text(
                            plan.fallbackOriginalPriceLabel,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppTheme.textSecondary,
                                  decoration: TextDecoration.lineThrough,
                                ),
                          ),
                        Text(
                          priceLabel,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: AppTheme.space2),
                        Icon(
                          available
                              ? Icons.verified_rounded
                              : Icons.schedule_rounded,
                          size: 18,
                          color: available
                              ? AppTheme.success
                              : AppTheme.warning,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectPaymentForm extends StatelessWidget {
  final SubscriptionCatalog? catalog;
  final String paymentMethod;
  final TextEditingController paymentReferenceController;
  final TextEditingController payerNameController;
  final TextEditingController payerPhoneController;
  final TextEditingController notesController;
  final ValueChanged<String> onPaymentMethodChanged;

  const _DirectPaymentForm({
    required this.catalog,
    required this.paymentMethod,
    required this.paymentReferenceController,
    required this.payerNameController,
    required this.payerPhoneController,
    required this.notesController,
    required this.onPaymentMethodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final DirectPaymentInfo? info = catalog?.directPayment;
    return Container(
      padding: const EdgeInsets.all(AppTheme.space6),
      decoration: AppTheme.softPanelDecoration(radius: AppTheme.radiusLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: AppTheme.tealAccent,
              ),
              const SizedBox(width: AppTheme.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Local payment',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTheme.space2),
                    Text(
                      (info?.instructions.trim().isNotEmpty ?? false)
                          ? info!.instructions
                          : 'Pay by local bank or wallet, then submit your payment reference for approval.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (info?.supportWhatsApp.trim().isNotEmpty ??
                        false) ...<Widget>[
                      const SizedBox(height: AppTheme.space2),
                      Text(
                        'WhatsApp support: ${info!.supportWhatsApp}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space5),
          DropdownButtonFormField<String>(
            initialValue: paymentMethod,
            decoration: const InputDecoration(labelText: 'Payment method'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: 'bank_transfer',
                child: Text('Bank transfer'),
              ),
              DropdownMenuItem<String>(
                value: 'easypaisa',
                child: Text('EasyPaisa'),
              ),
              DropdownMenuItem<String>(
                value: 'jazzcash',
                child: Text('JazzCash'),
              ),
              DropdownMenuItem<String>(
                value: 'other_wallet',
                child: Text('Other wallet'),
              ),
            ],
            onChanged: (String? value) {
              if (value != null) {
                onPaymentMethodChanged(value);
              }
            },
          ),
          const SizedBox(height: AppTheme.space4),
          TextField(
            controller: paymentReferenceController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Transaction ID / reference',
            ),
          ),
          const SizedBox(height: AppTheme.space4),
          TextField(
            controller: payerNameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Payer name'),
          ),
          const SizedBox(height: AppTheme.space4),
          TextField(
            controller: payerPhoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Payer phone'),
          ),
          const SizedBox(height: AppTheme.space4),
          TextField(
            controller: notesController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final bool busy;
  final bool selected;
  final bool canBuy;
  final bool previewMode;
  final bool directMode;
  final bool manualEnabled;
  final bool canPayOnline;
  final VoidCallback onBuy;
  final VoidCallback onPayOnline;
  final VoidCallback onRestore;
  final VoidCallback onPreviewContinue;

  const _ActionBar({
    required this.busy,
    required this.selected,
    required this.canBuy,
    required this.previewMode,
    required this.directMode,
    required this.manualEnabled,
    required this.canPayOnline,
    required this.onBuy,
    required this.onPayOnline,
    required this.onRestore,
    required this.onPreviewContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (directMode) ...<Widget>[
          // Primary, and the only option most users see: pay online via Safepay.
          FilledButton.icon(
            onPressed: canPayOnline ? onPayOnline : null,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.credit_card_rounded),
            label: Text(busy ? 'Processing' : 'Pay Online (Card / Wallet)'),
          ),
          const SizedBox(height: AppTheme.space3),
          Text(
            'Instant activation. Secure payment powered by Safepay — your card '
            'details are never stored by Quick AL.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppTheme.space5),
          _DividerLabel(
            manualEnabled ? 'or pay by bank transfer' : 'other options',
          ),
          const SizedBox(height: AppTheme.space5),
          // Manual bank transfer is only offered when the owner has turned it on
          // from the admin panel. Otherwise it shows here, disabled, so users
          // can see it exists but can only pay online.
          if (manualEnabled)
            OutlinedButton.icon(
              onPressed: busy || !canBuy ? null : onBuy,
              icon: const Icon(Icons.receipt_long_rounded),
              label: const Text('Submit Payment Reference'),
            )
          else ...<Widget>[
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.account_balance_rounded),
              label: const Text('Bank transfer (currently unavailable)'),
            ),
            const SizedBox(height: AppTheme.space2),
            Text(
              'Bank transfer is not available right now — please pay online above.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ] else ...<Widget>[
          FilledButton.icon(
            onPressed: canBuy ? onBuy : null,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_open_rounded),
            label: Text(busy ? 'Processing' : 'Subscribe'),
          ),
          const SizedBox(height: AppTheme.space4),
          OutlinedButton.icon(
            onPressed: busy ? null : onRestore,
            icon: const Icon(Icons.restore_rounded),
            label: const Text('Restore'),
          ),
        ],
        if (previewMode) ...<Widget>[
          const SizedBox(height: AppTheme.space4),
          TextButton(
            onPressed: busy ? null : onPreviewContinue,
            child: const Text('Continue'),
          ),
        ],
      ],
    );
  }
}

class _DividerLabel extends StatelessWidget {
  final String text;
  const _DividerLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4),
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppTheme.textSecondary),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _StateBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _StateBanner({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color),
          const SizedBox(width: AppTheme.space4),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
