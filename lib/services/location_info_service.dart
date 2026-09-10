import 'dart:convert';
import 'package:http/http.dart' as http;

class GeoPoint {
  final double lat;
  final double lon;
  const GeoPoint(this.lat, this.lon);
}

class WeatherInfo {
  final double temperature; // °C
  final double feelsLike;
  final int humidity; // %
  final double windSpeed; // km/h
  final int weatherCode; // WMO code
  final DateTime fetchedAt;

  WeatherInfo({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.weatherCode,
    required this.fetchedAt,
  });

  /// Short human-readable label for the WMO weather code.
  String get description {
    if (weatherCode == 0) return 'Clear sky';
    if (weatherCode <= 2) return 'Partly cloudy';
    if (weatherCode == 3) return 'Overcast';
    if (weatherCode == 45 || weatherCode == 48) return 'Foggy';
    if (weatherCode >= 51 && weatherCode <= 57) return 'Drizzle';
    if (weatherCode >= 61 && weatherCode <= 67) return 'Rain';
    if (weatherCode >= 80 && weatherCode <= 82) return 'Rain showers';
    if (weatherCode >= 95) return 'Thunderstorm';
    return 'Cloudy';
  }
}

/// Fetches coordinates, current weather, and a representative photo for a
/// place name, using free/no-key APIs (Open-Meteo + Wikipedia). Results are
/// cached in memory for the life of the app session to avoid refetching
/// every time a detail screen is reopened.
class LocationInfoService {
  LocationInfoService._();
  static final LocationInfoService instance = LocationInfoService._();

  final Map<String, GeoPoint?> _geoCache = {};
  final Map<String, WeatherInfo?> _weatherCache = {};
  final Map<String, String?> _imageCache = {};

  Future<GeoPoint?> getCoordinates({required String district, String? state}) async {
    final key = '$district|$state';
    if (_geoCache.containsKey(key)) return _geoCache[key];

    final query = state != null ? '$district, $state' : district;
    try {
      final uri = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search'
            '?name=${Uri.encodeComponent(query)}&count=1&language=en&format=json&country=MY',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          final r = results.first as Map<String, dynamic>;
          final point = GeoPoint((r['latitude'] as num).toDouble(), (r['longitude'] as num).toDouble());
          _geoCache[key] = point;
          return point;
        }
      }
    } catch (_) {
      // Fall through to null - caller shows a graceful empty state.
    }
    _geoCache[key] = null;
    return null;
  }

  Future<WeatherInfo?> getWeather(GeoPoint point) async {
    final key = '${point.lat},${point.lon}';
    if (_weatherCache.containsKey(key)) return _weatherCache[key];

    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
            '?latitude=${point.lat}&longitude=${point.lon}'
            '&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m'
            '&timezone=auto',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final current = data['current'] as Map<String, dynamic>?;
        if (current != null) {
          final info = WeatherInfo(
            temperature: (current['temperature_2m'] as num).toDouble(),
            feelsLike: (current['apparent_temperature'] as num).toDouble(),
            humidity: (current['relative_humidity_2m'] as num).toInt(),
            windSpeed: (current['wind_speed_10m'] as num).toDouble(),
            weatherCode: (current['weather_code'] as num).toInt(),
            fetchedAt: DateTime.now(),
          );
          _weatherCache[key] = info;
          return info;
        }
      }
    } catch (_) {}
    _weatherCache[key] = null;
    return null;
  }

  /// Tries a few likely Wikipedia page titles for a district/state and
  /// returns the first thumbnail image found. Malaysian districts often
  /// don't have an article under any of the titles worth guessing, so if
  /// none of them hit, falls back to a geographic search anchored on the
  /// district's real coordinates - that's tied to the actual place
  /// rather than to guessing how Wikipedia titled it.
  Future<String?> getImageUrl({required String district, String? state}) async {
    final key = '$district|$state';
    if (_imageCache.containsKey(key)) return _imageCache[key];

    final candidates = <String>[
      if (state != null) '$district District, $state',
      if (state != null) '$district, $state',
      district,
      if (state != null) state,
    ];

    for (final title in candidates) {
      final url = await _fetchWikipediaThumbnail(title);
      if (url != null) {
        _imageCache[key] = url;
        return url;
      }
    }

    final point = await getCoordinates(district: district, state: state);
    if (point != null) {
      final url = await _fetchWikipediaThumbnailNear(point);
      if (url != null) {
        _imageCache[key] = url;
        return url;
      }
    }

    _imageCache[key] = null;
    return null;
  }

  Future<String?> _fetchWikipediaThumbnail(String title) async {
    try {
      final uri = Uri.parse(
        'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(title)}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final thumb = data['thumbnail'] as Map<String, dynamic>?;
        final source = thumb?['source'] as String?;
        // Wikipedia often serves small thumbnails - request a larger width.
        if (source != null) {
          return source.replaceFirstMapped(RegExp(r'/(\d+)px-'), (m) => '/800px-');
        }
      }
    } catch (_) {}
    return null;
  }

  /// Finds real Wikipedia articles located near [point] (i.e. actually
  /// at/around this district, regardless of what it's titled) and
  /// returns the first one's thumbnail photo, if any of the nearby
  /// results have one.
  Future<String?> _fetchWikipediaThumbnailNear(GeoPoint point) async {
    try {
      final uri = Uri.parse(
        'https://en.wikipedia.org/w/api.php'
            '?action=query&generator=geosearch'
            '&ggscoord=${point.lat}|${point.lon}&ggsradius=10000&ggslimit=8'
            '&prop=pageimages&piprop=thumbnail&pithumbsize=800'
            '&format=json&origin=*',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final pages = (data['query'] as Map<String, dynamic>?)?['pages'] as Map<String, dynamic>?;
        if (pages != null) {
          for (final page in pages.values) {
            final thumb = (page as Map<String, dynamic>)['thumbnail'] as Map<String, dynamic>?;
            final source = thumb?['source'] as String?;
            if (source != null) return source;
          }
        }
      }
    } catch (_) {}
    return null;
  }
}





