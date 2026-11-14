import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config.dart';

/// Thin wrapper around RevenueCat. Purchases go through the App Store or
/// Google Play. RevenueCat then notifies the `revenuecat-webhook` Edge
/// Function, which marks the user as Premium in Supabase.
class SubscriptionService {
  SubscriptionService._();

  static final SubscriptionService instance = SubscriptionService._();

  bool _configured = false;
  String? _loggedInUserId;

  String? get _apiKey {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS =>
        RevenueCatConfig.appleApiKey.isEmpty
            ? null
            : RevenueCatConfig.appleApiKey,
      TargetPlatform.android =>
        RevenueCatConfig.googleApiKey.isEmpty
            ? null
            : RevenueCatConfig.googleApiKey,
      _ => null,
    };
  }

  /// RevenueCat runs on iOS, macOS and Android. Linux and Windows builds
  /// (and builds without an API key) show the plans but can't purchase.
  bool get isSupported => _apiKey != null;

  Future<void> ensureConfigured(String userId) async {
    final key = _apiKey;
    if (key == null) {
      throw StateError('Subscriptions are not available on this device.');
    }
    if (!_configured) {
      await Purchases.configure(PurchasesConfiguration(key)..appUserID = userId);
      _configured = true;
      _loggedInUserId = userId;
    } else if (_loggedInUserId != userId) {
      await Purchases.logIn(userId);
      _loggedInUserId = userId;
    }
  }

  Future<void> logOut() async {
    if (!_configured || _loggedInUserId == null) return;
    try {
      await Purchases.logOut();
    } catch (_) {
      // Already anonymous.
    }
    _loggedInUserId = null;
  }

  Future<List<Package>> packages() async {
    final offerings = await Purchases.getOfferings();
    return offerings.current?.availablePackages ?? const [];
  }

  bool isPremium(CustomerInfo info) =>
      info.entitlements.active.containsKey(RevenueCatConfig.entitlementId);

  /// Returns true when the purchase unlocked Premium, false when the user
  /// cancelled.
  Future<bool> purchase(Package package) async {
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      return isPremium(result.customerInfo);
    } on PlatformException catch (error) {
      if (PurchasesErrorHelper.getErrorCode(error) ==
          PurchasesErrorCode.purchaseCancelledError) {
        return false;
      }
      rethrow;
    }
  }

  Future<bool> restore() async => isPremium(await Purchases.restorePurchases());

  Future<String?> managementUrl() async =>
      (await Purchases.getCustomerInfo()).managementURL;
}
