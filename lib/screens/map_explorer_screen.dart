import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models.dart';
import '../services/data_service.dart';
import '../services/location_info_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'district_detail_screen.dart';

/// Which score is used to color every marker on the map.
enum MapMetric { livability, business, study }

extension on MapMetric {
  String get label {
    switch (this) {
      case MapMetric.livability:
        return 'Livability';
      case MapMetric.business:
        return 'Business';
      case MapMetric.study:
        return 'Study';
    }
  }
}

/// Full interactive map of every district UrbanEx tracks, color-coded by
/// whichever score the user picks (livability / business / study).
/// Complements the single-pin map already shown on a district's own
/// detail screen by letting someone see every district at once - by
/// state, by score tier - and jump straight into any of them from here.
class MapExplorerScreen extends StatefulWidget {
  const MapExplorerScreen({super.key});

  @override
  State<MapExplorerScreen> createState() => _MapExplorerScreenState();
}

class _MapExplorerScreenState extends State<MapExplorerScreen> {
  List<DistrictData> _districts = [];
  bool _loadingDistricts = true;

  // key = DistrictData.key ('$state|$district')
  final Map<String, GeoPoint> _coords = {};
  bool _loadingCoords = false;
  int _geocoded = 0;
  int _geocodeTotal = 0;

  MapMetric _metric = MapMetric.livability;
  DistrictData? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final districts = await DataService.instance.getDistricts();
    if (!mounted) return;
    setState(() {
      _districts = districts;
      _loadingDistricts = false;
      _loadingCoords = true;
      _geocodeTotal = districts.length;
    });
    await _geocodeAll(districts);
  }

  /// Looks up coordinates for every tracked district, a handful at a
  /// time so markers appear progressively instead of the screen staying
  /// blank until all ~90 districts have been geocoded.
  /// LocationInfoService caches each result for the life of the app
  /// session, so reopening this screen later is instant.
  Future<void> _geocodeAll(List<DistrictData> districts) async {
    const batchSize = 8;
    for (var i = 0; i < districts.length; i += batchSize) {
      final batch = districts.skip(i).take(batchSize);
      await Future.wait(batch.map((d) async {
        final point = await LocationInfoService.instance.getCoordinates(district: d.district, state: d.state);
        if (point != null) _coords[d.key] = point;
        _geocoded++;
      }));
      if (mounted) setState(() {});
    }
    if (mounted) setState(() => _loadingCoords = false);
  }

  double _scoreFor(DistrictData d) {
    switch (_metric) {
      case MapMetric.business:
        return d.businessScore();
      case MapMetric.study:
        return d.studyScore(stage: 'secondary');
      case MapMetric.livability:
        return d.livabilityScore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];
    for (final d in _districts) {
      final point = _coords[d.key];
      if (point == null) continue;
      final score = _scoreFor(d);
      markers.add(
        Marker(
          point: LatLng(point.lat, point.lon),
          width: 34,
          height: 34,
          child: GestureDetector(
            onTap: () => setState(() => _selected = d),
            child: _MapDot(color: AppColors.scoreColor(score), selected: _selected?.key == d.key),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('District map')),
      bottomNavigationBar: const GlobalBottomNav(),
      body: _loadingDistricts
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(3.6, 109.5),
              initialZoom: 5.3,
              minZoom: 4,
              maxZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.assi',
              ),
              MarkerLayer(markers: markers),
            ],
          ),

          // --- Metric switcher -------------------------------------
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor.withOpacity(0.95),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: MapMetric.values.map((m) {
                  return SelectableChip(
                    label: m.label,
                    selected: _metric == m,
                    onTap: () => setState(() => _metric = m),
                  );
                }).toList(),
              ),
            ),
          ),

          // --- Geocoding progress -----------------------------------
          if (_loadingCoords)
            Positioned(
              top: 66,
              left: 14,
              right: 14,
              child: _ProgressBanner(done: _geocoded, total: _geocodeTotal),
            ),

          // --- Legend ------------------------------------------------
          const Positioned(bottom: 14, left: 14, child: _ScoreLegend()),

          // --- Selected district card ---------------------------------
          if (_selected != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: _SelectedDistrictCard(
                district: _selected!,
                score: _scoreFor(_selected!),
                metricLabel: _metric.label,
                onClose: () => setState(() => _selected = null),
                onViewDetails: () {
                  final d = _selected!;
                  final score = _scoreFor(d);
                  setState(() => _selected = null);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => DistrictDetailScreen(district: d, overrideScore: score),
                  ));
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _MapDot extends StatelessWidget {
  final Color color;
  final bool selected;
  const _MapDot({required this.color, required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.3 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
        ),
      ),
    );
  }
}

class _ProgressBanner extends StatelessWidget {
  final int done;
  final int total;
  const _ProgressBanner({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : done / total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, value: fraction == 0 ? null : fraction),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Locating districts... $done/$total', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _ScoreLegend extends StatelessWidget {
  const _ScoreLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _legendRow(AppColors.good, 'Good (75+)'),
          const SizedBox(height: 4),
          _legendRow(AppColors.moderate, 'Moderate (50-74)'),
          const SizedBox(height: 4),
          _legendRow(AppColors.bad, 'Needs work (<50)'),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 11.5)),
      ],
    );
  }
}

class _SelectedDistrictCard extends StatelessWidget {
  final DistrictData district;
  final double score;
  final String metricLabel;
  final VoidCallback onClose;
  final VoidCallback onViewDetails;

  const _SelectedDistrictCard({
    required this.district,
    required this.score,
    required this.metricLabel,
    required this.onClose,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ScoreBadge(score: score),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(district.district, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('${district.state} · $metricLabel score', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: onClose, splashRadius: 20),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onViewDetails,
              child: const Text('View details'),
            ),
          ),
        ],
      ),
    );
  }
}


