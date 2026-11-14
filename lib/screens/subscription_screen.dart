import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../screens/legal_screen.dart';
import '../services/subscription_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';

/// Paywall and subscription management. The purchase itself is handled by the
/// App Store or Google Play through RevenueCat; Supabase stores the resulting
/// plan so the database can enforce the Free limits.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final SubscriptionService _service = SubscriptionService.instance;

  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _managementUrl;
  List<Package> _packages = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    final userId = state.userId;
    if (!_service.isSupported || userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _service.ensureConfigured(userId);
      final packages = await _service.packages();
      if (!mounted) return;
      setState(() => _packages = packages);

      await state.refreshPlan();
      if (!state.circlePremium) {
        try {
          final url = await _service.managementUrl();
          if (mounted) _managementUrl = url;
        } catch (_) {
          // The store only returns a management URL for an active purchase.
        }
      }
    } catch (error) {
      if (mounted) _error = friendlyError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _buy(Package package) async {
    final state = context.read<AppState>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final premium = await _service.purchase(package);
      if (!mounted) return;
      if (premium) {
        await state.refreshPlan(waitForPremium: true);
        if (!mounted) return;
        _showMessage('Premium is active. Thank you for supporting Locmate!');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyError(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final state = context.read<AppState>();
    final userId = state.userId;
    if (!_service.isSupported || userId == null) {
      _showMessage('Restore is available in the iOS and Android apps.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.ensureConfigured(userId);
      final premium = await _service.restore();
      await state.refreshPlan(waitForPremium: premium);
      if (!mounted) return;
      _showMessage(
        premium
            ? 'Your Premium subscription was restored.'
            : 'No active subscription was found for this store account.',
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyError(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _manage() async {
    if (!_service.isSupported) {
      _showMessage('Manage your subscription in the App Store or Google Play.');
      return;
    }
    setState(() => _busy = true);
    try {
      final url = _managementUrl ?? await _service.managementUrl();
      if (!mounted) return;
      if (url == null || url.isEmpty) {
        _showMessage(
          'Open the App Store or Google Play to manage this subscription.',
        );
        return;
      }
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        _showMessage('Could not open the store. Try again from your profile.');
      }
    } catch (error) {
      if (mounted) _showMessage(friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openLegal(LegalDocument document) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LegalScreen(document: document)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final owner = state.memberById(state.circle?.ownerId);
    final canUpgrade = state.isOwner && !state.circlePremium;
    final active = state.circlePremium;

    return Scaffold(
      appBar: AppBar(title: const Text('Locmate Premium')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
            children: [
              _PremiumHero(active: active),
              const SizedBox(height: 16),
              SurfaceCard(
                padding: const EdgeInsets.all(14),
                color: active
                    ? LocmateColors.safe.withValues(alpha: 0.08)
                    : scheme.primary.withValues(alpha: 0.06),
                borderColor: active
                    ? LocmateColors.safe.withValues(alpha: 0.25)
                    : scheme.primary.withValues(alpha: 0.18),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (active ? LocmateColors.safe : scheme.primary)
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        active
                            ? Icons.verified_rounded
                            : Icons.people_outline_rounded,
                        size: 21,
                        color: active ? LocmateColors.safe : scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            active ? 'Premium is active' : 'Free plan',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            active
                                ? 'Your circle has unlimited members and places.'
                                : 'Up to ${PlanLimits.freeMembers} members and '
                                      '${PlanLimits.freePlaces} places per circle.',
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.35,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (active && _service.isSupported)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _manage,
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('Manage subscription'),
                  ),
                ),
              if (!state.isOwner) ...[
                const SizedBox(height: 14),
                SurfaceCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Only the circle owner can make this circle Premium. '
                          '${owner == null ? 'Ask the owner to upgrade.' : 'Ask ${owner.firstName} to upgrade.'}',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.4,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SectionLabel('What you get'),
              SurfaceCard(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                child: Column(
                  children: const [
                    _Benefit(
                      icon: Icons.groups_rounded,
                      title: 'Unlimited circle members',
                      subtitle:
                          'The Free plan includes ${PlanLimits.freeMembers} people.',
                    ),
                    _Benefit(
                      icon: Icons.place_rounded,
                      title: 'Unlimited places',
                      subtitle:
                          'The Free plan includes ${PlanLimits.freePlaces} places.',
                    ),
                    _Benefit(
                      icon: Icons.battery_alert_rounded,
                      title: 'Low-battery alerts',
                      subtitle:
                          'Know when someone in your circle needs to charge.',
                    ),
                    _Benefit(
                      icon: Icons.favorite_rounded,
                      title: 'Support Locmate',
                      subtitle:
                          'Your subscription keeps the map and alerts running.',
                      isLast: true,
                    ),
                  ],
                ),
              ),
              if (canUpgrade) ...[
                const SectionLabel('Choose a plan'),
                if (!_service.isSupported)
                  SurfaceCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Purchases are available in the mobile apps',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Subscribe from Locmate on iOS or Android. Your '
                          'Premium plan then applies to this circle everywhere '
                          'you sign in.',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.4,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_loading)
                  const SurfaceCard(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                    ),
                  )
                else if (_packages.isEmpty)
                  SurfaceCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Plans are not available right now',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Check your connection and try again. If this '
                          'continues, the store products have not been '
                          'published yet.',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.4,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _loading ? null : _load,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  )
                else
                  for (final package in _packages)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PackageCard(
                        package: package,
                        busy: _busy,
                        onBuy: () => _buy(package),
                      ),
                    ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(
                    message: _error!,
                    onDismiss: () => setState(() => _error = null),
                  ),
                ],
                if (_service.isSupported)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: TextButton(
                      onPressed: _busy ? null : _restore,
                      child: const Text('Restore purchases'),
                    ),
                  ),
              ],
              const SizedBox(height: 14),
              Text.rich(
                TextSpan(
                  text:
                      'Payment is charged to your App Store or Google Play '
                      'account. Premium renews automatically unless cancelled '
                      'at least 24 hours before the period ends. You can cancel '
                      'any time in your store account. See the ',
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.5,
                    color: scheme.onSurfaceVariant,
                  ),
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: _LegalLink(
                        label: 'Terms of Service',
                        onTap: () => _openLegal(LegalDocument.terms),
                      ),
                    ),
                    const TextSpan(text: ' and '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: _LegalLink(
                        label: 'Privacy Policy',
                        onTap: () => _openLegal(LegalDocument.privacy),
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Text(
                LegalInfo.copyright,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumHero extends StatelessWidget {
  const _PremiumHero({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: active
              ? const [Color(0xFF0F8A62), LocmateColors.safe]
              : const [
                  LocmateColors.primaryDeep,
                  LocmateColors.primary,
                  Color(0xFF9B5CF6),
                ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  active
                      ? Icons.verified_rounded
                      : Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  active ? 'You’re Premium' : 'Locmate Premium',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            active
                ? 'Thank you for keeping your circle connected. Your plan is '
                      'active on every device where you sign in.'
                : 'More room for your circle, more places on the map, and '
                      'low-battery alerts when someone needs a charge.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 10, 0, isLast ? 10 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: scheme.primary),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.package,
    required this.busy,
    required this.onBuy,
  });

  final Package package;
  final bool busy;
  final VoidCallback onBuy;

  String get _label => switch (package.packageType) {
    PackageType.monthly => 'Monthly',
    PackageType.annual => 'Yearly',
    PackageType.sixMonth => '6 months',
    PackageType.threeMonth => '3 months',
    PackageType.twoMonth => '2 months',
    PackageType.weekly => 'Weekly',
    PackageType.lifetime => 'Lifetime',
    PackageType.custom || PackageType.unknown => package.identifier,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final product = package.storeProduct;
    final featured = package.packageType == PackageType.annual;
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      borderColor: featured ? scheme.primary.withValues(alpha: 0.45) : null,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              featured ? Icons.star_rounded : Icons.workspace_premium_outlined,
              color: scheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (featured) ...[
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'BEST VALUE',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  product.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  product.priceString,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: busy ? null : onBuy,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Choose'),
          ),
        ],
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          height: 1.5,
          fontWeight: FontWeight.w700,
          color: scheme.primary,
          decoration: TextDecoration.underline,
          decorationColor: scheme.primary,
        ),
      ),
    );
  }
}
