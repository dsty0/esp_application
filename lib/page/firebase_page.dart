import 'package:esp_aplicaton/page/humidity_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:esp_aplicaton/page/setting_page.dart';
import 'package:esp_aplicaton/page/temperature_detail_page.dart';
import 'package:esp_aplicaton/page/humidity_detail_page.dart';
import 'package:esp_aplicaton/page/light_detail_page.dart';
import 'package:esp_aplicaton/page/moisture_detail_page.dart';
import 'package:esp_aplicaton/page/info_page.dart';

String tokenId = "DST-TYL230904";


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
  LatLng? _devicePosition; // Posisi device dari Firebase


  @override
  void initState() {
    super.initState();
    loginAndListenData();
    getCurrentLocation();
    // getDeviceLocation(); // Ambil posisi device juga
    listenDeviceLocation(); // 🔥 Auto-update posisi device
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

            final latestKey = mapped.keys.toList()..sort((a, b) => b.compareTo(a));
            final latestData = mapped[latestKey.first]!;

            if (!latestData.containsKey('timestamp') || latestData['timestamp'] == null) {
              final now = DateTime.now();
              latestData['timestamp'] = now.toIso8601String();
              mapped[latestKey.first] = latestData;
            }

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

Future<void> getDeviceLocation() async {
  try {
    final snapshot = await dbRef.child('esp-data/$tokenId').get();
    if (snapshot.exists) {
      final raw = snapshot.value as Map<dynamic, dynamic>;
      final sortedKeys = raw.keys.toList()
        ..sort((a, b) => b.toString().compareTo(a.toString()));

      for (final key in sortedKeys) {
        final entry = raw[key];
        if (entry is Map) {
          final data = Map<String, dynamic>.from(entry);
          final lat = double.tryParse(data['lat']?.toString() ?? '');
          final lng = double.tryParse(data['lon']?.toString() ?? '');

          print("🧭 Checking key: $key, lat: $lat, lon: $lng");

          if (lat != null && lng != null) {
            print("✅ Found device location: $lat, $lng");
            setState(() {
              _devicePosition = LatLng(lat, lng);
            });
            return;
          }
        }
      }
    } else {
      print("⚠️ Data not found at: esp-data/$tokenId");
    }
  } catch (e) {
    print("❌ Error reading device location: $e");
  }
}

void listenDeviceLocation() {
  dbRef.child('esp-data/$tokenId').onValue.listen((event) {
    final snapshot = event.snapshot;
    if (snapshot.exists) {
      final raw = snapshot.value as Map<dynamic, dynamic>;
      final sortedKeys = raw.keys.toList()
        ..sort((a, b) => b.toString().compareTo(a.toString()));

      for (final key in sortedKeys) {
        final entry = raw[key];
        if (entry is Map) {
          final data = Map<String, dynamic>.from(entry);
          final lat = double.tryParse(data['lat']?.toString() ?? '');
          final lng = double.tryParse(data['lon']?.toString() ?? '');

          if (lat != null && lng != null) {
            final newPosition = LatLng(lat, lng);

            // Hanya update jika lokasi berbeda dari sebelumnya
            if (_devicePosition == null ||
                _devicePosition!.latitude != lat ||
                _devicePosition!.longitude != lng) {
              setState(() {
                _devicePosition = newPosition;
              });

              // Pindahkan kamera ke lokasi device
              _mapController.move(newPosition, _mapController.camera.zoom);
            }
            return;
          }
        }
      }
    }
  });
}


IconData getBatteryIcon(double voltage) {
  if (voltage >= 4.0) return Icons.battery_full;
  if (voltage >= 3.9) return Icons.battery_6_bar;
  if (voltage >= 3.8) return Icons.battery_5_bar;
  if (voltage >= 3.7) return Icons.battery_4_bar;
  if (voltage >= 3.6) return Icons.battery_3_bar;
  if (voltage >= 3.5) return Icons.battery_2_bar;
  if (voltage >= 3.4) return Icons.battery_1_bar;
  return Icons.battery_alert;
}

Icon getSignalIcon(int signalStrength) {
  Color color;
  if (signalStrength >= 75) {
    color = Colors.green;
  } else if (signalStrength >= 50) {
    color = Colors.lightGreen;
  } else if (signalStrength >= 25) {
    color = Colors.orange;
  } else {
    color = Colors.red;
  }

  return Icon(
    Icons.network_cell,
    size: 16,
    color: color,
  );
}

String formatTimestamp(dynamic ts) {
  if (ts == null) return "--";

  if (ts is int) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000).toLocal();
    return "${dt.day.toString().padLeft(2, '0')} ${_monthName(dt.month)} ${dt.year}, "
           "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  } else if (ts is String) {
    try {
      final parsed = int.tryParse(ts);
      if (parsed != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch(parsed * 1000).toLocal();
        return "${dt.day.toString().padLeft(2, '0')} ${_monthName(dt.month)} ${dt.year}, "
               "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      }

      final dt = DateTime.tryParse(ts)?.toLocal();
      if (dt != null) {
        return "${dt.day.toString().padLeft(2, '0')} ${_monthName(dt.month)} ${dt.year}, "
               "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      }
    } catch (_) {}
    return ts;
  }

  return "--";
}



  String _monthName(int month) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return months[month - 1];
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 0 && hour <= 12) {
      return 'Hello, Good Morning!';
    } else if (hour > 12 && hour <= 18) {
      return 'Hello, Good Afternoon!';
    } else {
      return 'Hello, Good Evening!';
    }
  }

  String getUserName() {
    final user = auth.currentUser;
    if (user != null && user.email != null) {
      return user.email!.split('@').first;
    }
    return "User";
  }

  @override
  Widget build(BuildContext context) {
    final sortedKeys = data.keys.toList()..sort((a, b) => b.compareTo(a));
    final latest = sortedKeys.isNotEmpty ? data[sortedKeys.first] : {};

    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                 CircleAvatar(
  backgroundColor: const Color(0xFF01AB96),
  radius: 25,
  child: Icon(
    Icons.person,
    color: const Color.fromARGB(221, 255, 255, 255),
    size: 30,
  ),
),

                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(getGreeting(), style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(getUserName()),
                      ],
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF01AB96),
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(Icons.settings, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SettingPage()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Map Section
          Stack(
            children: [
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                height: 260,
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
                        userAgentPackageName: 'com.esp.app',
                      ),
                      MarkerLayer(
                    markers: [
                      // Marker lokasi user
                      Marker(
                        point: _currentPosition,
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.location_on,
                          color: const Color(0xFF01AB96),
                          size: 30,
                        ),
                      ),
                      // Marker lokasi device (jika tersedia)
                      if (_devicePosition != null)
                        Marker(
                          point: _devicePosition!,
                          width: 40,
                          height: 40,
                          child: Icon(
                            Icons.sensors,
                            color: Colors.redAccent,
                            size: 30,
                          ),
                        ),
                    ],
                  ),

                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
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
                    icon: Icon(Icons.my_location, color: const Color(0xFF01AB96)),
                    onPressed: () {
                      _mapController.move(_currentPosition, 14);
                    },
                  ),
                ),
              ),
            ],
          ),

Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Data Sensor',
            style: GoogleFonts.lexend(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xDD181818),
            ),
          ),
          SizedBox(height: 2),
          Container(
            height: 2,
            width: 40,
            color: const Color(0xFF01AB96),
          ),
        ],
      ),
      Row(
  children: [
    Icon(
      getBatteryIcon(double.tryParse(latest['battery']?.toString() ?? '0') ?? 0),
      size: 16,
      color: const Color.fromARGB(255, 184, 184, 184),
    ),
    SizedBox(width: 4),
    Text(
      "${latest['battery'] ?? '--'} V",
      style: GoogleFonts.lexend(
        fontSize: 12,
        color: const Color(0xDD181818),
      ),
    ),
    SizedBox(width: 12),
getSignalIcon(int.tryParse(latest['signal']?.toString() ?? '0') ?? 0),
    SizedBox(width: 4),
    Text(
      "${latest['signal'] ?? '--'}%",
      style: GoogleFonts.lexend(
        fontSize: 12,
        color: const Color(0xDD181818),
      ),
    ),
    SizedBox(width: 12),
    Text(
      sortedKeys.isNotEmpty
          ? "Last updated: ${formatTimestamp(sortedKeys.first)}"
          : '--',
      style: GoogleFonts.lexend(
        fontSize: 12,
        color: const Color(0xDD181818),
      ),
    ),
  ],
),

    ],
  ),
),



          // Data Cards
          Expanded(
            child: GridView.count(
              padding: EdgeInsets.all(15),
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.42,
              children: [
               sensorCard(
  "Temperature", 
  "${latest['suhu'] ?? '--'}°C",
  "lib/assets/images/temperature.png", 
  formatTimestamp(latest['timestamp']),
  onTap: () {

Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => TemperatureDetailPage(tokenId: tokenId),
  ),
);

  },
),
               sensorCard("Humidity", "${latest['kelembapan'] ?? '--'} RH",
  "lib/assets/images/humidity.png", 
  formatTimestamp(latest['timestamp']),
  onTap: () {

Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => HumidityDetailPage(tokenId: tokenId),
  ),
);

  },
),
               sensorCard("Light Int", "${latest['cahaya'] ?? '--'} Lux",
  "lib/assets/images/light.png", 
  formatTimestamp(latest['timestamp']),
  onTap: () {

Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => LightDetailPage(tokenId: tokenId),
  ),
);

  },
),
               sensorCard("Moisture", "${latest['soil'] ?? '--'}%",
  "lib/assets/images/soil.png", 
  formatTimestamp(latest['timestamp']),
  onTap: () {

Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => MoistureDetailPage(tokenId: tokenId),
  ),
);

  },
),
              ],
            ),
          ),
        ],
      ),
//       bottomNavigationBar: BottomNavigationBar(
//   currentIndex: 1,
//   onTap: (index) {
//     if (index == 0) {
//       // Do nothing or go to home
//     } else if (index == 1) {
//       Navigator.push(
//         context,
//         MaterialPageRoute(builder: (context) => InfoPage()),
//       );
//     }
//   },
//   items: const [
//     BottomNavigationBarItem(
//       icon: Icon(Icons.home, color: Color(0xFF01AB96)), label: 'Home'),
//     BottomNavigationBarItem(
//       icon: Icon(Icons.info_sharp, color: Color.fromARGB(255, 75, 75, 75)), label: 'Info'),
//   ],
// ),

    );
  }

  Widget sensorCard(
  String title,
  String value,
  String assetPath,
  String timestamp, {
  VoidCallback? onTap, // Tambahkan onTap opsional
}) {
  return GestureDetector(
    onTap: onTap, // Pasang di GestureDetector
    child: Container(
      width: 280,
      height: 260,
      decoration: BoxDecoration(
        color: const Color(0xFF01AB96),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 1,
            offset: Offset(1, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset(assetPath, width: 34, height: 34),
                SizedBox(width: 6),
                Text(
                  title,
                  style: GoogleFonts.lexend(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Center(
              child: Text(
                value,
                style: GoogleFonts.lexend(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Spacer(),
            // Align(
            //   alignment: Alignment.bottomRight,
            //   child: Text(
            //     timestamp,
            //     style: GoogleFonts.lexend(
            //       color: Colors.white70,
            //       fontSize: 10,
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    ),
  );
}
}