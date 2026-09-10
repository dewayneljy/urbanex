import 'package:flutter/material.dart';
import '../models.dart';
import '../services/data_service.dart';
import '../services/local_store_service.dart';
import '../services/auth_screen.dart';
import '../static_geo_data.dart';
import '../widgets/common_widgets.dart';
import '../widgets/explore_layout_widgets.dart';
import 'browse_districts_screen.dart';
import 'compare_districts_screen.dart';
import 'district_detail_screen.dart';
import 'matching_districts_screen.dart';
import 'my_submissions_screen.dart';
import 'business_application_screen.dart';

class WhereToOpenBusinessScreen extends StatefulWidget {
  const WhereToOpenBusinessScreen({super.key});

  @override
  State<WhereToOpenBusinessScreen> createState() => _WhereToOpenBusinessScreenState();
}

class _WhereToOpenBusinessScreenState extends State<WhereToOpenBusinessScreen> {
  String _businessType = 'Food and Beverage';
  String _state = 'All States';
  final Set<String> _priorities = {};
  String _query = '';

  List<DistrictData> _all = [];
  bool _loading = true;

  static const _businessTypes = ['Food and Beverage', 'Services'];
  static const _priorityOptions = ['High density', 'High spending rate', 'High income'];

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
    var filtered = _state == 'All States' ? _all : _all.where((d) => d.state == _state).toList();
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      filtered = filtered.where((d) => d.district.toLowerCase().contains(q) || d.state.toLowerCase().contains(q)).toList();
    }
    final scored = [for (final d in filtered) ScoredDistrict(d, d.businessScore(priorities: _priorities))]
      ..sort((a, b) => b.score.compareTo(a.score));
    return scored;
  }

  void _showAllResults() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MatchingDistrictsScreen(title: 'Matching Districts', results: _computeScored(), initialQuery: _query),
    ));
  }

  Future<void> _startRegisterFlow() async {
    if (_all.isEmpty) return;

    final picked = await showDistrictPickerSheet(
      context,
      options: [..._all]..sort((a, b) => a.district.compareTo(b.district)),
      currentValue: null,
      title: 'Which district do you want to register in?',
    );
    if (picked == null || !mounted) return;

    final account = await LocalStoreService.instance.getCurrentUser();
    if (account == null) {
      final loggedIn = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
      if (loggedIn != true || !mounted) return;
    }
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BusinessApplicationScreen(district: picked),
    ));
  }

  void _openFilterSheet() {
    showExploreFilterSheet(
      context,
      title: 'Filter districts',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Business type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _businessTypes.map((b) {
                return SelectableChip(label: b, selected: _businessType == b, onTap: () => setSheetState(() => setState(() => _businessType = b)));
              }).toList(),
            ),
            const SizedBox(height: 20),
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
      appBar: AppBar(title: const Text('Where to open business?')),
      bottomNavigationBar: const GlobalBottomNav(),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const ExploreHeroBanner(
            icon: Icons.storefront_outlined,
            color: Color(0xFFE05252),
            title: 'Find a spot for your business',
            subtitle: 'Ranked using income, population density, and electricity reliability.',
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
              icon: Icons.assignment_outlined,
              color: const Color(0xFFF2874B),
              title: 'My submissions',
              subtitle: 'Track your applications',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MySubmissionsScreen())),
            ),
            ExploreAction(
              icon: Icons.storefront,
              color: const Color(0xFF3B82F6),
              title: 'Register business',
              subtitle: 'Submit a registration',
              onTap: _startRegisterFlow,
            ),
          ]),
          const SizedBox(height: 22),
          ExploreSectionHeader(title: 'Top districts for business', onSeeAll: _loading ? null : _showAllResults),
          const SizedBox(height: 10),
          if (_loading)
            const LoadingList()
          else if (preview.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No districts match yet', style: TextStyle(color: Colors.grey.shade500))),
            )
          else
            ...preview.map((r) => ExploreThumbnailListCard(
              title: r.district.district,
              subtitle: r.district.state,
              score: r.score,
              tags: [
                if (r.district.incomeMean != null) MiniStatChip(icon: Icons.payments_outlined, label: 'RM${r.district.incomeMean!.round()}/mo'),
                if (r.district.populationDensity != null) MiniStatChip(icon: Icons.groups_outlined, label: '${r.district.populationDensity!.round()}/km²'),
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


