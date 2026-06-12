import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../../../core/config/api_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_screen_shell.dart';
import '../data/subscription_api_client.dart';
import '../models/subscription_models.dart';

class SubscriptionGateScreen extends StatefulWidget {
  final Widget child;

  const SubscriptionGateScreen({super.key, required this.child});

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
    if ((status != null && status.active) || _previewBypass) {
      return widget.child;
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Quick AL')),
      body: AppScreenShell(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadSubscriptionState,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: <Widget>[
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
                    if (ApiConfig.isDirectWebsiteBuild) ...<Widget>[
                      const SizedBox(height: AppTheme.space2),
                      _DirectPaymentForm(
                        catalog: _catalog,
                        paymentMethod: _paymentMethod,
                        paymentReferenceController:
                            _paymentReferenceController,
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
                      previewMode: status?.enforcementMode != 'strict',
                      directMode: ApiConfig.isDirectWebsiteBuild,
                      onBuy: ApiConfig.isDirectWebsiteBuild
                          ? _submitDirectPaymentRequest
                          : _buySelectedPlan,
                      onRestore: _restorePurchases,
                      onPreviewContinue: () {
                        setState(() {
                          _previewBypass = true;
                        });
                      },
                    ),
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
    final List<SubscriptionPlan> plans = _catalog?.plans ?? <SubscriptionPlan>[];
    if (plans.isEmpty) {
      return <Widget>[
        _StateBanner(
          icon: Icons.payments_rounded,
          color: AppTheme.warning,
          text: 'Subscription plans are not available yet.',
        ),
      ];
    }

    return plans.map((SubscriptionPlan plan) {
      final ProductDetails? product = _products[plan.productId];
      final bool selected = _selectedProductId == plan.productId;
      final bool direct = ApiConfig.isDirectWebsiteBuild;
      final bool available = direct || (product != null && _iapAvailable);
      return Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.space5),
        child: _PlanCard(
          plan: plan,
          priceLabel: direct ? plan.fallbackPriceLabel : product?.price ?? plan.fallbackPriceLabel,
          selected: selected,
          available: available,
          onTap: () {
            setState(() {
              _selectedProductId = plan.productId;
              _error = null;
              if (direct) {
                _message = 'Pay locally, then submit your payment reference for approval.';
              } else if (!_iapAvailable) {
                _message = 'Google Play billing is not available on this install.';
              } else if (product == null) {
                _message = 'This plan is not active in Google Play Console yet.';
              } else {
                _message = null;
              }
            });
          },
        ),
      );
    }).toList(growable: false);
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
        catalog.plans.any((SubscriptionPlan plan) => plan.productId == _selectedProductId)) {
      return _selectedProductId;
    }
    if (catalog.plans.isEmpty) {
      return null;
    }
    final SubscriptionPlan preferred = catalog.plans.firstWhere(
      (SubscriptionPlan plan) => plan.id == 'monthly',
      orElse: () => catalog.plans.first,
    );
    return preferred.productId;
  }

  Future<void> _submitDirectPaymentRequest() async {
    final String? productId = _selectedProductId;
    SubscriptionPlan? plan;
    for (final SubscriptionPlan candidate in _catalog?.plans ?? <SubscriptionPlan>[]) {
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
      final SubscriptionStatus status = await _apiClient.verifyGooglePlayPurchase(
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
        _message = status.active ? 'Subscription active.' : 'Subscription saved.';
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

class _Header extends StatelessWidget {
  final SubscriptionStatus? status;

  const _Header({required this.status});

  @override
  Widget build(BuildContext context) {
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
                  'Quick AL Subscription',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppTheme.space3),
                Text(
                  status?.enforcementMode == 'strict'
                      ? 'Choose a plan to continue.'
                      : 'Billing preview is active while Play Console setup is completed.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
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
    final Color accent = selected ? AppTheme.royalBlue : AppTheme.tealAccent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: onTap,
        child: Ink(
          decoration: AppTheme.elevatedCardDecoration(
            selected: selected,
            accent: accent,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space6),
            child: Row(
              children: <Widget>[
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: accent,
                ),
                const SizedBox(width: AppTheme.space5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        plan.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: AppTheme.space2),
                      Text(
                        plan.durationLabel,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (plan.savingsLabel.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppTheme.space3),
                        Text(
                          plan.savingsLabel,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppTheme.success,
                            fontWeight: FontWeight.w900,
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
                    Text(
                      priceLabel,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space2),
                    Icon(
                      available ? Icons.verified_rounded : Icons.schedule_rounded,
                      size: 18,
                      color: available ? AppTheme.success : AppTheme.warning,
                    ),
                  ],
                ),
              ],
            ),
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
                    if (info?.supportWhatsApp.trim().isNotEmpty ?? false) ...<Widget>[
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
  final VoidCallback onBuy;
  final VoidCallback onRestore;
  final VoidCallback onPreviewContinue;

  const _ActionBar({
    required this.busy,
    required this.selected,
    required this.canBuy,
    required this.previewMode,
    required this.directMode,
    required this.onBuy,
    required this.onRestore,
    required this.onPreviewContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FilledButton.icon(
          onPressed: canBuy ? onBuy : null,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(directMode ? Icons.receipt_long_rounded : Icons.lock_open_rounded),
          label: Text(
            busy
                ? 'Processing'
                : directMode
                    ? 'Submit Payment Reference'
                    : 'Subscribe',
          ),
        ),
        if (!directMode) ...<Widget>[
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
