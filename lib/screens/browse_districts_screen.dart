import 'package:flutter/material.dart';
import '../models.dart';
import '../services/data_service.dart';
import '../static_geo_data.dart';
import '../widgets/common_widgets.dart';
import 'matching_districts_screen.dart';
import 'map_explorer_screen.dart';

/// Lets someone browse every state and district directly, rather than
/// going through one of the matching flows (Where should I live?, Where
/// to study?, etc). Top level is one rich card per state - same visual
/// language as every other list in the app (RichListCard: score-tier
/// stripe, ScoreRing, quick-stat chips) - summarising that state's
/// average livability and its best district. Tapping a state opens the
/// same MatchingDistrictsScreen used by the matching flows, ranked and
/// searchable, so drilling into a state feels identical to using any
/// other part of the app. Typing at the top level instead flattens
/// straight into a single ranked list of matching districts across every
/// state, for jumping directly to a district by name.
class BrowseDistrictsScreen extends StatefulWidget {
  const BrowseDistrictsScreen({super.key});

  @override
  State<BrowseDistrictsScreen> createState() => _BrowseDistrictsScreenState();
}

class _BrowseDistrictsScreenState extends State<BrowseDistrictsScreen> {
  List<DistrictData> _districts = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    DataService.instance.getDistricts().then((districts) {
      if (!mounted) return;
      setState(() {
        _districts = districts;
        _loading = false;
      });
    });
  }

  Map<String, List<DistrictData>> get _byState {
    final map = <String, List<DistrictData>>{};
    for (final state in kAllStates) {
      final inState = _districts.where((d) => d.state == state).toList()
        ..sort((a, b) => b.livabilityScore().compareTo(a.livabilityScore()));
      if (inState.isNotEmpty) map[state] = inState;
    }
    return map;
  }

  List<ScoredDistrict> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final matches = _districts.where((d) => d.district.toLowerCase().contains(q) || d.state.toLowerCase().contains(q)).toList()
      ..sort((a, b) => b.livabilityScore().compareTo(a.livabilityScore()));
    return matches.map((d) => ScoredDistrict(d, d.livabilityScore())).toList();
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().isNotEmpty;
    final grouped = _byState;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse districts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'View on map',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MapExplorerScreen())),
          ),
        ],
      ),
      bottomNavigationBar: const GlobalBottomNav(),
      body: _loading
          ? const LoadingList()
          : Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSearchField(hint: 'Search states or districts', onChanged: (v) => setState(() => _query = v)),
            const SizedBox(height: 10),
            Text(
              searching
                  ? '${_filtered.length} districts found'
                  : '${grouped.length} states · ${_districts.length} districts tracked',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Expanded(child: searching ? _buildFlatList() : _buildStateList(grouped)),
          ],
        ),
      ),
    );
  }

  Widget _buildFlatList() {
    final results = _filtered;
    if (results.isEmpty) {
      return Center(child: Text('No states or districts match your search', style: TextStyle(color: Colors.grey.shade500)));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final r = results[i];
        final d = r.district;
        final chips = <Widget>[
          if (d.incomeMean != null) MiniStatChip(icon: Icons.payments_outlined, label: 'RM${d.incomeMean!.round()}/mo'),
          if (d.totalSchools != null) MiniStatChip(icon: Icons.school_outlined, label: '${d.totalSchools!.round()} schools'),
        ];
        return RichListCard(
          rank: i + 1,
          title: d.district,
          subtitle: d.state,
          score: r.score,
          chips: chips,
          onTap: () => _openState(d.state),
        );
      },
    );
  }

  Widget _buildStateList(Map<String, List<DistrictData>> grouped) {
    final states = grouped.keys.toList();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: states.length,
      itemBuilder: (context, i) {
        final state = states[i];
        final districts = grouped[state]!;
        final avgScore = districts.map((d) => d.livabilityScore()).reduce((a, b) => a + b) / districts.length;
        final best = districts.first; // already sorted by score, descending

        final chips = <Widget>[
          MiniStatChip(icon: Icons.emoji_events_outlined, label: 'Top: ${best.district}'),
          MiniStatChip(icon: Icons.map_outlined, label: '${districts.length} district${districts.length == 1 ? '' : 's'}'),
        ];

        return RichListCard(
          title: state,
          subtitle: 'Average livability across tracked districts',
          score: avgScore,
          chips: chips,
          onTap: () => _openState(state),
        );
      },
    );
  }

  void _openState(String state) {
    final districts = _districts.where((d) => d.state == state).toList()
      ..sort((a, b) => b.livabilityScore().compareTo(a.livabilityScore()));
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MatchingDistrictsScreen(
        title: state,
        results: districts.map((d) => ScoredDistrict(d, d.livabilityScore())).toList(),
      ),
    ));
  }
}


