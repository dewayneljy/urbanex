import 'package:flutter/material.dart';
import '../models.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Lets the user pick any two tracked districts and see their real
/// indicators side by side - income, density, schools, and the state
/// safety figure - so they can make an actual decision instead of only
/// browsing a single ranked list at a time.
class CompareDistrictsScreen extends StatefulWidget {
  const CompareDistrictsScreen({super.key});

  @override
  State<CompareDistrictsScreen> createState() => _CompareDistrictsScreenState();
}

class _CompareDistrictsScreenState extends State<CompareDistrictsScreen> {
  List<DistrictData> _all = [];
  bool _loading = true;
  DistrictData? _left;
  DistrictData? _right;

  @override
  void initState() {
    super.initState();
    DataService.instance.getDistricts().then((d) {
      final sorted = [...d]..sort((a, b) => a.district.compareTo(b.district));
      setState(() {
        _all = sorted;
        _loading = false;
        if (sorted.length >= 2) {
          _left = sorted[0];
          _right = sorted[1];
        }
      });
    });
  }

  Future<void> _pickDistrict(bool isLeft) async {
    final picked = await showModalBottomSheet<DistrictData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DistrictPickerSheet(
        label: isLeft ? 'District A' : 'District B',
        accentColor: isLeft ? AppColors.compareA : AppColors.compareB,
        options: _all,
        currentValue: isLeft ? _left : _right,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isLeft) {
          _left = picked;
        } else {
          _right = picked;
        }
      });
    }
  }

  void _swap() {
    setState(() {
      final tmp = _left;
      _left = _right;
      _right = tmp;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compare Districts')),
      bottomNavigationBar: const GlobalBottomNav(),
      body: _loading
          ? const LoadingList()
          : ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            'Pick two districts to see how they stack up on income, schooling, density, and safety.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          _PickerRow(
            left: _left,
            right: _right,
            onTapLeft: () => _pickDistrict(true),
            onTapRight: () => _pickDistrict(false),
            onSwap: _swap,
          ),
          const SizedBox(height: 24),
          if (_left == null || _right == null)
            const _EmptyState()
          else if (_left!.key == _right!.key)
            const _SamePickState()
          else
            _ComparisonBody(left: _left!, right: _right!),
        ],
      ),
    );
  }
}

/// The two district-picker cards with a swap control between them.
class _PickerRow extends StatelessWidget {
  final DistrictData? left;
  final DistrictData? right;
  final VoidCallback onTapLeft;
  final VoidCallback onTapRight;
  final VoidCallback onSwap;

  const _PickerRow({
    required this.left,
    required this.right,
    required this.onTapLeft,
    required this.onTapRight,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _DistrictPickerCard(
              label: 'District A',
              accentColor: AppColors.compareA,
              value: left,
              onTap: onTapLeft,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Material(
                  color: Theme.of(context).cardColor,
                  shape: CircleBorder(side: BorderSide(color: Colors.grey.shade300)),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: (left != null && right != null) ? onSwap : null,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.swap_horiz, size: 20, color: AppColors.brand),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _DistrictPickerCard(
              label: 'District B',
              accentColor: AppColors.compareB,
              value: right,
              onTap: onTapRight,
            ),
          ),
        ],
      ),
    );
  }
}

class _DistrictPickerCard extends StatelessWidget {
  final String label;
  final Color accentColor;
  final DistrictData? value;
  final VoidCallback onTap;

  const _DistrictPickerCard({
    required this.label,
    required this.accentColor,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final d = value;
    return HoverLiftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5, fontWeight: FontWeight.w600)),
              const Spacer(),
              Icon(d == null ? Icons.add_circle_outline : Icons.edit_outlined, size: 16, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(height: 10),
          if (d == null)
            Text('Tap to choose', style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic, fontSize: 13.5))
          else ...[
            Text(d.district, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(d.state, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (d.incomeMean != null || d.totalSchools != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (d.incomeMean != null) MiniStatChip(icon: Icons.payments_outlined, label: 'RM${d.incomeMean!.round()}/mo'),
                  if (d.totalSchools != null) MiniStatChip(icon: Icons.school_outlined, label: '${d.totalSchools!.round()} schools'),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Searchable bottom sheet used to pick a district for either side.
class _DistrictPickerSheet extends StatefulWidget {
  final String label;
  final Color accentColor;
  final List<DistrictData> options;
  final DistrictData? currentValue;

  const _DistrictPickerSheet({
    required this.label,
    required this.accentColor,
    required this.options,
    required this.currentValue,
  });

  @override
  State<_DistrictPickerSheet> createState() => _DistrictPickerSheetState();
}

class _DistrictPickerSheetState extends State<_DistrictPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final results = q.isEmpty
        ? widget.options
        : widget.options.where((d) => d.district.toLowerCase().contains(q) || d.state.toLowerCase().contains(q)).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: widget.accentColor, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text('Choose ${widget.label}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AppSearchField(hint: 'Search states or districts', onChanged: (v) => setState(() => _query = v)),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: results.isEmpty
                    ? Center(child: Text('No districts match your search', style: TextStyle(color: Colors.grey.shade500)))
                    : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final d = results[i];
                    final selected = widget.currentValue?.key == d.key;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: HoverLiftCard(
                        selected: selected,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        onTap: () => Navigator.of(context).pop(d),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d.district,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: selected ? Colors.white : null,
                                    ),
                                  ),
                                  Text(
                                    d.state,
                                    style: TextStyle(fontSize: 12, color: selected ? Colors.white70 : Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            ScoreBadge(score: d.livabilityScore()),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.compare_arrows, size: 44, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('Pick two districts above to compare them', style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _SamePickState extends StatelessWidget {
  const _SamePickState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.info_outline, size: 40, color: AppColors.moderate),
          const SizedBox(height: 12),
          Text('That\'s the same district on both sides', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Pick two different districts to see a comparison', style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5)),
        ],
      ),
    );
  }
}

/// Everything shown once two distinct districts are selected: headline
/// score comparison, a 3-score "best for" table, categorized detailed
/// metrics, and an overall tally verdict.
class _ComparisonBody extends StatelessWidget {
  final DistrictData left;
  final DistrictData right;
  const _ComparisonBody({required this.left, required this.right});

  double _educationScore(DistrictData d) {
    final stages = ['primary', 'secondary', 'tertiary'];
    final scores = stages.map((s) => d.studyScore(stage: s)).toList();
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  @override
  Widget build(BuildContext context) {
    final leftLivability = left.livabilityScore();
    final rightLivability = right.livabilityScore();
    final leftEdu = _educationScore(left);
    final rightEdu = _educationScore(right);
    final leftBiz = left.businessScore();
    final rightBiz = right.businessScore();

    // (label, leftVal, rightVal, leftFraction, rightFraction, winner, footnote)
    final metricRows = <_MetricRow>[
      _MetricRow.numeric(
        label: 'Mean income',
        leftValue: left.incomeMean,
        rightValue: right.incomeMean,
        format: (v) => 'RM${v.round()}/mo',
        higherIsBetter: true,
        leftEstimated: left.estimatedFields.contains('income'),
        rightEstimated: right.estimatedFields.contains('income'),
      ),
      _MetricRow.numeric(
        label: 'Median income',
        leftValue: left.incomeMedian,
        rightValue: right.incomeMedian,
        format: (v) => 'RM${v.round()}/mo',
        higherIsBetter: true,
        leftEstimated: left.estimatedFields.contains('income'),
        rightEstimated: right.estimatedFields.contains('income'),
      ),
      _MetricRow.numeric(
        label: 'Poverty rate',
        leftValue: left.povertyRate,
        rightValue: right.povertyRate,
        format: (v) => '${v.toStringAsFixed(1)}%',
        higherIsBetter: false,
        leftEstimated: left.estimatedFields.contains('income'),
        rightEstimated: right.estimatedFields.contains('income'),
      ),
      _MetricRow.numeric(
        label: 'Population',
        leftValue: left.population,
        rightValue: right.population,
        format: (v) => v.round().toString(),
        higherIsBetter: null,
      ),
      _MetricRow.numeric(
        label: 'Population density',
        leftValue: left.populationDensity,
        rightValue: right.populationDensity,
        format: (v) => '${v.round()}/km²',
        higherIsBetter: false,
      ),
      _MetricRow.numeric(
        label: 'Electricity access',
        leftValue: left.electricityAccess,
        rightValue: right.electricityAccess,
        format: (v) => '${v.toStringAsFixed(1)}%',
        higherIsBetter: true,
        leftEstimated: left.estimatedFields.contains('electricity'),
        rightEstimated: right.estimatedFields.contains('electricity'),
      ),
      _MetricRow.numeric(
        label: 'Water access',
        leftValue: left.waterAccess,
        rightValue: right.waterAccess,
        format: (v) => '${v.toStringAsFixed(1)}%',
        higherIsBetter: true,
        leftEstimated: left.estimatedFields.contains('water'),
        rightEstimated: right.estimatedFields.contains('water'),
      ),
      _MetricRow.numeric(
        label: 'Primary schools',
        leftValue: left.primarySchools,
        rightValue: right.primarySchools,
        format: (v) => v.round().toString(),
        higherIsBetter: true,
      ),
      _MetricRow.numeric(
        label: 'Secondary schools',
        leftValue: left.secondarySchools,
        rightValue: right.secondarySchools,
        format: (v) => v.round().toString(),
        higherIsBetter: true,
      ),
      _MetricRow.numeric(
        label: 'Tertiary schools',
        leftValue: left.tertiarySchools,
        rightValue: right.tertiarySchools,
        format: (v) => v.round().toString(),
        higherIsBetter: true,
      ),
      _MetricRow.numeric(
        label: 'Total schools',
        leftValue: left.totalSchools,
        rightValue: right.totalSchools,
        format: (v) => v.round().toString(),
        higherIsBetter: true,
      ),
      _MetricRow.numeric(
        label: 'State crime rate, per 1,000',
        leftValue: left.stateCrimesPerCapita,
        rightValue: right.stateCrimesPerCapita,
        format: (v) => v.toStringAsFixed(1),
        higherIsBetter: false,
        leftEstimated: left.estimatedFields.contains('crime'),
        rightEstimated: right.estimatedFields.contains('crime'),
        footnote: 'Approximate: state total crimes ÷ population of districts this app tracks, not the true state population. "(avg)" means no figure exists for that state yet, so the national average is shown instead.',
      ),
    ];

    int leftWins = 0, rightWins = 0;
    for (final r in metricRows) {
      if (r.winner == -1) leftWins++;
      if (r.winner == 1) rightWins++;
    }
    final decided = leftWins + rightWins;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeadlineCompareCard(left: left, right: right, leftScore: leftLivability, rightScore: rightLivability),
        const SizedBox(height: 20),

        const SectionTitle('Best for'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _ScoreCompareLine(icon: Icons.home_work_outlined, label: 'Overall livability', leftScore: leftLivability, rightScore: rightLivability),
                const Divider(height: 24),
                _ScoreCompareLine(icon: Icons.school_outlined, label: 'Studying here', leftScore: leftEdu, rightScore: rightEdu),
                const Divider(height: 24),
                _ScoreCompareLine(icon: Icons.storefront_outlined, label: 'Opening a business', leftScore: leftBiz, rightScore: rightBiz),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        const SectionTitle('Income & poverty'),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
            child: Column(children: metricRows.sublist(0, 3).map((r) => r.toBar()).toList()),
          ),
        ),
        const SizedBox(height: 16),

        const SectionTitle('Population & access'),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
            child: Column(children: metricRows.sublist(3, 7).map((r) => r.toBar()).toList()),
          ),
        ),
        const SizedBox(height: 16),

        const SectionTitle('Education'),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
            child: Column(children: metricRows.sublist(7, 11).map((r) => r.toBar()).toList()),
          ),
        ),
        const SizedBox(height: 16),

        const SectionTitle('Safety'),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
            child: Column(children: metricRows.sublist(11, 12).map((r) => r.toBar()).toList()),
          ),
        ),
        const SizedBox(height: 20),

        if (decided > 0) ...[
          const SectionTitle('Overall verdict'),
          _VerdictCard(left: left, right: right, leftWins: leftWins, rightWins: rightWins, decided: decided),
        ],
      ],
    );
  }
}

/// Headline card: big score rings for livability, a crown on whichever
/// district leads, and the point gap between them.
class _HeadlineCompareCard extends StatelessWidget {
  final DistrictData left;
  final DistrictData right;
  final double leftScore;
  final double rightScore;

  const _HeadlineCompareCard({required this.left, required this.right, required this.leftScore, required this.rightScore});

  @override
  Widget build(BuildContext context) {
    final leftLeads = leftScore > rightScore;
    final rightLeads = rightScore > leftScore;
    final rawGap = (leftScore - rightScore).abs();
    final gap = rawGap.round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: _RingColumn(name: left.district, state: left.state, score: leftScore, leading: leftLeads)),
                Column(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.brand, shape: BoxShape.circle),
                      child: const Text('VS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ),
                Expanded(child: _RingColumn(name: right.district, state: right.state, score: rightScore, leading: rightLeads)),
              ],
            ),
            const SizedBox(height: 14),
            if (rawGap < 0.5)
              Text('Dead even on overall livability', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5))
            else
              Text(
                gap > 0
                    ? '${leftLeads ? left.district : right.district} leads livability by $gap pts'
                    : '${leftLeads ? left.district : right.district} is narrowly ahead on livability',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5, fontWeight: FontWeight.w500),
              ),
          ],
        ),
      ),
    );
  }
}

class _RingColumn extends StatelessWidget {
  final String name;
  final String state;
  final double score;
  final bool leading;

  const _RingColumn({required this.name, required this.state, required this.score, required this.leading});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            ScoreRing(score: score, size: 76),
            if (leading)
              const Positioned(
                top: -14,
                child: Icon(Icons.emoji_events, color: Color(0xFFF2A93B), size: 22),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
        Text(state, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5)),
      ],
    );
  }
}

/// One row of the "Best for" card: an icon+label, then each district's
/// score with the winner bolded/coloured - mirrors how DuoStatBar marks
/// winners, but compact enough for three scores in one card.
class _ScoreCompareLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final double leftScore;
  final double rightScore;

  const _ScoreCompareLine({required this.icon, required this.label, required this.leftScore, required this.rightScore});

  @override
  Widget build(BuildContext context) {
    final leftWins = leftScore > rightScore;
    final rightWins = rightScore > leftScore;
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.brand),
        const SizedBox(width: 10),
        Expanded(flex: 3, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        Expanded(
          flex: 2,
          child: _scoreChip(leftScore, leftWins),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: _scoreChip(rightScore, rightWins),
        ),
      ],
    );
  }

  Widget _scoreChip(double score, bool wins) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (wins) Icon(Icons.check_circle, size: 14, color: AppColors.good) else Container(width: 14),
        const SizedBox(width: 4),
        Text(
          score.round().toString(),
          style: TextStyle(fontWeight: wins ? FontWeight.bold : FontWeight.w500, color: wins ? AppColors.good : null),
        ),
      ],
    );
  }
}

/// Final tally: how many of the comparable metrics each district won,
/// shown as a split bar so the overall lean is visible at a glance.
class _VerdictCard extends StatelessWidget {
  final DistrictData left;
  final DistrictData right;
  final int leftWins;
  final int rightWins;
  final int decided;

  const _VerdictCard({required this.left, required this.right, required this.leftWins, required this.rightWins, required this.decided});

  @override
  Widget build(BuildContext context) {
    final leftFlex = leftWins == 0 ? 1 : leftWins;
    final rightFlex = rightWins == 0 ? 1 : rightWins;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${left.district} wins $leftWins of $decided', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text('${right.district} wins $rightWins of $decided', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    if (leftWins > 0) Expanded(flex: leftFlex, child: Container(color: AppColors.compareA)),
                    if (rightWins > 0) Expanded(flex: rightFlex, child: Container(color: AppColors.compareB)),
                    if (leftWins == 0 && rightWins == 0) Expanded(child: Container(color: Colors.grey.shade300)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Based on $decided directly comparable metrics with real data on both sides. Ties and missing data are excluded.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bundles one metric's raw values into the winner/formatting logic
/// shared by every row, then hands back a ready-to-render [DuoStatBar].
class _MetricRow {
  final String label;
  final String leftText;
  final String rightText;
  final double leftFraction;
  final double rightFraction;
  final int winner; // -1 left, 1 right, 0 tie/no data/not applicable
  final String? footnote;

  _MetricRow({
    required this.label,
    required this.leftText,
    required this.rightText,
    required this.leftFraction,
    required this.rightFraction,
    required this.winner,
    this.footnote,
  });

  /// [higherIsBetter] is null for purely informational metrics (e.g. raw
  /// population) that don't have a "better" side.
  factory _MetricRow.numeric({
    required String label,
    required double? leftValue,
    required double? rightValue,
    required String Function(double) format,
    required bool? higherIsBetter,
    String? footnote,
    bool leftEstimated = false,
    bool rightEstimated = false,
  }) {
    // A value filled in from a state-average fallback (see DataService) is
    // still shown as a real number rather than "No data" - just marked
    // with a small "(avg)" tag so it's clear it isn't this district's own
    // figure, matching the disclosure used elsewhere in the app.
    final leftText = leftValue != null ? '${format(leftValue)}${leftEstimated ? ' (avg)' : ''}' : 'No data';
    final rightText = rightValue != null ? '${format(rightValue)}${rightEstimated ? ' (avg)' : ''}' : 'No data';
    final maxV = [leftValue ?? 0, rightValue ?? 0].reduce((a, b) => a > b ? a : b);
    final leftFraction = maxV == 0 ? 0.0 : (leftValue ?? 0) / maxV;
    final rightFraction = maxV == 0 ? 0.0 : (rightValue ?? 0) / maxV;

    int winner = 0;
    if (higherIsBetter != null && leftValue != null && rightValue != null && leftValue != rightValue) {
      final leftHigher = leftValue > rightValue;
      winner = (leftHigher == higherIsBetter) ? -1 : 1;
    }

    return _MetricRow(
      label: label,
      leftText: leftText,
      rightText: rightText,
      leftFraction: leftFraction,
      rightFraction: rightFraction,
      winner: winner,
      footnote: footnote,
    );
  }

  Widget toBar() => DuoStatBar(
    label: label,
    leftValueText: leftText,
    rightValueText: rightText,
    leftFraction: leftFraction,
    rightFraction: rightFraction,
    winner: winner,
    footnote: footnote,
  );
}


