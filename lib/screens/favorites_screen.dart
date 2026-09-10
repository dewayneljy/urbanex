import 'package:flutter/material.dart';
import '../models.dart';
import '../services/local_store_service.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'district_detail_screen.dart';
import 'infrastructure_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<FavoriteEntry> _favorites = [];
  List<DistrictData> _districts = [];
  List<StateInfraData> _states = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    // Refresh whenever a favorite is toggled anywhere else in the app -
    // needed because this screen stays alive (and un-rebuilt) inside the
    // bottom-nav's IndexedStack rather than being recreated on each visit.
    LocalStoreService.favoritesRevision.addListener(_load);
  }

  @override
  void dispose() {
    LocalStoreService.favoritesRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final favs = await LocalStoreService.instance.getFavorites();
    // Also pull the full live datasets so each favorite can show real
    // quick-stat chips, not just its saved score.
    final districts = await DataService.instance.getDistricts();
    final states = await DataService.instance.getStates();
    if (!mounted) return;
    setState(() {
      _favorites = favs;
      _districts = districts;
      _states = states;
      _loading = false;
    });
  }



  DistrictData? _findDistrict(FavoriteEntry e) {
    for (final d in _districts) {
      if (d.state == e.state && d.district == e.district) return d;
    }
    return null;
  }

  StateInfraData? _findState(FavoriteEntry e) {
    for (final s in _states) {
      if (s.state == e.state) return s;
    }
    return null;
  }

  Future<void> _confirmDeleteAll() async {
    final count = _favorites.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all favorites?'),
        content: Text(
          'This removes all $count saved favorite${count == 1 ? '' : 's'} from this device. This can\'t be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.bad, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await LocalStoreService.instance.clearAllFavorites();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All favorites deleted')));
  }

  @override
  Widget build(BuildContext context) {
    final states = _favorites.where((f) => f.type == 'state').toList();
    final districts = _favorites.where((f) => f.type == 'district').toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Favorites', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              if (_favorites.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _confirmDeleteAll,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading) const LoadingList(),
          if (!_loading && _favorites.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.star_border, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text('No favorites yet', style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text('Tap the star on any state or district to save it here.',
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                ),
              ),
            ),
          if (states.isNotEmpty) ...[
            const SectionTitle('States'),
            ...states.map((f) => _FavoriteCard(entry: f, matchedState: _findState(f))),
            const SizedBox(height: 16),
          ],
          if (districts.isNotEmpty) ...[
            const SectionTitle('Districts'),
            ...districts.map((f) => _FavoriteCard(entry: f, matchedDistrict: _findDistrict(f))),
          ],
        ],
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  final FavoriteEntry entry;
  final DistrictData? matchedDistrict;
  final StateInfraData? matchedState;
  const _FavoriteCard({required this.entry, this.matchedDistrict, this.matchedState});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    final d = matchedDistrict;
    final s = matchedState;
    if (d != null) {
      if (d.incomeMean != null) chips.add(MiniStatChip(icon: Icons.payments_outlined, label: 'RM${d.incomeMean!.round()}/mo'));
      if (d.populationDensity != null) chips.add(MiniStatChip(icon: Icons.groups_outlined, label: '${d.populationDensity!.round()}/km²'));
      if (d.totalSchools != null) chips.add(MiniStatChip(icon: Icons.school_outlined, label: '${d.totalSchools!.round()} schools'));
    } else if (s != null) {
      if (s.electricityAccess != null) chips.add(MiniStatChip(icon: Icons.bolt, label: '${s.electricityAccess!.toStringAsFixed(0)}% power'));
      if (s.waterAccess != null) chips.add(MiniStatChip(icon: Icons.water_drop_outlined, label: '${s.waterAccess!.toStringAsFixed(0)}% water'));
      if (s.totalCrimes != null) chips.add(MiniStatChip(icon: Icons.shield_outlined, label: '${s.totalCrimes!.round()} crimes/yr'));
    }

    return RichListCard(
      title: entry.title,
      subtitle: entry.type == 'district' ? entry.subtitle : 'Malaysia',
      score: (d?.livabilityScore() ?? s?.score ?? entry.score),
      chips: chips,
      flagged: s?.isFlagged ?? false,
      onTap: () {
        if (entry.type == 'state' && s != null) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => StateDetailScreen(state: s)));
        } else if (d != null) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => DistrictDetailScreen(district: d)));
        }
      },
    );
  }
}



