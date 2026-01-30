import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/earthquake.dart';
import '../services/earthquake_service.dart';

class LastEarthquakeScreen extends StatefulWidget {
  const LastEarthquakeScreen({super.key});

  @override
  State<LastEarthquakeScreen> createState() => _LastEarthquakeScreenState();
}

class _LastEarthquakeScreenState extends State<LastEarthquakeScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<Earthquake>> _earthquakes;
  TabController? _tabController;

  // Filtreler
  String? _selectedCity;
  DateTimeRange? _selectedDateRange;
  double _minMagnitude = 0.0;
  bool _showOnlySignificant = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadEarthquakes();
  }

  void _loadEarthquakes() {
    setState(() {
      _earthquakes = EarthquakeService.fetchEarthquakes();
    });
  }

  List<Earthquake> _applyFilters(List<Earthquake> earthquakes) {
    var filtered = earthquakes;

    if (_selectedCity != null) {
      filtered = filtered
          .where((e) => e.title.toLowerCase().contains(_selectedCity!.toLowerCase()))
          .toList();
    }

    if (_selectedDateRange != null) {
      filtered = filtered.where((e) {
        try {
          final date = DateFormat('dd.MM.yyyy').parse(e.date);
          return date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
              date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
        } catch (_) {
          return true;
        }
      }).toList();
    }

    if (_showOnlySignificant) {
      filtered = filtered.where((e) => e.magnitude >= 4.0).toList();
    }

    filtered = filtered.where((e) => e.magnitude >= _minMagnitude).toList();

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1D1E33),
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deprem İzleme',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Kandilli Rasathanesi',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white60,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEarthquakes,
          ),
        ],
        bottom: TabBar(
          controller: _tabController!,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'Liste'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Grafikler'),
            Tab(icon: Icon(Icons.map), text: 'İstatistik'),
          ],
        ),
      ),
      body: FutureBuilder<List<Earthquake>>(
        future: _earthquakes,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Hata: ${snapshot.error}', style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadEarthquakes,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D1E33),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Yeniden Dene'),
                  ),
                ],
              ),
            );
          }

          final allEarthquakes = snapshot.data!;
          final earthquakes = _applyFilters(allEarthquakes);

          return TabBarView(
            controller: _tabController,
            children: [
              _buildListView(earthquakes, allEarthquakes),
              _buildChartsView(earthquakes),
              _buildStatisticsView(earthquakes),
            ],
          );
        },
      ),
    );
  }

  Widget _buildListView(List<Earthquake> earthquakes, List<Earthquake> allEarthquakes) {
    final criticalQuakes = earthquakes.where((e) => e.magnitude >= 5.0).toList();

    return Column(
      children: [
        // Kritik uyarı banner
        if (criticalQuakes.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade600, Colors.red.shade800],
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'KRİTİK DEPREM UYARISI',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${criticalQuakes.length} adet 5.0+ büyüklüğünde deprem tespit edildi',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Filtre özeti
        if (_selectedCity != null || _selectedDateRange != null || _minMagnitude > 0)
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF1D1E33),
            child: Row(
              children: [
                const Icon(Icons.filter_alt, size: 20, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Filtre aktif: ${earthquakes.length}/${allEarthquakes.length} deprem',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedCity = null;
                      _selectedDateRange = null;
                      _minMagnitude = 0.0;
                      _showOnlySignificant = false;
                    });
                  },
                  child: const Text('Temizle', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),

        // Liste
        Expanded(
          child: earthquakes.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey[600]),
                const SizedBox(height: 16),
                Text(
                  'Filtre kriterlerine uygun deprem bulunamadı',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
          )
              : RefreshIndicator(
            onRefresh: () async => _loadEarthquakes(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: earthquakes.length,
              itemBuilder: (context, index) {
                final quake = earthquakes[index];
                return _buildEarthquakeCard(quake, index);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEarthquakeCard(Earthquake quake, int index) {
    final isCritical = quake.magnitude >= 5.0;
    final isSignificant = quake.magnitude >= 4.0;

    Color getColor() {
      if (isCritical) return Colors.red;
      if (isSignificant) return Colors.orange;
      if (quake.magnitude >= 3.0) return Colors.amber;
      return Colors.green;
    }

    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: isCritical ? 4 : 2,
        color: const Color(0xFF1D1E33),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isCritical ? Colors.red : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showEarthquakeDetails(quake),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Büyüklük göstergesi
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        getColor(),
                        getColor().withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: getColor().withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        quake.magnitude.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Büyüklük',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Deprem bilgileri
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quake.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isCritical ? FontWeight.bold : FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(
                            quake.time,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[300],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.calendar_today, size: 14, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(
                            quake.date,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[300],
                            ),
                          ),
                        ],
                      ),
                      if (quake.depth > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.layers, size: 14, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(
                              'Derinlik: ${quake.depth.toStringAsFixed(1)} km',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Uyarı ikonu
                if (isCritical)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_rounded,
                      color: Colors.red,
                      size: 24,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChartsView(List<Earthquake> earthquakes) {
    if (earthquakes.isEmpty) {
      return Center(
        child: Text('Grafik için yeterli veri yok', style: TextStyle(color: Colors.grey[400])),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMagnitudeDistributionChart(earthquakes),
          const SizedBox(height: 24),
          _buildTimelineChart(earthquakes),
          const SizedBox(height: 24),
          _buildDepthChart(earthquakes),
        ],
      ),
    );
  }

  Widget _buildMagnitudeDistributionChart(List<Earthquake> earthquakes) {
    final ranges = {
      '0-2': 0,
      '2-3': 0,
      '3-4': 0,
      '4-5': 0,
      '5+': 0,
    };

    for (var eq in earthquakes) {
      if (eq.magnitude < 2) ranges['0-2'] = ranges['0-2']! + 1;
      else if (eq.magnitude < 3) ranges['2-3'] = ranges['2-3']! + 1;
      else if (eq.magnitude < 4) ranges['3-4'] = ranges['3-4']! + 1;
      else if (eq.magnitude < 5) ranges['4-5'] = ranges['4-5']! + 1;
      else ranges['5+'] = ranges['5+']! + 1;
    }

    return Card(
      elevation: 2,
      color: const Color(0xFF1D1E33),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Büyüklük Dağılımı',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: ranges.values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final labels = ranges.keys.toList();
                          if (value.toInt() < labels.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                labels[value.toInt()],
                                style: const TextStyle(fontSize: 12, color: Colors.white70),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 12, color: Colors.white70),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  barGroups: ranges.entries.toList().asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.value.toDouble(),
                          gradient: const LinearGradient(
                            colors: [Colors.white, Colors.white60],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          width: 30,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineChart(List<Earthquake> earthquakes) {
    final last24Hours = <int, int>{};
    final now = DateTime.now();

    for (int i = 23; i >= 0; i--) {
      last24Hours[i] = 0;
    }

    int totalIn24Hours = 0;
    for (var eq in earthquakes) {
      try {
        final dateTime = DateFormat('dd.MM.yyyy HH:mm:ss').parse('${eq.date} ${eq.time}');
        final hoursAgo = now.difference(dateTime).inHours;
        if (hoursAgo >= 0 && hoursAgo < 24) {
          last24Hours[hoursAgo] = (last24Hours[hoursAgo] ?? 0) + 1;
          totalIn24Hours++;
        }
      } catch (_) {}
    }

    return Card(
      elevation: 2,
      color: const Color(0xFF1D1E33),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Son 24 Saat Aktivitesi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$totalIn24Hours deprem',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Her saat dilimindeki deprem sayısı (0 = şu an, 23 = 23 saat önce)',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.white.withOpacity(0.1),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 6,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${value.toInt()}s',
                              style: const TextStyle(fontSize: 10, color: Colors.white70),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 11, color: Colors.white70),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: last24Hours.entries
                          .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
                          .toList()
                          .reversed
                          .toList(),
                      isCurved: true,
                      color: Colors.white,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildDepthChart(List<Earthquake> earthquakes) {
    final depthRanges = {
      '0-10 km': 0,
      '10-30 km': 0,
      '30-70 km': 0,
      '70+ km': 0,
    };

    for (var eq in earthquakes.where((e) => e.depth > 0)) {
      if (eq.depth < 10) depthRanges['0-10 km'] = depthRanges['0-10 km']! + 1;
      else if (eq.depth < 30) depthRanges['10-30 km'] = depthRanges['10-30 km']! + 1;
      else if (eq.depth < 70) depthRanges['30-70 km'] = depthRanges['30-70 km']! + 1;
      else depthRanges['70+ km'] = depthRanges['70+ km']! + 1;
    }

    return Card(
      elevation: 2,
      color: const Color(0xFF1D1E33),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Derinlik Dağılımı',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 60,
                  sections: depthRanges.entries.map((entry) {
                    final colors = [
                      Colors.white,
                      Colors.white70,
                      Colors.white54,
                      Colors.white38
                    ];
                    final index = depthRanges.keys.toList().indexOf(entry.key);
                    return PieChartSectionData(
                      value: entry.value.toDouble(),
                      title: '${entry.value}',
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A0E21),
                      ),
                      color: colors[index % colors.length],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: depthRanges.entries.map((entry) {
                final colors = [
                  Colors.white,
                  Colors.white70,
                  Colors.white54,
                  Colors.white38
                ];
                final index = depthRanges.keys.toList().indexOf(entry.key);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: colors[index % colors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.key,
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsView(List<Earthquake> earthquakes) {
    if (earthquakes.isEmpty) {
      return const Center(
          child: Text('İstatistik için veri yok', style: TextStyle(color: Colors.white)));
    }

    final maxMag = earthquakes.map((e) => e.magnitude).reduce((a, b) => a > b ? a : b);
    final minMag = earthquakes.map((e) => e.magnitude).reduce((a, b) => a < b ? a : b);
    final avgMag =
        earthquakes.map((e) => e.magnitude).reduce((a, b) => a + b) / earthquakes.length;

    final critical = earthquakes.where((e) => e.magnitude >= 5.0).length;
    final significant = earthquakes.where((e) => e.magnitude >= 4.0 && e.magnitude < 5.0).length;
    final moderate = earthquakes.where((e) => e.magnitude >= 3.0 && e.magnitude < 4.0).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Özet kartlar
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Toplam',
                  earthquakes.length.toString(),
                  Icons.auto_graph,
                  Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Kritik',
                  critical.toString(),
                  Icons.warning_rounded,
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Önemli',
                  significant.toString(),
                  Icons.priority_high,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Orta',
                  moderate.toString(),
                  Icons.info_outline,
                  Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Büyüklük istatistikleri
          Card(
            elevation: 2,
            color: const Color(0xFF1D1E33),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Büyüklük İstatistikleri',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildStatRow('Maksimum', maxMag.toStringAsFixed(1), Colors.red),
                  const Divider(height: 24, color: Colors.white24),
                  _buildStatRow('Ortalama', avgMag.toStringAsFixed(1), Colors.white),
                  const Divider(height: 24, color: Colors.white24),
                  _buildStatRow('Minimum', minMag.toStringAsFixed(1), Colors.green),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // En güçlü depremler
          Card(
            elevation: 2,
            color: const Color(0xFF1D1E33),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'En Güçlü 5 Deprem',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...(earthquakes.toList()..sort((a, b) => b.magnitude.compareTo(a.magnitude)))
                      .take(5)
                      .map((eq) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              eq.magnitude.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                eq.title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${eq.date} • ${eq.time}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ))
                      .toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      color: const Color(0xFF1D1E33),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1D1E33),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Filtreler',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Şehir filtresi
              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Şehir / Bölge',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: 'Örn: İstanbul, Ankara',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.location_city, color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                ),
                onChanged: (value) {
                  setModalState(() {
                    _selectedCity = value.isEmpty ? null : value;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Tarih aralığı
              ListTile(
                leading: const Icon(Icons.date_range, color: Colors.white70),
                title: Text(
                  _selectedDateRange == null
                      ? 'Tarih Aralığı Seç'
                      : '${DateFormat('dd.MM.yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd.MM.yyyy').format(_selectedDateRange!.end)}',
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: _selectedDateRange != null
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white),
                  onPressed: () {
                    setModalState(() => _selectedDateRange = null);
                  },
                )
                    : null,
                onTap: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.dark(),
                        child: child!,
                      );
                    },
                  );
                  if (range != null) {
                    setModalState(() => _selectedDateRange = range);
                  }
                },
              ),
              const SizedBox(height: 8),

              // Minimum büyüklük
              Text(
                'Minimum Büyüklük: ${_minMagnitude.toStringAsFixed(1)}',
                style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
              ),
              Slider(
                value: _minMagnitude,
                min: 0,
                max: 7,
                divisions: 70,
                label: _minMagnitude.toStringAsFixed(1),
                activeColor: Colors.white,
                inactiveColor: Colors.white24,
                onChanged: (value) {
                  setModalState(() => _minMagnitude = value);
                },
              ),
              const SizedBox(height: 8),

              // Sadece önemli depremler
              SwitchListTile(
                title: const Text('Sadece Önemli Depremler (4.0+)',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('Küçük depremleri filtrele',
                    style: TextStyle(color: Colors.white60)),
                value: _showOnlySignificant,
                activeColor: Colors.white,
                onChanged: (value) {
                  setModalState(() => _showOnlySignificant = value);
                },
              ),
              const SizedBox(height: 16),

              // Uygula butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {});
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0A0E21),
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Filtreleri Uygula'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showEarthquakeDetails(Earthquake quake) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1D1E33),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: quake.magnitude >= 5.0 ? Colors.red : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    quake.magnitude.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    quake.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 32, color: Colors.white24),
            _buildDetailRow(Icons.access_time, 'Saat', quake.time),
            _buildDetailRow(Icons.calendar_today, 'Tarih', quake.date),
            if (quake.depth > 0)
              _buildDetailRow(Icons.layers, 'Derinlik', '${quake.depth.toStringAsFixed(1)} km'),
            if (quake.latitude != 0 && quake.longitude != 0)
              _buildDetailRow(
                Icons.location_on,
                'Koordinatlar',
                '${quake.latitude.toStringAsFixed(4)}, ${quake.longitude.toStringAsFixed(4)}',
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white70),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 15,
              color: Colors.white,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }
}