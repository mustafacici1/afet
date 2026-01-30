class Earthquake {
  final String title;
  final double magnitude;
  final String date;
  final String time;
  final double depth;
  final double latitude;
  final double longitude;
  final DateTime rawDateTime;

  Earthquake({
    required this.title,
    required this.magnitude,
    required this.date,
    required this.time,
    required this.depth,
    required this.latitude,
    required this.longitude,
    required this.rawDateTime,
  });

  factory Earthquake.fromJson(Map<String, dynamic> json) {
    String dateStr = '-';
    String timeStr = '-';
    DateTime parsedDateTime = DateTime.now();

    if (json['date_time'] != null) {
      try {
        final dateTimeString = json['date_time'].toString();
        parsedDateTime = DateTime.parse(dateTimeString);
        final localDateTime = parsedDateTime.toLocal();

        final dateParts = localDateTime.toString().split(' ')[0].split('-');
        if (dateParts.length == 3) {
          dateStr = '${dateParts[2]}.${dateParts[1]}.${dateParts[0]}';
        }
        timeStr = localDateTime.toString().split(' ')[1].substring(0, 8);

      } catch (e) {
        print('Tarih parse hatası: $e');
      }
    }

    // Koordinatları geojson'dan alalım
    double lat = 0.0;
    double lng = 0.0;
    if (json['geojson'] != null && json['geojson']['coordinates'] != null) {
      final coords = json['geojson']['coordinates'];
      if (coords.length >= 2) {
        lng = (coords[0] as num?)?.toDouble() ?? 0.0;
        lat = (coords[1] as num?)?.toDouble() ?? 0.0;
      }
    }

    return Earthquake(
      title: json['title'] ?? 'Bilinmeyen Bölge',
      magnitude: (json['mag'] as num?)?.toDouble() ?? 0.0,
      date: dateStr,
      time: timeStr,
      depth: (json['depth'] as num?)?.toDouble() ?? 0.0,
      latitude: lat,
      longitude: lng,
      rawDateTime: parsedDateTime,
    );
  }
}