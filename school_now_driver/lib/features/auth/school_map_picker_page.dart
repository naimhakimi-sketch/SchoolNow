import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';
import 'dart:convert';

class SchoolMapPickerResult {
  final double lat;
  final double lng;

  const SchoolMapPickerResult({required this.lat, required this.lng});
}

class SchoolMapPickerPage extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const SchoolMapPickerPage({
    super.key,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<SchoolMapPickerPage> createState() => _SchoolMapPickerPageState();
}

class _SchoolMapPickerPageState extends State<SchoolMapPickerPage> {
  final _mapController = MapController();
  final Location _location = Location();
  final _searchController = TextEditingController();
  LatLng? _selected;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _selected = LatLng(widget.initialLat!, widget.initialLng!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onTap(LatLng pos) {
    setState(() {
      _selected = pos;
    });
  }

  Future<void> _confirm() async {
    final selected = _selected;
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tap on the map to select the school location.')),
      );
      return;
    }

    Navigator.of(context).pop(
      SchoolMapPickerResult(lat: selected.latitude, lng: selected.longitude),
    );
  }

  Future<void> _searchSchool() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
    });

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'limit': '1',
        'addressdetails': '0',
      });

      final resp = await http.get(
        uri,
        headers: const {
          // Nominatim requires a valid User-Agent identifying the app.
          'User-Agent': 'school_now_driver/1.0 (flutter_map search)',
        },
      );

      if (!mounted) return;

      if (resp.statusCode != 200) {
        throw Exception('Search failed (${resp.statusCode})');
      }

      final decoded = jsonDecode(resp.body);
      if (decoded is! List || decoded.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No results found. Try a different school name.')),
          );
        }
        return;
      }

      final first = decoded.first;
      final lat = double.tryParse(first['lat']?.toString() ?? '');
      final lon = double.tryParse(first['lon']?.toString() ?? '');
      if (lat == null || lon == null) {
        throw Exception('Invalid search result');
      }

      final point = LatLng(lat, lon);
      if (mounted) {
        setState(() {
          _selected = point;
        });

        _mapController.move(point, 15);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
        });
      }
    }
  }

  Future<void> _centerOnMyLocation() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return;
      }
      PermissionStatus permission = await _location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _location.requestPermission();
        if (permission != PermissionStatus.granted) return;
      }

      final loc = await _location.getLocation();
      final lat = (loc.latitude ?? 0).toDouble();
      final lng = (loc.longitude ?? 0).toDouble();
      if (!mounted) return;

      _mapController.move(LatLng(lat, lng), 15);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select School Location'),
        actions: [
          TextButton(
            onPressed: _confirm,
            child: const Text('Confirm'),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: selected ?? const LatLng(0, 0),
              initialZoom: selected != null ? 15 : 2,
              onTap: (tapPosition, point) => _onTap(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'school_now_driver',
              ),
              if (selected != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: selected,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search school name (e.g., SMK ABC)',
                          border: InputBorder.none,
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _searching ? null : _searchSchool(),
                      ),
                    ),
                    IconButton(
                      onPressed: _searching ? null : _searchSchool,
                      icon: _searching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 110,
            child: FloatingActionButton.small(
              onPressed: _centerOnMyLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected == null
                          ? 'Tap to drop a pin for the school.'
                          : 'Selected: ${selected.latitude.toStringAsFixed(6)}, ${selected.longitude.toStringAsFixed(6)}',
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Map data © OpenStreetMap contributors',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
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
