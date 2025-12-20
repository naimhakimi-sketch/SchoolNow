import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OsrmRoute {
  final List<LatLng> geometry;
  final List<String> steps;

  const OsrmRoute({
    required this.geometry,
    required this.steps,
  });
}

class OsrmRoutingService {
  // Public/demo OSRM endpoint (free, no key). Not SLA-backed.
  static const String _baseUrl = 'https://router.project-osrm.org';

  Future<List<LatLng>> routeDriving(List<LatLng> points) async {
    final r = await routeDrivingWithSteps(points, includeSteps: false);
    return r?.geometry ?? const [];
  }

  Future<OsrmRoute?> routeDrivingWithSteps(
    List<LatLng> points, {
    required bool includeSteps,
  }) async {
    if (points.length < 2) return null;

    // OSRM supports many waypoints, but keeping it conservative helps reliability.
    if (points.length > 25) {
      // Fallback: caller can draw straight-line polyline.
      return null;
    }

    final coords = points
        .map(
          (p) =>
              '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}',
        )
        .join(';');

    final uri = Uri.parse(
      '$_baseUrl/route/v1/driving/$coords'
      '?overview=full&geometries=geojson&steps=${includeSteps ? 'true' : 'false'}',
    );

    final resp = await http.get(
      uri,
      headers: const {
        // Not strictly required, but good practice for public services.
        'User-Agent': 'school_now/1.0 (routing; flutter_map)',
      },
    );

    if (resp.statusCode != 200) {
      throw Exception('OSRM route failed (${resp.statusCode})');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw Exception('Invalid OSRM response');
    }

    if ((decoded['code'] ?? '').toString() != 'Ok') {
      throw Exception('OSRM error: ${(decoded['code'] ?? '').toString()}');
    }

    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty) {
      throw Exception('OSRM returned no routes');
    }

    final route0 = routes.first;
    if (route0 is! Map) {
      throw Exception('Invalid OSRM route');
    }

    final geometry = route0['geometry'];
    if (geometry is! Map) {
      throw Exception('OSRM missing geometry');
    }

    final coordinates = geometry['coordinates'];
    if (coordinates is! List) {
      throw Exception('OSRM geometry missing coordinates');
    }

    final out = <LatLng>[];
    for (final c in coordinates) {
      if (c is List && c.length >= 2) {
        final lon = (c[0] as num?)?.toDouble();
        final lat = (c[1] as num?)?.toDouble();
        if (lat != null && lon != null) {
          out.add(LatLng(lat, lon));
        }
      }
    }

    final steps = <String>[];
    if (includeSteps) {
      final legs = route0['legs'];
      if (legs is List) {
        for (final leg in legs) {
          if (leg is! Map) continue;
          final legSteps = leg['steps'];
          if (legSteps is! List) continue;
          for (final s in legSteps) {
            if (s is! Map) continue;
            final maneuver = s['maneuver'];
            final name = (s['name'] ?? '').toString();
            String instruction = '';
            if (maneuver is Map) {
              instruction = (maneuver['instruction'] ?? '').toString();
              if (instruction.isEmpty) {
                final type = (maneuver['type'] ?? '').toString();
                final modifier = (maneuver['modifier'] ?? '').toString();
                instruction = [
                  if (type.isNotEmpty) type,
                  if (modifier.isNotEmpty) modifier,
                ].join(' ');
              }
            }
            if (instruction.isEmpty) {
              instruction = name.isNotEmpty ? 'Continue on $name' : 'Continue';
            } else if (name.isNotEmpty &&
                !instruction.toLowerCase().contains(name.toLowerCase())) {
              instruction = '$instruction onto $name';
            }

            final distance = (s['distance'] as num?)?.toDouble();
            if (distance != null && distance.isFinite && distance >= 20) {
              final meters = distance.round();
              steps.add('$instruction (${meters}m)');
            } else {
              steps.add(instruction);
            }
          }
        }
      }
    }

    return OsrmRoute(geometry: out, steps: steps);
  }
}
