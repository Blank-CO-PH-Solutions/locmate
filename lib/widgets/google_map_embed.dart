import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Interactive Google Maps view built from the public, keyless
/// `output=embed` URL and rendered in a WebView (Android/iOS) or iframe (web).
///
/// The embed intentionally trades the Maps SDK's markers and camera API for a
/// zero-configuration setup: it needs no API key, billing account or platform
/// SDK. Only one location (the current [center]) is shown at a time.
class GoogleMapEmbed extends StatefulWidget {
  const GoogleMapEmbed({super.key, required this.center, this.zoom = 15});

  /// Location shown by the map.
  final LatLng center;

  /// Google Maps zoom level (higher is closer).
  final double zoom;

  /// Builds the keyless embed URL used by the WebView/iframe.
  static Uri uriFor({required LatLng center, double zoom = 15}) {
    return Uri.https('www.google.com', '/maps', {
      'q':
          '${center.latitude.toStringAsFixed(6)},'
          '${center.longitude.toStringAsFixed(6)}',
      'z': '${zoom.clamp(1, 20).round()}',
      'hl': 'en',
      'output': 'embed',
    });
  }

  @override
  State<GoogleMapEmbed> createState() => _GoogleMapEmbedState();
}

class _GoogleMapEmbedState extends State<GoogleMapEmbed> {
  WebViewController? _controller;
  late Uri _uri;

  @override
  void initState() {
    super.initState();
    _uri = GoogleMapEmbed.uriFor(center: widget.center, zoom: widget.zoom);
    final controller = WebViewController();
    if (!kIsWeb) {
      // These APIs are not implemented by the web (iframe) implementation.
      controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF1D1B26))
        ..setNavigationDelegate(
          NavigationDelegate(onNavigationRequest: _onNavigationRequest),
        );
    }
    _controller = controller;
    unawaited(controller.loadRequest(_uri));
  }

  @override
  void didUpdateWidget(covariant GoogleMapEmbed oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = GoogleMapEmbed.uriFor(
      center: widget.center,
      zoom: widget.zoom,
    );
    if (next != _uri) {
      _uri = next;
      unawaited(_controller?.loadRequest(next) ?? Future<void>.value());
    }
  }

  /// Keeps Google's own pages (including consent and assets) in the view and
  /// opens any other link in the user's browser.
  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    if (_isGoogleHost(uri.host)) return NavigationDecision.navigate;
    unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
    return NavigationDecision.prevent;
  }

  static bool _isGoogleHost(String host) =>
      host == 'google.com' ||
      host.endsWith('.google.com') ||
      host.endsWith('.gstatic.com') ||
      host.endsWith('.googleapis.com');

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return ColoredBox(
      color: const Color(0xFF1D1B26),
      child: SizedBox.expand(child: WebViewWidget(controller: controller)),
    );
  }
}
