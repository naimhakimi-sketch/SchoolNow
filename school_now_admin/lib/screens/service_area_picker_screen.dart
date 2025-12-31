import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ServiceAreaPickerScreen extends StatefulWidget {
  final String? initialSchoolId;
  final Map<String, dynamic>? initialServiceArea;

  const ServiceAreaPickerScreen({
    super.key,
    this.initialSchoolId,
    this.initialServiceArea,
  });

  @override
  State<ServiceAreaPickerScreen> createState() =>
      _ServiceAreaPickerScreenState();
}

class _ServiceAreaPickerScreenState extends State<ServiceAreaPickerScreen> {
  final _mapController = MapController();
  LatLng _center = const LatLng(3.1390, 101.6869); // Default: KL
  double _radiusKm = 10.0;

  @override
  void initState() {
    super.initState();
    if (widget.initialServiceArea != null) {
      _center = LatLng(
        widget.initialServiceArea!['center_lat'] as double,
        widget.initialServiceArea!['center_lng'] as double,
      );
      _radiusKm = (widget.initialServiceArea!['radius_km'] as num).toDouble();
    }
  }

  void _confirm() {
    Navigator.pop(context, {
      'school_id': widget.initialSchoolId,
      'center_lat': _center.latitude,
      'center_lng': _center.longitude,
      'radius_km': _radiusKm,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Service Area'),
        actions: [
          TextButton(
            onPressed: _confirm,
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 12,
              onTap: (_, latlng) {
                setState(() {
                  _center = latlng;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.school_now_admin',
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _center,
                    radius: _radiusKm * 1000, // Convert km to meters
                    useRadiusInMeter: true,
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderColor: Colors.blue,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _center,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Service Radius: ${_radiusKm.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Slider(
                      value: _radiusKm,
                      min: 1,
                      max: 50,
                      divisions: 49,
                      label: '${_radiusKm.toStringAsFixed(1)} km',
                      onChanged: (v) {
                        setState(() {
                          _radiusKm = v;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap on map to set center point',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
