import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:locmate/services/maps_service.dart';

void main() {
  group('MapsService deep links', () {
    test('directions URI includes origin, destination and travel mode', () {
      final uri = MapsService.directionsUri(
        destination: const LatLng(14.599512, 120.984222),
        origin: const LatLng(14.6042, 120.9822),
        travelMode: 'walking',
      );

      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['destination'], '14.599512,120.984222');
      expect(uri.queryParameters['origin'], '14.604200,120.982200');
      expect(uri.queryParameters['travelmode'], 'walking');
    });

    test('directions URI omits the origin when it is unknown', () {
      final uri = MapsService.directionsUri(destination: const LatLng(1, 2));

      expect(uri.queryParameters.containsKey('origin'), isFalse);
    });

    test('place URI uses a labelled search', () {
      final uri = MapsService.placeUri(const LatLng(1.5, 2.5), label: 'Home');

      expect(uri.path, '/maps/search/');
      expect(uri.queryParameters['query'], '1.500000,2.500000 (Home)');
    });
  });

  group('MapsService place lookup', () {
    test('parses a reverse geocoding result from Nominatim', () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'nominatim.openstreetmap.org');
        expect(request.url.path, '/reverse');
        expect(request.url.queryParameters['lat'], '1.500000');
        expect(request.url.queryParameters['lon'], '2.500000');
        expect(request.url.queryParameters['format'], 'jsonv2');
        expect(request.headers['User-Agent'], isNotEmpty);
        return http.Response(
          jsonEncode({
            'place_id': 123456,
            'lat': '1.5',
            'lon': '2.5',
            'display_name': '1 Example Street, Test City',
          }),
          200,
        );
      });

      final result = await MapsService.reverseGeocode(
        const LatLng(1.5, 2.5),
        client: client,
      );

      expect(result, isNotNull);
      expect(result!.formattedAddress, '1 Example Street, Test City');
      expect(result.point.latitude, 1.5);
      expect(result.point.longitude, 2.5);
      expect(result.placeId, '123456');
    });

    test('returns null when a coordinate has no address', () async {
      final client = MockClient(
        (request) async =>
            http.Response(jsonEncode({'error': 'Unable to geocode'}), 200),
      );

      expect(
        await MapsService.reverseGeocode(const LatLng(0, 0), client: client),
        isNull,
      );
    });

    test('searchAddress sends the trimmed address', () async {
      late Uri requested;
      final client = MockClient((request) async {
        requested = request.url;
        return http.Response(
          jsonEncode([
            {
              'place_id': 42,
              'lat': '51.5034',
              'lon': '-0.1276',
              'display_name': '10 Downing Street, London, England',
            },
          ]),
          200,
        );
      });

      final results = await MapsService.searchAddress(
        '  10 Downing Street  ',
        client: client,
      );

      expect(requested.path, '/search');
      expect(requested.queryParameters['q'], '10 Downing Street');
      expect(requested.queryParameters['limit'], '5');
      expect(results, hasLength(1));
      expect(
        results.single.formattedAddress,
        '10 Downing Street, London, England',
      );
    });

    test('empty searches do not call the API', () async {
      var called = false;
      final client = MockClient((request) async {
        called = true;
        return http.Response('[]', 200);
      });

      expect(await MapsService.searchAddress('   ', client: client), isEmpty);
      expect(called, isFalse);
    });

    test('HTTP failures surface a readable message', () async {
      final client = MockClient(
        (request) async => http.Response('rate limited', 503),
      );

      expect(
        () => MapsService.reverseGeocode(const LatLng(1, 2), client: client),
        throwsA(
          isA<PlaceSearchException>().having(
            (error) => error.message,
            'message',
            contains('HTTP 503'),
          ),
        ),
      );
    });

    test('malformed responses surface a readable message', () async {
      final client = MockClient(
        (request) async => http.Response('not json', 200),
      );

      expect(
        () => MapsService.searchAddress('Manila', client: client),
        throwsA(
          isA<PlaceSearchException>().having(
            (error) => error.message,
            'message',
            contains('unexpected response'),
          ),
        ),
      );
    });
  });
}
