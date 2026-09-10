import 'package:flutter/material.dart';
import '../models.dart';
import '../services/data_service.dart';
import '../services/local_store_service.dart';
import '../services/nav_service.dart';
import '../widgets/common_widgets.dart';
import '../widgets/explore_layout_widgets.dart';
import '../widgets/location_info_widgets.dart';
import 'data_sources_screen.dart';


class InfrastructureListScreen extends StatefulWidget {
  const InfrastructureListScreen({super.key});

  @override
  State<InfrastructureListScreen> createState() => _InfrastructureListScreenState();
}

class _InfrastructureListScreenState extends State<InfrastructureListScreen> {
  List<StateInfraData> _states = [];
  bool _loading = true;
  bool _refreshing = false;
  String _query = '';
  bool _flaggedOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (forceRefresh) setState(() => _refreshing = true);
    final states = await DataService.instance.getStates(forceRefresh: forceRefresh);
    states.sort((a, b) => b.score.compareTo(a.score));
    if (!mounted) return;
    setState(() {
      _states = states;
      _loading = false;
      _refreshing = false;
    });
  }

  void _goToFavorites() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    NavService.currentTab.value = 1;
  }

  @override
  Widget build(BuildContext context) {
    var filtered = _states.where((s) => s.state.toLowerCase().contains(_query.toLowerCase())).toList();
    if (_flaggedOnly) filtered = filtered.where((s) => s.isFlagged).toList();
    final flagged = filtered.where((s) => s.isFlagged).toList();
    final ok = filtered.where((s) => !s.isFlagged).toList();
    final preview = filtered.take(5).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('How is the infrastructure?')),
      bottomNavigationBar: const GlobalBottomNav(),
      body: _loading
          ? const LoadingList()
          : RefreshIndicator(
        onRefresh: () => _load(forceRefresh: true),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const ExploreHeroBanner(
              icon: Icons.bolt,
              color: Color(0xFFF2A93B),
              title: 'Check the infrastructure',
              subtitle: 'Electricity & water access, forest reserves and crime data by state.',
            ),
            const SizedBox(height: 16),
            ExploreSearchBar(
              hint: 'Search states...',
              onChanged: (v) => setState(() => _query = v),
              onFilterTap: () {
                showExploreFilterSheet(
                  context,
                  title: 'Filter states',
                  builder: (ctx) => StatefulBuilder(
                    builder: (ctx, setSheetState) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Flagged states only', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Show states below the infrastructure threshold'),
                          value: _flaggedOnly,
                          onChanged: (v) => setSheetState(() => setState(() => _flaggedOnly = v)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            ExploreQuickActionsGrid(actions: [
              ExploreAction(
                icon: Icons.dataset_outlined,
                color: const Color(0xFF3B82F6),
                title: 'Data sources',
                subtitle: 'Every live dataset used',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DataSourcesScreen())),
              ),
              ExploreAction(
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFE05252),
                title: _flaggedOnly ? 'Showing flagged' : 'Flagged states',
                subtitle: '${_states.where((s) => s.isFlagged).length} below threshold',
                onTap: () => setState(() => _flaggedOnly = !_flaggedOnly),
              ),
              ExploreAction(
                icon: Icons.sync,
                color: const Color(0xFF14B8A6),
                title: 'Refresh data',
                subtitle: _refreshing ? 'Refreshing...' : 'Pull the latest figures',
                onTap: _refreshing ? () {} : () => _load(forceRefresh: true),
              ),
              ExploreAction(
                icon: Icons.star_border,
                color: const Color(0xFFF2A93B),
                title: 'Saved favorites',
                subtitle: 'Your starred places',
                onTap: _goToFavorites,
              ),
            ]),
            const SizedBox(height: 22),
            ExploreSectionHeader(title: 'Top-rated states', onSeeAll: null),
            const SizedBox(height: 10),
            ...preview.map((s) => ExploreThumbnailListCard(
              title: s.state,
              subtitle: 'Malaysia',
              score: s.score,
              tags: [
                if (s.electricityAccess != null) MiniStatChip(icon: Icons.bolt, label: '${s.electricityAccess!.toStringAsFixed(0)}% power'),
                if (s.waterAccess != null) MiniStatChip(icon: Icons.water_drop_outlined, label: '${s.waterAccess!.toStringAsFixed(0)}% water'),
              ],
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StateDetailScreen(state: s))),
            )),
            const SizedBox(height: 10),
            if (flagged.isNotEmpty) ...[
              const SectionTitle('Flagged States'),
              ...flagged.map((s) => _StateTile(state: s, rank: _states.indexOf(s) + 1)),
              const SizedBox(height: 16),
            ],
            if (ok.isNotEmpty) ...[
              const SectionTitle('Other States'),
              ...ok.map((s) => _StateTile(state: s, rank: _states.indexOf(s) + 1)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StateTile extends StatelessWidget {
  final StateInfraData state;
  final int rank;
  const _StateTile({required this.state, required this.rank});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (state.electricityAccess != null)
        MiniStatChip(icon: Icons.bolt, label: '${state.electricityAccess!.toStringAsFixed(0)}% power'),
      if (state.waterAccess != null)
        MiniStatChip(icon: Icons.water_drop_outlined, label: '${state.waterAccess!.toStringAsFixed(0)}% water'),
      if (state.totalCrimes != null)
        MiniStatChip(icon: Icons.shield_outlined, label: '${state.totalCrimes!.round()} crimes/yr'),
    ];
    return RichListCard(
      rank: rank,
      title: state.state,
      subtitle: 'Malaysia',
      score: state.score,
      chips: chips,
      flagged: state.isFlagged,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StateDetailScreen(state: state))),
    );
  }
}

class StateDetailScreen extends StatefulWidget {
  final StateInfraData state;
  const StateDetailScreen({super.key, required this.state});

  @override
  State<StateDetailScreen> createState() => _StateDetailScreenState();
}

class _StateDetailScreenState extends State<StateDetailScreen> {
  bool _isFavorite = false;
  List<TrendPoint> _trend = [];
  bool _loadingTrend = true;

  FavoriteEntry get _entry => FavoriteEntry(type: 'state', state: widget.state.state, score: widget.state.score);

  @override
  void initState() {
    super.initState();
    LocalStoreService.instance.isFavorite(_entry.id).then((v) => setState(() => _isFavorite = v));
    DataService.instance.getStateIncomeTrend(widget.state.state).then((t) {
      if (mounted) setState(() {
        _trend = t;
        _loadingTrend = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Scaffold(
      appBar: AppBar(title: Text(s.state)),
      bottomNavigationBar: const GlobalBottomNav(),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          LocationHeaderImage(district: s.state, state: null),
          const SizedBox(height: 16),
          ScoreHeader(
            score: s.score,
            subtitle: 'Malaysia',
            isFavorite: _isFavorite,
            onToggleFavorite: () async {
              await LocalStoreService.instance.toggleFavorite(_entry);
              setState(() => _isFavorite = !_isFavorite);
            },
          ),
          const SizedBox(height: 16),
          WeatherInfoCard(district: s.state, state: null),
          const SizedBox(height: 24),
          const Text('Score breakdown', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 14),
          StatBarRow(
            label: 'Electricity access',
            valueText: s.electricityAccess != null ? '${s.electricityAccess!.toStringAsFixed(1)}%' : 'No data',
            fraction: (s.electricityAccess ?? 0) / 100,
          ),
          StatBarRow(
            label: 'Water access',
            valueText: s.waterAccess != null ? '${s.waterAccess!.toStringAsFixed(1)}%' : 'No data',
            fraction: (s.waterAccess ?? 0) / 100,
          ),
          StatBarRow(
            label: 'Forest reserves',
            valueText: s.forestReserveKm2 != null ? '${s.forestReserveKm2!.round()} km²' : 'No data',
            fraction: (s.forestReserveKm2 ?? 0) / 45000,
            footnote: s.estimatedFields.contains('forest')
                ? 'No live figure for ${s.state} yet - this is a static reference estimate, not a recent survey.'
                : null,
          ),
          StatBarRow(
            label: 'Crimes recorded (latest year)',
            valueText: s.totalCrimes != null ? s.totalCrimes!.round().toString() : 'No data',
            fraction: 1 - ((s.totalCrimes ?? 5000) / 30000).clamp(0, 1),
            footnote: s.crimesPerCapita == null
                ? null
                : (s.estimatedFields.contains('crime')
                ? 'No crime figure for ${s.state} itself yet - the ${s.crimesPerCapita!.toStringAsFixed(1)} per-1,000 rate used in scoring is the national average across states that do have one.'
                : '≈ ${s.crimesPerCapita!.toStringAsFixed(1)} per 1,000 residents (approximate — based on tracked districts\' population, not the true state total).'),
          ),
          const SizedBox(height: 24),
          const Text('Location', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 10),
          LocationMapCard(district: s.state, state: null),
          const SizedBox(height: 10),
          const Text('Trend', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 10),
          _loadingTrend
              ? const SizedBox(height: 110, child: Center(child: CircularProgressIndicator()))
              : TrendSparkline(points: _trend, formatValue: (v) => 'RM${v.round()}'),
          const SizedBox(height: 6),
          Text(
            'Mean household income across ${s.state} over recent years (data.gov.my, "All Districts" aggregate).',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }
}


