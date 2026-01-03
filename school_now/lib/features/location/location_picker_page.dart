import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

class LocationPickerPage extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationPickerPage({super.key, this.initialLocation});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final _mapController = MapController();
  final Location _location = Location();
  late final TextEditingController _searchController;

  LatLng? _selected;
  String? _selectedAddress;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    if (widget.initialLocation != null) {
      _selected = widget.initialLocation;
      _reverseGeocode(widget.initialLocation!);
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
    _reverseGeocode(pos);
  }

  Future<void> _reverseGeocode(LatLng location) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': location.latitude.toString(),
        'lon': location.longitude.toString(),
        'format': 'json',
      });

      final resp = await http.get(
        uri,
        headers: const {'User-Agent': 'school_now/1.0 (location picker)'},
      );

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (mounted) {
          setState(() {
            _selectedAddress = decoded['display_name']?.toString() ?? '';
          });
        }
      }
    } catch (e) {
      // Silently fail for reverse geocoding
    }
  }

  Future<void> _confirm() async {
    final selected = _selected;
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tap on the map to select a location.')),
      );
      return;
    }

    Navigator.of(context).pop({
      'lat': selected.latitude,
      'lng': selected.longitude,
      'address':
          _selectedAddress ??
          '${selected.latitude.toStringAsFixed(6)}, ${selected.longitude.toStringAsFixed(6)}',
    });
  }

  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
    });

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'limit': '5',
        'addressdetails': '1',
      });

      final resp = await http.get(
        uri,
        headers: const {'User-Agent': 'school_now/1.0 (location picker)'},
      );

      if (!mounted) return;

      if (resp.statusCode != 200) {
        throw Exception('Search failed (${resp.statusCode})');
      }

      final decoded = jsonDecode(resp.body);
      if (decoded is! List || decoded.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No results found. Try a more specific address.'),
          ),
        );
        return;
      }

      final first = decoded.first;
      final lat = double.tryParse(first['lat']?.toString() ?? '');
      final lon = double.tryParse(first['lon']?.toString() ?? '');
      final displayName = first['display_name']?.toString();

      if (lat == null || lon == null) {
        throw Exception('Invalid search result');
      }

      final point = LatLng(lat, lon);
      setState(() {
        _selected = point;
        _selectedAddress = displayName ?? query;
      });

      _mapController.move(point, 17);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Search error: $e')));
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

      final point = LatLng(lat, lng);
      setState(() {
        _selected = point;
      });
      _reverseGeocode(point);
      _mapController.move(point, 17);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Location error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Pickup Location'),
        actions: [
          TextButton(onPressed: _confirm, child: const Text('Confirm')),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  selected ??
                  const LatLng(3.1390, 101.6869), // Default to Malaysia
              initialZoom: selected != null ? 17 : 10,
              onTap: (tapPosition, point) => _onTap(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'school_now',
              ),
              if (selected != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: selected,
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
            left: 12,
            right: 12,
            top: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search address',
                          border: InputBorder.none,
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) =>
                            _searching ? null : _searchAddress(),
                      ),
                    ),
                    IconButton(
                      onPressed: _searching ? null : _searchAddress,
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
                          ? 'Search an address or tap on the map to select a location.'
                          : 'Selected: ${selected.latitude.toStringAsFixed(6)}, ${selected.longitude.toStringAsFixed(6)}',
                    ),
                    if ((_selectedAddress ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _selectedAddress!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
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
