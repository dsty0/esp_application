import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';

class FirebasePage extends StatefulWidget {
  @override
  _FirebasePageState createState() => _FirebasePageState();
}

class _FirebasePageState extends State<FirebasePage> {
  final MapController _mapController = MapController();
  final auth = FirebaseAuth.instance;
  final dbRef = FirebaseDatabase.instance.ref();
  Map<String, dynamic> data = {};
  LatLng _currentPosition = LatLng(-7.2575, 112.7521); // Default: Surabaya

  @override
  void initState() {
    super.initState();
    loginAndListenData();
    getCurrentLocation();
  }

  Future<void> loginAndListenData() async {
    try {
      final user = auth.currentUser;
      if (user != null) {
        dbRef.child('esp-data/DST-TYL230904').onValue.listen((event) {
          final snapshot = event.snapshot;
          if (snapshot.exists) {
            final raw = snapshot.value as Map<dynamic, dynamic>;
            final mapped = raw.map((key, value) =>
                MapEntry(key.toString(), Map<String, dynamic>.from(value)));
            setState(() {
              data = mapped;
            });
          }
        });
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  Future<void> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();

    if (!serviceEnabled || permission == LocationPermission.deniedForever) {
      setState(() {
        _currentPosition = LatLng(
          -6.9 + (0.2 * (DateTime.now().second % 10)) / 10.0,
          107.6 + (0.2 * (DateTime.now().minute % 10)) / 10.0,
        );
      });
      return;
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedKeys = data.keys.toList()..sort((a, b) => b.compareTo(a));
    final latest = sortedKeys.isNotEmpty ? data[sortedKeys.first] : {};

    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(top: 50, left: 20, bottom: 10),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundImage: AssetImage("lib/assets/images/image.png"),
                  radius: 25,
                ),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Hello, Good morning!",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("Dani"),
                  ],
                ),
              ],
            ),
          ),
          Stack(
            children: [
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                height: 240,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(0),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentPosition,
                      initialZoom: 14,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://cartodb-basemaps-a.global.ssl.fastly.net/light_all/{z}/{x}/{y}@4x.png',
                        userAgentPackageName: 'com.example.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentPosition,
                            width: 40,
                            height: 40,
                            child:
                                Icon(Icons.location_on, color: Colors.red, size: 30),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 20,
                right: 30,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(Icons.my_location, color: Colors.black87),
                    onPressed: () {
                      _mapController.move(_currentPosition, 14);
                    },
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: GridView.count(
              padding: EdgeInsets.all(15),
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.42,
              children: [
                sensorCard("Temperature", "${latest['suhu'] ?? '--'}°C", "lib/assets/images/temperature.png"),
                sensorCard("Humidity", "${latest['kelembapan'] ?? '--'}%", "lib/assets/images/humidity.png"),
                sensorCard("Light", "${latest['cahaya'] ?? '--'}Cd", "lib/assets/images/light.png"),
                sensorCard("Moisture", "${latest['soil'] ?? '--'}%", "lib/assets/images/soil.png"),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.home, color: Colors.green), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: ''),
        ],
      ),
    );
  }

  Widget sensorCard(String title, String value, String assetPath) {
    return Container(
      width: 280,
      height: 260,
      decoration: BoxDecoration(
        color: Colors.teal[400],
        border: Border.all(color: Colors.white, width: 0.6),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 2,
            offset: Offset(1, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(assetPath, width: 34, height: 34),
                SizedBox(width: 6),
                Text(
                  title,
                  style: GoogleFonts.lexend(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              value,
              style: GoogleFonts.lexend(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
