import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class HomeAddressPickerResult {
  final double lat;
  final double lng;
  final String displayName;

  const HomeAddressPickerResult({
    required this.lat,
    required this.lng,
    required this.displayName,
  });
}

class HomeAddressPickerPage extends StatefulWidget {
  final String? initialQuery;
  final double? initialLat;
  final double? initialLng;

  const HomeAddressPickerPage({
    super.key,
    this.initialQuery,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<HomeAddressPickerPage> createState() => _HomeAddressPickerPageState();
}

class _HomeAddressPickerPageState extends State<HomeAddressPickerPage> {
  final _mapController = MapController();
  late final TextEditingController _searchController;

  LatLng? _selected;
  String? _selectedDisplayName;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
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
        const SnackBar(content: Text('Tap on the map to select your home location.')),
      );
      return;
    }

    Navigator.of(context).pop(
      HomeAddressPickerResult(
        lat: selected.latitude,
        lng: selected.longitude,
        displayName: _selectedDisplayName ?? _searchController.text.trim(),
      ),
    );
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
        'limit': '1',
        'addressdetails': '0',
      });

      final resp = await http.get(
        uri,
        headers: const {'User-Agent': 'school_now/1.0 (home address picker)'},
      );

      if (!mounted) return;

      if (resp.statusCode != 200) {
        throw Exception('Search failed (${resp.statusCode})');
      }

      final decoded = jsonDecode(resp.body);
      if (decoded is! List || decoded.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No results found. Try a more specific address.')),
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
        _selectedDisplayName = displayName ?? query;
      });

      _mapController.move(point, 17);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Pickup Point'),
        actions: [
          TextButton(onPressed: _confirm, child: const Text('Confirm')),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: selected ?? const LatLng(0, 0),
              initialZoom: selected != null ? 17 : 2,
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
                      child: const Icon(Icons.home, color: Colors.indigo, size: 40),
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
                          hintText: 'Search address (type full address)',
                          border: InputBorder.none,
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _searching ? null : _searchAddress(),
                      ),
                    ),
                    IconButton(
                      onPressed: _searching ? null : _searchAddress,
                      icon: _searching
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.search),
                    ),
                  ],
                ),
              ),
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
                          ? 'Search your address or tap to drop a pin.'
                          : 'Selected: ${selected.latitude.toStringAsFixed(6)}, ${selected.longitude.toStringAsFixed(6)}',
                    ),
                    if ((_selectedDisplayName ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(_selectedDisplayName!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                    const SizedBox(height: 6),
                    const Text('Map data © OpenStreetMap contributors', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
