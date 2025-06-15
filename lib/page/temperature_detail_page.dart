import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class TemperatureDetailPage extends StatefulWidget {
  final String tokenId;

  const TemperatureDetailPage({Key? key, required this.tokenId}) : super(key: key);

  @override
  _TemperatureDetailPageState createState() => _TemperatureDetailPageState();
}

class _TemperatureDetailPageState extends State<TemperatureDetailPage> {
  late final DatabaseReference _dbRef;
  Map<String, dynamic> allData = {};
  DateTimeRange? selectedRange;
  String viewMode = 'Grafik';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _dbRef = FirebaseDatabase.instance.ref('esp-data/${widget.tokenId}');
    fetchData();
  }

  void fetchData() {
    _dbRef.onValue.listen((event) {
      final snapshot = event.snapshot;
      if (snapshot.exists) {
        final raw = snapshot.value as Map;
        final parsed = raw.entries.map((entry) {
          final timestampUnix = int.tryParse(entry.key.toString());
          final timestamp = DateTime.fromMillisecondsSinceEpoch(
            timestampUnix != null && timestampUnix > 1000000000000
                ? timestampUnix
                : (timestampUnix ?? 0) * 1000,
          );

          final data = Map<String, dynamic>.from(entry.value);
          return {
            'timestamp': timestamp,
            'suhu': (data['suhu'] ?? 0).toDouble(),
          };
        }).where((e) => e['timestamp'] != null).toList();

        setState(() {
          allData = {
            for (var item in parsed) item['timestamp'].toString(): item,
          };
          isLoading = false;
        });
      } else {
        setState(() {
          allData = {};
          isLoading = false;
        });
      }
    });
  }

  List<Map<String, dynamic>> get filteredData {
    final entries = allData.entries.map((e) {
      final tsStr = e.value['timestamp']?.toString() ?? '';
      final ts = DateTime.tryParse(tsStr);
      return {
        'timestamp': ts,
        'suhu': (e.value['suhu'] ?? 0).toDouble(),
      };
    }).where((e) => e['timestamp'] != null).toList();

    entries.sort((a, b) =>
        (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

    if (selectedRange != null) {
      final start = selectedRange!.start;
      final end = selectedRange!.end.add(const Duration(days: 1));
      return entries.where((e) {
        final ts = e['timestamp'] as DateTime;
        return ts.isAfter(start.subtract(const Duration(seconds: 1))) &&
            ts.isBefore(end);
      }).toList();
    }

    return entries.take(10).toList();
  }

  Future<void> selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: selectedRange,
    );

    if (picked != null) {
      setState(() {
        selectedRange = picked;
      });
    }
  }

  Future<void> exportCSV() async {
    final data = filteredData;
    final csv = StringBuffer();
    csv.writeln("DateTime,Suhu");

    for (var item in data) {
      final ts = item['timestamp'] as DateTime;
      final suhu = item['suhu'];
      csv.writeln("${DateFormat('yyyy-MM-dd HH:mm:ss').format(ts)},$suhu");
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/temperature_data.csv');
    await file.writeAsString(csv.toString());

    Share.shareXFiles([XFile(file.path)], text: 'Temperature Data CSV');
  }

  @override
  Widget build(BuildContext context) {
    final chartData = [...filteredData];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: Colors.black),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
            Card(
  color: Colors.white, // <- Tambahkan ini
  elevation: 2,         // opsional biar ada bayangan
  shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12)),
  child: Padding(

                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Temperature",
                                style: GoogleFonts.lexend(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.download),
                                onPressed: exportCSV,
                              )
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                selectedRange == null
                                    ? "Data Pemantauan"
                                    : "${DateFormat('dd/MM/yy').format(selectedRange!.start)} - ${DateFormat('dd/MM/yy').format(selectedRange!.end)}",
                                style: GoogleFonts.lexend(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Row(
      children: [
        buildFilterButton("Grafik"),
        const SizedBox(width: 8),
        buildFilterButton("Tabel"),
      ],
    ),
    ElevatedButton(
      onPressed: selectDateRange,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF01AB96),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(8),
      ),
      child: const Icon(Icons.calendar_today, size: 16),
    )
  ],
),

                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  viewMode == "Tabel"
                  ? Expanded(child: buildTable(chartData))
                  : SizedBox(height: 320, child: buildChart(chartData)),

                ],
              ),
            ),
    );
  }

  Widget buildFilterButton(String label) {
    final isActive = viewMode == label;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          viewMode = label;
        });
      },
      style: ElevatedButton.styleFrom(
  backgroundColor: isActive ? const Color(0xFF01AB96) : Colors.white,
  // tambahkan border biar tombol putih tetap kelihatan
  side: BorderSide(color: Colors.grey.shade300),

        foregroundColor: isActive ? Colors.white : Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(label),
    );
  }

 Widget buildChart(List<Map<String, dynamic>> chartData) {
  if (chartData.isEmpty) {
    return const Center(child: Text("No data"));
  }

  final reversedData = chartData.reversed.toList();

return Padding(
  padding: const EdgeInsets.all(4),
  child: Card(
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        height: 150,
        child: LineChart(
          LineChartData(
          minY: 0,
          titlesData: FlTitlesData(
  bottomTitles: AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 28,
      getTitlesWidget: (value, meta) {
        final index = value.toInt();
        if (index >= 0 && index < reversedData.length) {
          final ts = reversedData[index]['timestamp'] as DateTime;
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              DateFormat('HH:mm').format(ts),
              style: GoogleFonts.lexend(fontSize: 10),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    ),
  ),
  leftTitles: AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 28,
      getTitlesWidget: (value, meta) {
        return Text(
          value.toInt().toString(),
          style: GoogleFonts.lexend(fontSize: 10),
          textAlign: TextAlign.right,
        );
      },
    ),
  ),
  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
),

          gridData: FlGridData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(reversedData.length, (i) {
                final suhu = reversedData[i]['suhu'];
                return FlSpot(i.toDouble(), suhu);
              }),
              isCurved: true,
              color: const Color(0xFF01AB96),
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    ),
  ),
  ),
);
}

Widget buildTable(List<Map<String, dynamic>> tableData) {
  return SizedBox(
  height: (tableData.length * 60.0).clamp(300.0, 800.0), // Minimal 300, maksimal 800
    child: Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              color: const Color.fromARGB(255, 255, 255, 255),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: Text(
                        "Waktu Perekaman",
                        style: GoogleFonts.lexend(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        "Suhu (°C)",
                        style: GoogleFonts.lexend(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: tableData.map((item) {
                    final ts = item['timestamp'] as DateTime;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Center(
                                  child: Text(
                                    DateFormat('dd/MM/yy HH:mm').format(ts),
                                    style: GoogleFonts.lexend(),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Center(
                                  child: Text(
                                    "${item['suhu']}",
                                    style: GoogleFonts.lexend(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}