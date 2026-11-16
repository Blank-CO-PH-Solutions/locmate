import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config.dart';

/// A place returned by OpenStreetMap Nominatim.
class GeocodedAddress {
  const GeocodedAddress({
    required this.formattedAddress,
    required this.point,
    this.placeId,
  });

  final String formattedAddress;
  final LatLng point;
  final String? placeId;
}

/// A place lookup failure with a message that can be shown to users.
class PlaceSearchException implements Exception {
  const PlaceSearchException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Keyless map helpers used by the app.
///
/// The map itself is rendered with OpenStreetMap tiles via `flutter_map`.
/// Place addresses come from OpenStreetMap Nominatim, and the universal
/// `google.com/maps` URLs open turn-by-turn directions in the user's installed
/// Google Maps app or browser. None of these require an API key or billing.
class MapsService {
  const MapsService._();

  static const Map<String, String> _headers = {
    'User-Agent': MapsConfig.userAgent,
    'Accept': 'application/json',
  };

  /// Opens driving/walking directions to [destination]. When [origin] is
  /// supplied, Google Maps keeps the user's actual route start instead of
  /// asking for their current position.
  static Uri directionsUri({
    required LatLng destination,
    LatLng? origin,
    String travelMode = 'driving',
  }) {
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': _latLng(destination),
      'travelmode': travelMode,
      if (origin != null) 'origin': _latLng(origin),
    });
  }

  /// Opens a single coordinate in Google Maps.
  static Uri placeUri(LatLng point, {String? label}) {
    if (label != null && label.trim().isNotEmpty) {
      return Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': '${_latLng(point)} (${label.trim()})',
      });
    }
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': _latLng(point),
    });
  }

  /// Converts a coordinate to the closest street address.
  static Future<GeocodedAddress?> reverseGeocode(
    LatLng point, {
    http.Client? client,
  }) async {
    final body = await _getJson(
      Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': point.latitude.toStringAsFixed(6),
        'lon': point.longitude.toStringAsFixed(6),
        'format': 'jsonv2',
        'zoom': '18',
        'addressdetails': '1',
        'accept-language': 'en',
        'email': MapsConfig.contactEmail,
      }),
      client: client,
    );
    if (body is! Map) return null;
    final error = body['error'];
    if (error is String && error.isNotEmpty) return null;
    return _parse(body);
  }

  /// Looks up an address typed by the user. The first result is usually the
  /// best match.
  static Future<List<GeocodedAddress>> searchAddress(
    String query, {
    http.Client? client,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final body = await _getJson(
      Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': trimmed,
        'format': 'jsonv2',
        'limit': '5',
        'addressdetails': '1',
        'accept-language': 'en',
        'email': MapsConfig.contactEmail,
      }),
      client: client,
    );
    if (body is! List) {
      throw const PlaceSearchException(
        'OpenStreetMap returned an unexpected response.',
      );
    }
    return [
      for (final row in body)
        if (row is Map) ?_parse(row),
    ];
  }

  static Future<Object?> _getJson(Uri uri, {http.Client? client}) async {
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw PlaceSearchException(
          'Address lookup is unavailable right now '
          '(HTTP ${response.statusCode}).',
        );
      }
      try {
        return jsonDecode(response.body);
      } on FormatException {
        throw const PlaceSearchException(
          'OpenStreetMap returned an unexpected response.',
        );
      }
    } on PlaceSearchException {
      rethrow;
    } catch (_) {
      throw const PlaceSearchException(
        'Could not reach OpenStreetMap. Check your internet connection.',
      );
    } finally {
      if (client == null) httpClient.close();
    }
  }

  static GeocodedAddress? _parse(Map row) {
    final lat = double.tryParse('${row['lat']}');
    final lng = double.tryParse('${row['lon']}');
    if (lat == null || lng == null) return null;
    final display = row['display_name'];
    final point = LatLng(lat, lng);
    final placeId = row['place_id'];
    return GeocodedAddress(
      formattedAddress: display is String && display.trim().isNotEmpty
          ? display.trim()
          : _latLng(point),
      point: point,
      placeId: placeId?.toString(),
    );
  }

  static String _latLng(LatLng point) =>
      '${point.latitude.toStringAsFixed(6)},'
      '${point.longitude.toStringAsFixed(6)}';
}
