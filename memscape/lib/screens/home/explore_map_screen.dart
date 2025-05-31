import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:memscape/models/photo_model.dart';
import 'package:memscape/services/realtime_database_service.dart';

class ExploreMapScreen extends StatefulWidget {
  const ExploreMapScreen({super.key});

  @override
  State<ExploreMapScreen> createState() => _ExploreMapScreenState();
}

class _ExploreMapScreenState extends State<ExploreMapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  List<PhotoModel> _allPhotos = [];
  List<PhotoModel> _filteredPhotos = [];
  LatLng? _userLocation;
  LatLng? _searchLocation;
  String? _searchedCity;
  bool _showSheet = false;
  List<LatLng> _routePoints = [];
  StreamSubscription<Position>? _positionStream;
  double? _userHeading;
  bool _enableMapRotation = false;

  double _calculateBearing(LatLng from, LatLng to) {
    final dLon = to.longitude - from.longitude;
    final y = sin(dLon * pi / 180) * cos(to.latitude * pi / 180);
    final x =
        cos(from.latitude * pi / 180) * sin(to.latitude * pi / 180) -
        sin(from.latitude * pi / 180) *
            cos(to.latitude * pi / 180) *
            cos(dLon * pi / 180);
    final bearing = atan2(y, x);
    return (bearing * 180 / pi + 360) % 360;
  }

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
    _loadUserLocation();
    _fetchPhotos();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  void _startLocationTracking() async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    // _positionStream = Geolocator.getPositionStream(
    //   locationSettings: locationSettings,
    // ).listen((Position position) {
    //   setState(() {
    //     _userLocation = LatLng(position.latitude, position.longitude);
    //     _userHeading = position.heading;
    //   });
    // });
    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      final current = LatLng(position.latitude, position.longitude);

      // Optional fallback: use GPS heading if no route is selected
      double heading = position.heading;

      // if (_routePoints.isNotEmpty) {
      //   final destination = _routePoints.last;
      //   heading = _calculateBearing(current, destination);
      //   // 🔁 Rotate map only when route is active
      //   _mapController.rotate(heading);
      // }

      if (_routePoints.isNotEmpty) {
        final destination = _routePoints.last;
        heading = _calculateBearing(current, destination);

        // 🔄 Rotate map if route is selected
        _mapController.rotate(heading);
      } else {
        // Optional: reset rotation when no route
        _mapController.rotate(0);
      }

      setState(() {
        _userLocation = current;
        _userHeading = heading;
        if (_enableMapRotation) {
          _mapController.rotate(heading); // 🔁 rotate the map to heading
        }
      });
    });
  }

  Future<void> _loadUserLocation() async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;

    final position = await Geolocator.getCurrentPosition();
    final loc = LatLng(position.latitude, position.longitude);

    setState(() {
      _userLocation = LatLng(position.latitude, position.longitude);
      _userLocation = loc;
    });
    // 📍 Move the map to user location with desired zoom (e.g., 12.5)
    _mapController.move(loc, 12.5);
    _mapController.move(_userLocation!, 15); // 🔍 Zoom in nicely
  }

  Future<bool> _handleLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) return false;
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<void> _fetchPhotos() async {
    final data = await FirebaseFirestore.instance.collection('photos').get();

    setState(() {
      _allPhotos =
          data.docs
              .map((doc) {
                final d = doc.data();
                return PhotoModel(
                  caption: d['caption'] ?? '',
                  location: d['location'] ?? '',
                  lat: d['lat'],
                  lng: d['lng'],
                  imagePath: d['imagePath'] ?? '',
                  imageBase64: null, // Will be loaded later if needed
                  uid: d['uid'] ?? '',
                  timestamp:
                      DateTime.tryParse(d['timestamp'] ?? '') ?? DateTime.now(),
                  isPublic: d['isPublic'] ?? false,
                );
              })
              .where((p) => p.lat != null && p.lng != null && p.isPublic)
              .toList();
    });
  }

  Future<void> _searchPlace(String query) async {
    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isEmpty) throw Exception("Location not found");

      final loc = locations.first;
      final LatLng newCenter = LatLng(loc.latitude, loc.longitude);

      final distance = const Distance();
      final matchedPhotos =
          _allPhotos.where((p) {
            if (p.lat == null || p.lng == null) return false;
            final photoPoint = LatLng(p.lat!, p.lng!);
            return distance(newCenter, photoPoint) <= 10000; // within 10 km
          }).toList();

      setState(() {
        _searchLocation = newCenter;
        _searchedCity = query;
        _filteredPhotos = matchedPhotos;
        _showSheet = matchedPhotos.isNotEmpty;
      });

      _mapController.move(newCenter, 13.0);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Place not found.")));
    }
  }

  Future<List<LatLng>> fetchRoute(LatLng start, LatLng end, String mode) async {
    final url =
        'https://router.project-osrm.org/route/v1/$mode/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final coords = data['routes'][0]['geometry']['coordinates'] as List;
      return coords.map((c) => LatLng(c[1] as double, c[0] as double)).toList();
    } else {
      throw Exception('Failed to fetch route');
    }
  }

  Future<void> _drawRoute(String mode, PhotoModel photo) async {
    if (_userLocation == null) return;

    final String baseUrl = 'https://api.openrouteservice.org/v2/directions';
    final String apiKey =
        '5b3ce3597851110001cf6248b16bba8b608b442e8723352c9672c508'; // 🔑 Replace this

    final String profile = switch (mode) {
      'walking' => 'foot-walking',
      'cycling' => 'cycling-regular',
      'driving' => 'driving-car',
      _ => 'foot-walking',
    };

    final String url =
        '$baseUrl/$profile?api_key=$apiKey&start=${_userLocation!.longitude},${_userLocation!.latitude}&end=${photo.lng},${photo.lat}';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final coordinates =
          data['features'][0]['geometry']['coordinates'] as List;

      setState(() {
        _routePoints =
            coordinates
                .map((c) => LatLng(c[1] as double, c[0] as double))
                .toList();
        _enableMapRotation = true; // 🔁 enable map rotation
      });
    } else {
      debugPrint("❌ Route fetch failed: ${response.statusCode}");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Could not fetch route.")));
    }
  }

  void _drawPublicTransitRoute(PhotoModel photo) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Public transit support coming soon.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Explore Memories",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onPrimary,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              onSubmitted: _searchPlace,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: "Search a city or place...",
                hintStyle: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
            ),
          ),
        ),
      ),

      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation ?? const LatLng(20.5937, 78.9629),
              initialZoom: 4.5,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.memscape.app',
              ),
              MarkerLayer(
                markers: [
                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: 40,
                      height: 40,
                      child: Transform.rotate(
                        angle:
                            (_userHeading ?? 0) *
                            (pi / 180), // Convert degrees to radians
                        child: const Icon(
                          Icons.navigation, // 🔺 triangle icon
                          size: 40,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  if (_filteredPhotos.isNotEmpty)
                    ..._filteredPhotos.map(
                      (photo) => Marker(
                        point: LatLng(photo.lat!, photo.lng!),
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onTap: () => _showMemoryDialog(context, photo),
                          child: const Icon(
                            Icons.location_on,
                            size: 40,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              PolylineLayer(
                polylines: [
                  if (_routePoints.isNotEmpty)
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5,
                      color: Colors.blueAccent,
                    ),
                ],
              ),
            ],
          ),

          // 📜 Draggable Sheet for searched results
          if (_showSheet && _filteredPhotos.isNotEmpty)
            DraggableScrollableSheet(
              initialChildSize: 0.3,
              minChildSize: 0.2,
              maxChildSize: 0.75,
              builder: (context, scrollController) {
                final theme = Theme.of(context);
                final colorScheme = theme.colorScheme;

                return Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    boxShadow: const [
                      BoxShadow(blurRadius: 8, color: Colors.black26),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "📍 Memories in '${_searchedCity!.toUpperCase()}'",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: _filteredPhotos.length,
                          itemBuilder: (_, index) {
                            final photo = _filteredPhotos[index];

                            return Card(
                              elevation: 3,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              color: colorScheme.surface,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  if (photo.lat != null && photo.lng != null) {
                                    setState(() {
                                      _routePoints = [];
                                      _enableMapRotation = false;
                                    });
                                    _mapController.rotate(0);
                                    _mapController.move(
                                      LatLng(photo.lat!, photo.lng!),
                                      14,
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "⚠️ Location not available.",
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // ⬇️ Image Section
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(16),
                                      ),
                                      child: FutureBuilder<String?>(
                                        future: RealtimeDatabaseService()
                                            .fetchBase64Image(
                                              photo.imagePath ?? '',
                                            ),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return const SizedBox(
                                              height: 200,
                                              child: Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            );
                                          } else if (snapshot.hasError ||
                                              !snapshot.hasData ||
                                              snapshot.data!.isEmpty) {
                                            return const SizedBox(
                                              height: 200,
                                              child: Center(
                                                child: Text(
                                                  "⚠️ Image failed to load",
                                                ),
                                              ),
                                            );
                                          } else {
                                            try {
                                              final imageBytes = base64Decode(
                                                snapshot.data!,
                                              );
                                              return Image.memory(
                                                imageBytes,
                                                height: 200,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                              );
                                            } catch (e) {
                                              return const SizedBox(
                                                height: 200,
                                                child: Center(
                                                  child: Text(
                                                    "⚠️ Error decoding image",
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ),

                                    // ⬇️ Details & Route Buttons
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            photo.caption,
                                            style: theme.textTheme.bodyLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: colorScheme.onSurface,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            photo.location,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color: colorScheme.outline,
                                                ),
                                          ),
                                          const SizedBox(height: 10),

                                          // ⬇️ Navigation Buttons
                                          SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              children: [
                                                const SizedBox(width: 8),
                                                ElevatedButton.icon(
                                                  onPressed:
                                                      () => _drawRoute(
                                                        'walking',
                                                        photo,
                                                      ),
                                                  icon: const Icon(
                                                    Icons.directions_walk,
                                                  ),
                                                  label: const Text('Walk'),
                                                ),
                                                const SizedBox(width: 8),
                                                ElevatedButton.icon(
                                                  onPressed:
                                                      () => _drawRoute(
                                                        'cycling',
                                                        photo,
                                                      ),
                                                  icon: const Icon(
                                                    Icons.directions_bike,
                                                  ),
                                                  label: const Text('Bike'),
                                                ),
                                                const SizedBox(width: 8),
                                                ElevatedButton.icon(
                                                  onPressed:
                                                      () => _drawRoute(
                                                        'driving',
                                                        photo,
                                                      ),
                                                  icon: const Icon(
                                                    Icons.directions_car,
                                                  ),
                                                  label: const Text('Car'),
                                                ),
                                                const SizedBox(width: 8),
                                                ElevatedButton.icon(
                                                  onPressed:
                                                      () =>
                                                          _drawPublicTransitRoute(
                                                            photo,
                                                          ),
                                                  icon: const Icon(
                                                    Icons.directions_transit,
                                                  ),
                                                  label: const Text('Transit'),
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          // 🔵 Go to live location button (bottom right)
          Positioned(
            top: 20,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Theme.of(context).colorScheme.primary,
              onPressed: () {
                if (_userLocation != null) {
                  _mapController.move(_userLocation!, 15.0);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Live location not available"),
                    ),
                  );
                }
              },
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showMemoryDialog(BuildContext context, PhotoModel photo) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Text(
              photo.caption,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 400,
                  maxWidth: 300, // ✅ Add finite width constraint
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FutureBuilder<String?>(
                      future: RealtimeDatabaseService().fetchBase64Image(
                        photo.imagePath ?? '',
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        } else if (snapshot.hasError ||
                            !snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return const SizedBox(
                            height: 200,
                            child: Center(
                              child: Text("⚠️ Image failed to load"),
                            ),
                          );
                        } else {
                          try {
                            final imageBytes = base64Decode(snapshot.data!);
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                imageBytes,
                                height: 200,
                                width:
                                    280, // ✅ Explicit width to prevent infinite size
                                fit: BoxFit.cover,
                              ),
                            );
                          } catch (e) {
                            return const SizedBox(
                              height: 200,
                              child: Center(
                                child: Text("⚠️ Error decoding image"),
                              ),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    Text("📍 ${photo.location}"),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Close",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
    );
  }
}

// import 'dart:async';
// import 'dart:convert';
// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:http/http.dart' as http;
// import 'package:latlong2/latlong.dart';
// import 'package:memscape/models/photo_model.dart';
// import 'package:memscape/services/realtime_database_service.dart';

// class ExploreMapScreen extends StatefulWidget {
//   const ExploreMapScreen({super.key});

//   @override
//   State<ExploreMapScreen> createState() => _ExploreMapScreenState();
// }

// class _ExploreMapScreenState extends State<ExploreMapScreen> {
//   final MapController _mapController = MapController();
//   final TextEditingController _searchController = TextEditingController();

//   List<PhotoModel> _allPhotos = [];
//   List<PhotoModel> _filteredPhotos = [];
//   LatLng? _userLocation;
//   LatLng? _searchLocation;
//   String? _searchedCity;
//   bool _showSheet = false;
//   List<LatLng> _routePoints = [];
//   StreamSubscription<Position>? _positionStream;
//   double? _userHeading;
//   bool _enableMapRotation = false;

//   double _calculateBearing(LatLng from, LatLng to) {
//     final dLon = to.longitude - from.longitude;
//     final y = sin(dLon * pi / 180) * cos(to.latitude * pi / 180);
//     final x =
//         cos(from.latitude * pi / 180) * sin(to.latitude * pi / 180) -
//         sin(from.latitude * pi / 180) *
//             cos(to.latitude * pi / 180) *
//             cos(dLon * pi / 180);
//     final bearing = atan2(y, x);
//     return (bearing * 180 / pi + 360) % 360;
//   }

//   @override
//   void initState() {
//     super.initState();
//     _startLocationTracking();
//     _loadUserLocation();
//     _fetchPhotos();
//   }

//   @override
//   void dispose() {
//     _positionStream?.cancel();
//     super.dispose();
//   }

//   void _startLocationTracking() async {
//     final hasPermission = await _handleLocationPermission();
//     if (!hasPermission) return;

//     const locationSettings = LocationSettings(
//       accuracy: LocationAccuracy.high,
//       distanceFilter: 5,
//     );

//     // _positionStream = Geolocator.getPositionStream(
//     //   locationSettings: locationSettings,
//     // ).listen((Position position) {
//     //   setState(() {
//     //     _userLocation = LatLng(position.latitude, position.longitude);
//     //     _userHeading = position.heading;
//     //   });
//     // });
//     _positionStream = Geolocator.getPositionStream(
//       locationSettings: locationSettings,
//     ).listen((Position position) {
//       final current = LatLng(position.latitude, position.longitude);

//       // Optional fallback: use GPS heading if no route is selected
//       double heading = position.heading;

//       // if (_routePoints.isNotEmpty) {
//       //   final destination = _routePoints.last;
//       //   heading = _calculateBearing(current, destination);
//       //   // 🔁 Rotate map only when route is active
//       //   _mapController.rotate(heading);
//       // }

//       if (_routePoints.isNotEmpty) {
//         final destination = _routePoints.last;
//         heading = _calculateBearing(current, destination);

//         // 🔄 Rotate map if route is selected
//         _mapController.rotate(heading);
//       } else {
//         // Optional: reset rotation when no route
//         _mapController.rotate(0);
//       }

//       setState(() {
//         _userLocation = current;
//         _userHeading = heading;
//         if (_enableMapRotation) {
//           _mapController.rotate(heading); // 🔁 rotate the map to heading
//         }
//       });
//     });
//   }

//   Future<void> _loadUserLocation() async {
//     final hasPermission = await _handleLocationPermission();
//     if (!hasPermission) return;

//     final position = await Geolocator.getCurrentPosition();
//     final loc = LatLng(position.latitude, position.longitude);

//     setState(() {
//       _userLocation = LatLng(position.latitude, position.longitude);
//       _userLocation = loc;
//     });
//     // 📍 Move the map to user location with desired zoom (e.g., 12.5)
//     _mapController.move(loc, 12.5);
//     _mapController.move(_userLocation!, 15); // 🔍 Zoom in nicely
//   }

//   Future<bool> _handleLocationPermission() async {
//     LocationPermission permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.deniedForever) return false;
//     }
//     return permission == LocationPermission.always ||
//         permission == LocationPermission.whileInUse;
//   }

//   Future<void> _fetchPhotos() async {
//     final data = await RealtimeDatabaseService().getAllPhotos();
//     setState(() {
//       _allPhotos = data.where((p) => p.lat != null && p.lng != null).toList();
//     });
//   }

//   Future<void> _searchPlace(String query) async {
//     try {
//       List<Location> locations = await locationFromAddress(query);
//       if (locations.isEmpty) throw Exception("Location not found");

//       final loc = locations.first;
//       final LatLng newCenter = LatLng(loc.latitude, loc.longitude);

//       final searchLower = query.toLowerCase().trim();
//       final matchedPhotos =
//           _allPhotos.where((p) {
//             final loc = p.location.toLowerCase().trim();
//             return loc.contains(searchLower) || searchLower.contains(loc);
//           }).toList();

//       setState(() {
//         _searchLocation = newCenter;
//         _searchedCity = query; // <-- THIS was missing
//         _filteredPhotos = matchedPhotos;
//         _showSheet = matchedPhotos.isNotEmpty;
//       });

//       _mapController.move(newCenter, 12.5);
//     } catch (e) {
//       debugPrint("❌ Error searching location: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           backgroundColor: Theme.of(context).colorScheme.errorContainer,
//           content: Text(
//             "Place not found.",
//             style: TextStyle(
//               color: Theme.of(context).colorScheme.onErrorContainer,
//             ),
//           ),
//         ),
//       );
//     }
//   }

//   Future<List<LatLng>> fetchRoute(LatLng start, LatLng end, String mode) async {
//     final url =
//         'https://router.project-osrm.org/route/v1/$mode/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';

//     final response = await http.get(Uri.parse(url));

//     if (response.statusCode == 200) {
//       final data = json.decode(response.body);
//       final coords = data['routes'][0]['geometry']['coordinates'] as List;
//       return coords.map((c) => LatLng(c[1] as double, c[0] as double)).toList();
//     } else {
//       throw Exception('Failed to fetch route');
//     }
//   }

//   Future<void> _drawRoute(String mode, PhotoModel photo) async {
//     if (_userLocation == null) return;

//     final String baseUrl = 'https://api.openrouteservice.org/v2/directions';
//     final String apiKey =
//         '5b3ce3597851110001cf6248b16bba8b608b442e8723352c9672c508'; // 🔑 Replace this

//     final String profile = switch (mode) {
//       'walking' => 'foot-walking',
//       'cycling' => 'cycling-regular',
//       'driving' => 'driving-car',
//       _ => 'foot-walking',
//     };

//     final String url =
//         '$baseUrl/$profile?api_key=$apiKey&start=${_userLocation!.longitude},${_userLocation!.latitude}&end=${photo.lng},${photo.lat}';

//     final response = await http.get(Uri.parse(url));

//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body);
//       final coordinates =
//           data['features'][0]['geometry']['coordinates'] as List;

//       setState(() {
//         _routePoints =
//             coordinates
//                 .map((c) => LatLng(c[1] as double, c[0] as double))
//                 .toList();
//         _enableMapRotation = true; // 🔁 enable map rotation
//       });
//     } else {
//       debugPrint("❌ Route fetch failed: ${response.statusCode}");
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text("Could not fetch route.")));
//     }
//   }

//   void _drawPublicTransitRoute(PhotoModel photo) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text("Public transit support coming soon.")),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           "Explore Memories",
//           style: Theme.of(context).textTheme.titleLarge?.copyWith(
//             color: Theme.of(context).colorScheme.onPrimary,
//           ),
//         ),
//         backgroundColor: Theme.of(context).colorScheme.primary,
//         iconTheme: IconThemeData(
//           color: Theme.of(context).colorScheme.onPrimary,
//         ),
//         bottom: PreferredSize(
//           preferredSize: const Size.fromHeight(56),
//           child: Padding(
//             padding: const EdgeInsets.all(8),
//             child: TextField(
//               controller: _searchController,
//               onSubmitted: _searchPlace,
//               style: TextStyle(
//                 color: Theme.of(context).colorScheme.onBackground,
//               ),
//               decoration: InputDecoration(
//                 hintText: "Search a city or place...",
//                 hintStyle: TextStyle(
//                   color: Theme.of(
//                     context,
//                   ).colorScheme.onBackground.withOpacity(0.6),
//                 ),
//                 prefixIcon: Icon(
//                   Icons.search,
//                   color: Theme.of(context).colorScheme.onBackground,
//                 ),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 filled: true,
//                 fillColor: Theme.of(context).colorScheme.surface,
//               ),
//             ),
//           ),
//         ),
//       ),

//       body: Stack(
//         children: [
//           FlutterMap(
//             mapController: _mapController,
//             options: MapOptions(
//               initialCenter: _userLocation ?? const LatLng(20.5937, 78.9629),
//               initialZoom: 4.5,
//               interactionOptions: const InteractionOptions(
//                 flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
//               ),
//             ),
//             children: [
//               TileLayer(
//                 urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
//                 userAgentPackageName: 'com.memscape.app',
//               ),
//               MarkerLayer(
//                 markers: [
//                   if (_userLocation != null)
//                     Marker(
//                       point: _userLocation!,
//                       width: 40,
//                       height: 40,
//                       child: Transform.rotate(
//                         angle:
//                             (_userHeading ?? 0) *
//                             (pi / 180), // Convert degrees to radians
//                         child: const Icon(
//                           Icons.navigation, // 🔺 triangle icon
//                           size: 40,
//                           color: Colors.blue,
//                         ),
//                       ),
//                     ),
//                   if (_filteredPhotos.isNotEmpty)
//                     ..._filteredPhotos.map(
//                       (photo) => Marker(
//                         point: LatLng(photo.lat!, photo.lng!),
//                         width: 40,
//                         height: 40,
//                         child: GestureDetector(
//                           onTap: () => _showMemoryDialog(context, photo),
//                           child: const Icon(
//                             Icons.location_on,
//                             size: 40,
//                             color: Colors.red,
//                           ),
//                         ),
//                       ),
//                     ),
//                 ],
//               ),
//               PolylineLayer(
//                 polylines: [
//                   if (_routePoints.isNotEmpty)
//                     Polyline(
//                       points: _routePoints,
//                       strokeWidth: 5,
//                       color: Colors.blueAccent,
//                     ),
//                 ],
//               ),
//             ],
//           ),

//           // 📜 Draggable Sheet for searched results
//           if (_showSheet && _filteredPhotos.isNotEmpty)
//             DraggableScrollableSheet(
//               initialChildSize: 0.3,
//               minChildSize: 0.2,
//               maxChildSize: 0.75,
//               builder: (context, scrollController) {
//                 final theme = Theme.of(context);
//                 final colorScheme = theme.colorScheme;

//                 return Container(
//                   decoration: BoxDecoration(
//                     color: colorScheme.background,
//                     borderRadius: const BorderRadius.vertical(
//                       top: Radius.circular(20),
//                     ),
//                     boxShadow: const [
//                       BoxShadow(blurRadius: 8, color: Colors.black26),
//                     ],
//                   ),
//                   padding: const EdgeInsets.all(16),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Center(
//                         child: Container(
//                           width: 40,
//                           height: 4,
//                           decoration: BoxDecoration(
//                             color: colorScheme.outlineVariant,
//                             borderRadius: BorderRadius.circular(2),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 12),
//                       Text(
//                         "📍 Memories in '${_searchedCity!.toUpperCase()}'",
//                         style: theme.textTheme.titleMedium?.copyWith(
//                           fontWeight: FontWeight.bold,
//                           color: colorScheme.onBackground,
//                         ),
//                       ),
//                       const SizedBox(height: 12),
//                       Expanded(
//                         child: ListView.builder(
//                           controller: scrollController,
//                           itemCount: _filteredPhotos.length,
//                           itemBuilder: (_, index) {
//                             final photo = _filteredPhotos[index];

//                             return Card(
//                               elevation: 3,
//                               margin: const EdgeInsets.symmetric(vertical: 8),
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(16),
//                               ),
//                               color: colorScheme.surface,
//                               child: InkWell(
//                                 borderRadius: BorderRadius.circular(16),
//                                 onTap: () {
//                                   setState(() {
//                                     _routePoints = [];
//                                     _enableMapRotation =
//                                         false; // 🔁 disable map rotation
//                                   });
//                                   _mapController.rotate(0); // Reset rotation
//                                   _mapController.move(
//                                     LatLng(photo.lat!, photo.lng!),
//                                     14,
//                                   );
//                                 },
//                                 child: Column(
//                                   crossAxisAlignment:
//                                       CrossAxisAlignment.stretch,
//                                   children: [
//                                     ClipRRect(
//                                       borderRadius: const BorderRadius.vertical(
//                                         top: Radius.circular(16),
//                                       ),
//                                       child: Image.memory(
//                                         base64Decode(photo.imageBase64!),
//                                         height: 160,
//                                         fit: BoxFit.cover,
//                                       ),
//                                     ),
//                                     Padding(
//                                       padding: const EdgeInsets.all(12),
//                                       child: Column(
//                                         crossAxisAlignment:
//                                             CrossAxisAlignment.start,
//                                         children: [
//                                           Text(
//                                             photo.caption,
//                                             style: theme.textTheme.bodyLarge
//                                                 ?.copyWith(
//                                                   fontWeight: FontWeight.w600,
//                                                   color: colorScheme.onSurface,
//                                                 ),
//                                           ),
//                                           const SizedBox(height: 4),
//                                           Text(
//                                             photo.location,
//                                             style: theme.textTheme.bodyMedium
//                                                 ?.copyWith(
//                                                   color: colorScheme.outline,
//                                                 ),
//                                           ),
//                                           const SizedBox(height: 10),
//                                           SingleChildScrollView(
//                                             scrollDirection: Axis.horizontal,
//                                             child: Row(
//                                               children: [
//                                                 const SizedBox(width: 8),
//                                                 ElevatedButton.icon(
//                                                   onPressed:
//                                                       () => _drawRoute(
//                                                         'walking',
//                                                         photo,
//                                                       ),
//                                                   icon: const Icon(
//                                                     Icons.directions_walk,
//                                                   ),
//                                                   label: const Text('Walk'),
//                                                 ),
//                                                 const SizedBox(width: 8),
//                                                 ElevatedButton.icon(
//                                                   onPressed:
//                                                       () => _drawRoute(
//                                                         'cycling',
//                                                         photo,
//                                                       ),
//                                                   icon: const Icon(
//                                                     Icons.directions_bike,
//                                                   ),
//                                                   label: const Text('Bike'),
//                                                 ),
//                                                 const SizedBox(width: 8),
//                                                 ElevatedButton.icon(
//                                                   onPressed:
//                                                       () => _drawRoute(
//                                                         'driving',
//                                                         photo,
//                                                       ),
//                                                   icon: const Icon(
//                                                     Icons.directions_car,
//                                                   ),
//                                                   label: const Text('Car'),
//                                                 ),
//                                                 const SizedBox(width: 8),
//                                                 ElevatedButton.icon(
//                                                   onPressed:
//                                                       () =>
//                                                           _drawPublicTransitRoute(
//                                                             photo,
//                                                           ),
//                                                   icon: const Icon(
//                                                     Icons.directions_transit,
//                                                   ),
//                                                   label: const Text('Transit'),
//                                                 ),
//                                                 const SizedBox(width: 8),
//                                               ],
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             );
//                           },
//                         ),
//                       ),
//                     ],
//                   ),
//                 );
//               },
//             ),

//           // 🔵 Go to live location button (bottom right)
//           Positioned(
//             top: 20,
//             right: 20,
//             child: FloatingActionButton(
//               backgroundColor: Theme.of(context).colorScheme.primary,
//               onPressed: () {
//                 if (_userLocation != null) {
//                   _mapController.move(_userLocation!, 15.0);
//                 } else {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(
//                       content: Text("Live location not available"),
//                     ),
//                   );
//                 }
//               },
//               child: const Icon(Icons.my_location, color: Colors.white),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showMemoryDialog(BuildContext context, PhotoModel photo) {
//     showDialog(
//       context: context,
//       builder:
//           (_) => AlertDialog(
//             backgroundColor: Theme.of(context).colorScheme.surface,

//             title: Text(
//               photo.caption,
//               style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
//             ),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 if (photo.imageBase64 != null && photo.imageBase64!.isNotEmpty)
//                   Image.memory(
//                     base64Decode(
//                       photo.imageBase64!,
//                     ), // safe because we checked null
//                     height: 150,
//                     fit: BoxFit.cover,
//                   ),

//                 const SizedBox(height: 10),
//                 Text("📍 ${photo.location}"),
//               ],
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: Text(
//                   "Close",
//                   style: TextStyle(
//                     color: Theme.of(context).colorScheme.primary,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//     );
//   }
// }
