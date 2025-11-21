// Import paket yang dibutuhkan
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'catatan_model.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const MapScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final List<CatatanModel> _savedNotes = [];
  final MapController _mapController = MapController();

  Future<void> saveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    List<String> data = _savedNotes.map((n) {
      return jsonEncode({
        "lat": n.position.latitude,
        "lng": n.position.longitude,
        "note": n.note,
        "address": n.address,
        "type": n.type,
      });
    }).toList();

    prefs.setStringList("notes", data);
  }


  @override
void initState() {
  super.initState();
  SharedPreferences.getInstance().then((prefs) {

  });
  loadData();
}


  Future<void> loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? data = prefs.getStringList("notes");

    if (data == null) return;

    setState(() {
      _savedNotes.clear();
      for (var item in data) {
        var jsonItem = jsonDecode(item);
        _savedNotes.add(
          CatatanModel(
            position: latlong.LatLng(jsonItem["lat"], jsonItem["lng"]),
            note: jsonItem["note"],
            address: jsonItem["address"],
            type: jsonItem["type"],
          ),
        );
      }
    });
  }

  
  // Fungsi untuk mendapatkan lokasi saat ini
  Future<void> _findMyLocation() async {
    // Cek layanan dan izin GPS
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    // Ambil posisi
    Position position = await Geolocator.getCurrentPosition();

    // Pindahkan kamera peta
    _mapController.move(
      latlong.LatLng(position.latitude, position.longitude),
      15.0,
    );
  }

          void _handleLongPress(TapPosition tapPosition, latlong.LatLng point) async {
          String? type = await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Pilih Jenis Lokasi"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text("Rumah"),
                    onTap: () => Navigator.pop(context, "rumah"),
                  ),
                  ListTile(
                    title: const Text("Toko"),
                    onTap: () => Navigator.pop(context, "toko"),
                  ),
                  ListTile(
                    title: const Text("Kantor"),
                    onTap: () => Navigator.pop(context, "kantor"),
                  ),
                ],
              ),
            ),
          );

          if (type == null) return; // user cancel

          // reverse geocoding
          List<Placemark> placemarks =
              await placemarkFromCoordinates(point.latitude, point.longitude);

          String address = placemarks.first.street ?? "Alamat tidak dikenal";

          setState(() {
            _savedNotes.add(
              CatatanModel(
                position: point,
                note: "Catatan Baru",
                address: address,
                type: type,
              ),
            );
          });
          saveData();
        }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Geo-Catatan")),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
  initialCenter: const latlong.LatLng(-6.2, 106.8),
  initialZoom: 13.0,
  onLongPress: (tapPosition, latlng) {
  _handleLongPress(tapPosition, latlng);
},
),

        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          ),
              MarkerLayer(
              markers: _savedNotes.map((n) {
                Icon icon;

                if (n.type == "rumah") {
                  icon = const Icon(Icons.home, color: Colors.blue, size: 35);
                } else if (n.type == "toko") {
                  icon = const Icon(Icons.store, color: Colors.green, size: 35);
                } else if (n.type == "kantor") {
                  icon = const Icon(Icons.business, color: Colors.orange, size: 35);
                } else {
                  icon = const Icon(Icons.location_on, color: Colors.red, size: 35);
                }

               return Marker(
                  point: n.position,
                  child: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text("Hapus Marker?"),
                          content: Text(n.address),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Batal"),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _savedNotes.remove(n);
                                });
                                saveData();
                                Navigator.pop(context);
                              },
                              child: const Text("Hapus"),
                            ),
                          ],
                        ),
                      );
                    },
        child: icon,
      ),
    );
  }).toList(),
),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _findMyLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
