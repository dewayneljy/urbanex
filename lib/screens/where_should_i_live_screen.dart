import 'package:flutter/material.dart';
import '../models.dart';
import '../services/data_service.dart';
import '../services/nav_service.dart';
import '../static_geo_data.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/explore_layout_widgets.dart';
import 'browse_districts_screen.dart';
import 'compare_districts_screen.dart';
import 'matching_districts_screen.dart';
import 'district_detail_screen.dart';

class WhereShouldILiveScreen extends StatefulWidget {
  const WhereShouldILiveScreen({super.key});

  @override
  State<WhereShouldILiveScreen> createState() => _WhereShouldILiveScreenState();
}

class _WhereShouldILiveScreenState extends State<WhereShouldILiveScreen> {
  double _budget = 5000;
  String _state = 'All States';
  final Set<String> _priorities = {};
  String _query = '';

  List<DistrictData> _all = [];
  bool _loading = true;

  static const _priorityOptions = [
    'Government services nearby',
    'Low poverty rate',
    'Low population',
    'Low crime rate',
    'Entertainment',
  ];

  @override
  void initState() {
    super.initState();
    DataService.instance.getDistricts().then((d) {
      if (mounted) setState(() {
        _all = d;
        _loading = false;
      });
    });
  }

  List<ScoredDistrict> _computeScored() {
    var filtered = _all.where((d) => (d.incomeMean ?? 0) <= _budget * 1.6).toList();
    if (_state != 'All States') filtered = filtered.where((d) => d.state == _state).toList();
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      filtered = filtered.where((d) => d.district.toLowerCase().contains(q) || d.state.toLowerCase().contains(q)).toList();
    }
    final scored = [for (final d in filtered) ScoredDistrict(d, d.livabilityScore(priorities: _priorities))]
      ..sort((a, b) => b.score.compareTo(a.score));
    return scored;
  }

  void _showAllResults() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MatchingDistrictsScreen(title: 'Affordable Districts', results: _computeScored(), initialQuery: _query),
    ));
  }

  void _goToFavorites() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    NavService.currentTab.value = 1;
  }

  void _openFilterSheet() {
    showExploreFilterSheet(
      context,
      title: 'Filter districts',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Budget range', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            Text('< RM${_budget.round()}', style: TextStyle(color: Colors.grey.shade600)),
            Slider(
              value: _budget,
              min: 1000,
              max: 15000,
              divisions: 28,
              label: 'RM${_budget.round()}',
              onChanged: (v) => setSheetState(() => setState(() => _budget = v)),
            ),
            const SizedBox(height: 12),
            const Text('States', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: ['All States', ...kAllStates].map((s) {
                return SelectableChip(label: s, selected: _state == s, onTap: () => setSheetState(() => setState(() => _state = s)));
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text('Priorities', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _priorityOptions.map((p) {
                final selected = _priorities.contains(p);
                return SelectableChip(
                  label: p,
                  selected: selected,
                  onTap: () => setSheetState(() => setState(() => selected ? _priorities.remove(p) : _priorities.add(p))),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showAllResults();
                },
                child: const Text('Show matching districts'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _loading ? <ScoredDistrict>[] : _computeScored().take(5).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Where should I live?')),
      bottomNavigationBar: const GlobalBottomNav(),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const ExploreHeroBanner(
            icon: Icons.home_outlined,
            color: Color(0xFF3B82F6),
            title: 'Find your district',
            subtitle: 'Matched on income, poverty rate, density and safety - live from data.gov.my.',
          ),
          const SizedBox(height: 16),
          ExploreSearchBar(
            hint: 'Search for a district or state...',
            onChanged: (v) => setState(() => _query = v),
            onSubmitted: (_) => _showAllResults(),
            onFilterTap: _openFilterSheet,
          ),
          const SizedBox(height: 18),
          ExploreQuickActionsGrid(actions: [
            ExploreAction(
              icon: Icons.travel_explore_outlined,
              color: const Color(0xFF14B8A6),
              title: 'Browse districts',
              subtitle: 'Explore every state',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BrowseDistrictsScreen())),
            ),
            ExploreAction(
              icon: Icons.compare_arrows,
              color: const Color(0xFF8B5CF6),
              title: 'Compare districts',
              subtitle: 'Side-by-side stats',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CompareDistrictsScreen())),
            ),
            ExploreAction(
              icon: Icons.star_border,
              color: const Color(0xFFF2A93B),
              title: 'Saved favorites',
              subtitle: 'Your starred places',
              onTap: _goToFavorites,
            ),
            ExploreAction(
              icon: Icons.tune,
              color: const Color(0xFF3B82F6),
              title: 'Adjust filters',
              subtitle: 'Budget, state & priorities',
              onTap: _openFilterSheet,
            ),
          ]),
          const SizedBox(height: 22),
          ExploreSectionHeader(title: 'Top matching districts', onSeeAll: _loading ? null : _showAllResults),
          const SizedBox(height: 10),
          if (_loading)
            const LoadingList()
          else if (preview.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No districts match yet - try adjusting filters', style: TextStyle(color: Colors.grey.shade500))),
            )
          else
            ...preview.map((r) => ExploreThumbnailListCard(
              title: r.district.district,
              subtitle: r.district.state,
              score: r.score,
              tags: [
                if (r.district.incomeMean != null) MiniStatChip(icon: Icons.payments_outlined, label: 'RM${r.district.incomeMean!.round()}/mo'),
                if (r.district.totalSchools != null) MiniStatChip(icon: Icons.school_outlined, label: '${r.district.totalSchools!.round()} schools'),
              ],
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => DistrictDetailScreen(district: r.district, overrideScore: r.score),
              )),
            )),
        ],
      ),
    );
  }
}


