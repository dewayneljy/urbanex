import 'package:flutter/material.dart';
import '../models.dart';
import '../widgets/common_widgets.dart';
import 'district_detail_screen.dart';

class ScoredDistrict {
  final DistrictData district;
  final double score;
  ScoredDistrict(this.district, this.score);
}

/// Generic results list used by "Where should I live?", "Where to study?"
/// and "Where to open a business?" - a search box plus a ranked list of
/// districts, each shown as a rich card with real quick-stats and a score
/// ring rather than a plain name-and-number row.
class MatchingDistrictsScreen extends StatefulWidget {
  final String title;
  final List<ScoredDistrict> results;
  final String? initialQuery;

  const MatchingDistrictsScreen({super.key, required this.title, required this.results, this.initialQuery});

  @override
  State<MatchingDistrictsScreen> createState() => _MatchingDistrictsScreenState();
}

class _MatchingDistrictsScreenState extends State<MatchingDistrictsScreen> {
  late String _query = widget.initialQuery ?? '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.results
        .where((r) => r.district.district.toLowerCase().contains(_query.toLowerCase()) ||
            r.district.state.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      bottomNavigationBar: const GlobalBottomNav(),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSearchField(hint: 'Search', onChanged: (v) => setState(() => _query = v)),
            const SizedBox(height: 10),
            Text('${filtered.length} districts found', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Text('No districts match your filters', style: TextStyle(color: Colors.grey.shade500)))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final r = filtered[i];
                        final d = r.district;
                        final chips = <Widget>[
                          if (d.incomeMean != null) MiniStatChip(icon: Icons.payments_outlined, label: 'RM${d.incomeMean!.round()}/mo'),
                          if (d.populationDensity != null)
                            MiniStatChip(icon: Icons.groups_outlined, label: '${d.populationDensity!.round()}/km²'),
                          if (d.totalSchools != null)
                            MiniStatChip(icon: Icons.school_outlined, label: '${d.totalSchools!.round()} schools'),
                        ];
                        return RichListCard(
                          rank: i + 1,
                          title: d.district,
                          subtitle: d.state,
                          score: r.score,
                          chips: chips,
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => DistrictDetailScreen(district: d, overrideScore: r.score),
                          )),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}



