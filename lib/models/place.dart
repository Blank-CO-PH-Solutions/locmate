import 'package:latlong2/latlong.dart';

class Place {
  const Place({
    required this.id,
    required this.name,
    required this.address,
    required this.icon,
    required this.point,
    this.radiusMeters = 180,
  });

  final String id;
  final String name;
  final String address;
  final String icon;
  final LatLng point;
  final double radiusMeters;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'icon': icon,
        'lat': point.latitude,
        'lng': point.longitude,
        'radius': radiusMeters,
      };

  factory Place.fromJson(Map<String, dynamic> json) => Place(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String? ?? '',
        icon: json['icon'] as String? ?? 'other',
        point: LatLng(
          (json['lat'] as num).toDouble(),
          (json['lng'] as num).toDouble(),
        ),
        radiusMeters: (json['radius'] as num?)?.toDouble() ?? 180,
      );
}
