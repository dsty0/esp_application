import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingPage extends StatefulWidget {
  @override
  _SettingPageState createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final dbRef = FirebaseDatabase.instance.ref();
  final TextEditingController _intervalController = TextEditingController();
  final String deviceID = "DST-TYL230904-INV";

  @override
  void initState() {
    super.initState();
    loadInterval();
  }

  void loadInterval() async {
    final snapshot = await dbRef.child('esp-data/$deviceID/interval').get();
    if (snapshot.exists) {
      _intervalController.text = snapshot.value.toString();
    }
  }

  void saveInterval() async {
    try {
      final int? interval = int.tryParse(_intervalController.text);
      if (interval != null) {
        await dbRef.child('esp-data/$deviceID').set({'interval': interval});
        Navigator.pop(context); // kembali ke halaman sebelumnya
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Interval updated to $interval')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Invalid input')),
        );
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF1F1F1),
      appBar: AppBar(
        backgroundColor: Color(0xFF01AB96),
        elevation: 0,
        centerTitle: true,
        title: Text("Setting Device", style: GoogleFonts.lexend(color: Colors.white)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Interval  ⓘ", style: GoogleFonts.lexend(fontSize: 14)),
            SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _intervalController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: "0",
                  border: InputBorder.none,
                ),
              ),
            ),
            Spacer(),
            Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    ElevatedButton(
      onPressed: () => Navigator.pop(context),
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
                  child: Text("CANCEL", style: GoogleFonts.lexend(color: Colors.black)),
    ),
    SizedBox(width: 16), // Jarak antar tombol diperkecil
    ElevatedButton(
      onPressed: saveInterval,
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF01AB96),
        padding: EdgeInsets.symmetric(horizontal: 34, vertical: 12),
      ),
                  child: Text("SAVE", style: GoogleFonts.lexend(color: Colors.white)),
    ),
  ],
),

            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
