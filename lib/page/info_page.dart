import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InfoPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Info', style: GoogleFonts.lexend()),
        backgroundColor: const Color(0xFF01AB96),
      ),
      body: Center(
        child: Text(
          'Dalam proses pengembangan...',
          style: GoogleFonts.lexend(
            fontSize: 18,
            color: Colors.grey[700],
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
