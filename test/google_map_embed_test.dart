import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:locmate/widgets/google_map_embed.dart';

void main() {
  group('GoogleMapEmbed.uriFor', () {
    test('builds a keyless embed URL for the coordinate', () {
      final uri = GoogleMapEmbed.uriFor(
        center: const LatLng(14.599512, 120.984222),
        zoom: 15.6,
      );

      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps');
      expect(uri.queryParameters['q'], '14.599512,120.984222');
      expect(uri.queryParameters['z'], '16');
      expect(uri.queryParameters['hl'], 'en');
      expect(uri.queryParameters['output'], 'embed');
      expect(uri.toString(), isNot(contains('key=')));
    });

    test('clamps the zoom to the supported range', () {
      final tooClose = GoogleMapEmbed.uriFor(
        center: const LatLng(0, 0),
        zoom: 99,
      );
      final tooFar = GoogleMapEmbed.uriFor(
        center: const LatLng(0, 0),
        zoom: 0,
      );

      expect(tooClose.queryParameters['z'], '20');
      expect(tooFar.queryParameters['z'], '1');
    });
  });
}
