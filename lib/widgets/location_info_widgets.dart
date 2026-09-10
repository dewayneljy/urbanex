import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_info_service.dart';
import '../theme/app_theme.dart';

/// Header photo for a district/state detail screen. Fetches a real photo
/// from Wikipedia; falls back to a simple gradient placeholder if none is
/// found or the request fails.
class LocationHeaderImage extends StatefulWidget {
  final String district;
  final String? state;
  const LocationHeaderImage({super.key, required this.district, this.state});

  @override
  State<LocationHeaderImage> createState() => _LocationHeaderImageState();
}

class _LocationHeaderImageState extends State<LocationHeaderImage> {
  String? _url;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    LocationInfoService.instance.getImageUrl(district: widget.district, state: widget.state).then((url) {
      if (mounted) setState(() {
        _url = url;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: _loading
            ? Container(color: Colors.grey.shade300)
            : _url == null
            ? _placeholder()
            : Image.network(
          _url!,
          fit: BoxFit.cover,
          loadingBuilder: (ctx, child, progress) =>
          progress == null ? child : Container(color: Colors.grey.shade300),
          errorBuilder: (ctx, err, stack) => _placeholder(),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.brand.withOpacity(0.7), AppColors.brandDark]),
      ),
      child: const Center(child: Icon(Icons.location_city, color: Colors.white, size: 40)),
    );
  }
}

/// Compact current-weather card: temperature, condition, feels-like,
/// humidity, and wind - enough to be useful without overloading the
/// detail screen.
class WeatherInfoCard extends StatefulWidget {
  final String district;
  final String? state;
  const WeatherInfoCard({super.key, required this.district, this.state});

  @override
  State<WeatherInfoCard> createState() => _WeatherInfoCardState();
}

class _WeatherInfoCardState extends State<WeatherInfoCard> {
  WeatherInfo? _weather;
  bool _loading = true;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final point = await LocationInfoService.instance.getCoordinates(district: widget.district, state: widget.state);
    if (point == null) {
      if (mounted) setState(() {
        _loading = false;
        _unavailable = true;
      });
      return;
    }
    final weather = await LocationInfoService.instance.getWeather(point);
    if (mounted) setState(() {
      _weather = weather;
      _loading = false;
      _unavailable = weather == null;
    });
  }

  IconData get _icon {
    final code = _weather?.weatherCode ?? 0;
    if (code == 0) return Icons.wb_sunny_outlined;
    if (code <= 3) return Icons.wb_cloudy_outlined;
    if (code == 45 || code == 48) return Icons.foggy;
    if (code >= 51 && code <= 67) return Icons.grain;
    if (code >= 80 && code <= 82) return Icons.beach_access_outlined;
    if (code >= 95) return Icons.thunderstorm_outlined;
    return Icons.cloud_outlined;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())));
    }
    if (_unavailable) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.cloud_off_outlined, color: Colors.grey.shade400),
              const SizedBox(width: 10),
              Text('Weather unavailable right now', style: TextStyle(color: Colors.grey.shade500)),
            ],
          ),
        ),
      );
    }

    final w = _weather!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icon, color: AppColors.brand, size: 30),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${w.temperature.round()}°C', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(w.description, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
                const Spacer(),
                Text('Live weather', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _WeatherStat(icon: Icons.thermostat_outlined, label: 'Feels like', value: '${w.feelsLike.round()}°C'),
                _WeatherStat(icon: Icons.water_drop_outlined, label: 'Humidity', value: '${w.humidity}%'),
                _WeatherStat(icon: Icons.air, label: 'Wind', value: '${w.windSpeed.round()} km/h'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _WeatherStat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
      ],
    );
  }
}

/// Small OpenStreetMap view centered on the district/state, with a single
/// marker. Uses flutter_map (no API key needed).
class LocationMapCard extends StatefulWidget {
  final String district;
  final String? state;
  const LocationMapCard({super.key, required this.district, this.state});

  @override
  State<LocationMapCard> createState() => _LocationMapCardState();
}

class _LocationMapCardState extends State<LocationMapCard> {
  GeoPoint? _point;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    LocationInfoService.instance.getCoordinates(district: widget.district, state: widget.state).then((p) {
      if (mounted) setState(() {
        _point = p;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    }
    if (_point == null) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16)),
        child: Text("Couldn't locate this place on the map", style: TextStyle(color: Colors.grey.shade500)),
      );
    }

    final center = LatLng(_point!.lat, _point!.lon);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 200,
        child: FlutterMap(
          options: MapOptions(initialCenter: center, initialZoom: 10.5, interactionOptions: const InteractionOptions(flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag)),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.assi',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: center,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_pin, color: Colors.red, size: 36),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


