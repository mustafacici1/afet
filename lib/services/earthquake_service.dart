import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/earthquake.dart';

class EarthquakeService {
  static Future<List<Earthquake>> fetchEarthquakes() async {
    final uri = Uri.parse(
      'https://api.orhanaydogdu.com.tr/deprem/kandilli/live',
    );

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final List list = decoded['result'];
      return list.map((e) => Earthquake.fromJson(e)).toList();
    } else {
      throw Exception('Deprem verileri alınamadı');
    }
  }

  static Future<Earthquake?> fetchLatestEarthquake() async {
    try {
      final earthquakes = await fetchEarthquakes();
      if (earthquakes.isNotEmpty) {
        // The API seems to return the latest first, but we sort just in case.
        earthquakes.sort((a, b) => b.rawDateTime.compareTo(a.rawDateTime));
        return earthquakes.first;
      }
      return null;
    } catch (e) {
      // Return null or re-throw to let the caller handle it
      print('Could not fetch latest earthquake: $e');
      return null;
    }
  }
}