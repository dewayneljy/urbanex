import 'package:flutter/material.dart';
import '../models.dart';
import '../services/nav_service.dart';
import '../theme/app_theme.dart';

/// A row of 5 stars. Read-only when [onChanged] is null (for showing an
/// existing rating); tappable when it's provided (for picking one).
/// [rating] can be 0-5; a value of 0 shows all-empty stars.
class StarRating extends StatelessWidget {
  final int rating;
  final double size;
  final ValueChanged<int>? onChanged;

  const StarRating({super.key, required this.rating, this.size = 20, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating;
        final star = Icon(
          filled ? Icons.star : Icons.star_border,
          size: size,
          color: filled ? Colors.amber.shade600 : Colors.grey.shade400,
        );
        if (onChanged == null) return star;
        return InkWell(
          borderRadius: BorderRadius.circular(size),
          onTap: () => onChanged!(i + 1),
          child: Padding(padding: const EdgeInsets.all(2), child: star),
        );
      }),
    );
  }
}

/// Big numeric score (0-100) with a coloured "Good/Moderate/Bad" pill and
/// a 4-segment strip, matching the district/state detail screens.
class ScoreHeader extends StatelessWidget {
  final double score;
  final String subtitle;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  /// Overrides the trailing favorite star with a custom action (e.g. a
  /// "Report an issue" icon) when provided - [isFavorite] and
  /// [onToggleFavorite] are ignored in that case. Screens that don't
  /// pass this keep the default favorite-star behaviour unchanged.
  final Widget? trailing;

  const ScoreHeader({
    super.key,
    required this.score,
    required this.subtitle,
    this.isFavorite = false,
    this.onToggleFavorite,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.scoreColor(score);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                score.round().toString(),
                style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold, height: 1),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppColors.scoreLabel(score),
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ScoreStrip(score: score),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
        if (trailing != null)
          trailing!
        else if (onToggleFavorite != null)
          IconButton(
            icon: Icon(isFavorite ? Icons.star : Icons.star_border),
            color: isFavorite ? AppColors.moderate : null,
            onPressed: onToggleFavorite,
          ),
      ],
    );
  }
}

/// The 4-block red/orange/yellow/green strip used next to scores.
class ScoreStrip extends StatelessWidget {
  final double score;
  const ScoreStrip({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final colors = [AppColors.bad, const Color(0xFFF2874B), AppColors.moderate, AppColors.good];
    final activeIndex = (score / 25).floor().clamp(0, 3);
    return Row(
      children: List.generate(4, (i) {
        return Container(
          margin: const EdgeInsets.only(right: 4),
          width: 20,
          height: 8,
          decoration: BoxDecoration(
            color: i == activeIndex ? colors[i] : colors[i].withOpacity(0.25),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

/// A "Score breakdown" style row: label, formatted value, and a
/// proportional progress bar.
class StatBarRow extends StatelessWidget {
  final String label;
  final String valueText;
  final double fraction; // 0..1
  final String? footnote; // optional small italic note shown under the bar (e.g. a data-approximation caveat)

  const StatBarRow({
    super.key,
    required this.label,
    required this.valueText,
    required this.fraction,
    this.footnote,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
              Text(valueText, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0, 1),
              minHeight: 6,
              backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(isDark ? AppColors.good : Colors.black87),
            ),
          ),
          if (footnote != null) ...[
            const SizedBox(height: 4),
            Text(footnote!, style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade500)),
          ],
        ],
      ),
    );
  }
}

/// A "vs" version of [StatBarRow] - one label with two stacked bars, used
/// on the Compare Districts screen so every metric reads the same way a
/// single-district stat bar does elsewhere in the app, just doubled up.
/// [leftFraction]/[rightFraction] should already be normalised against a
/// shared max so the two bars are visually comparable. [winner] is -1 if
/// the left side is ahead, 1 if the right side is ahead, 0 for a tie or
/// when there isn't enough data to call it.
class DuoStatBar extends StatelessWidget {
  final String label;
  final String leftValueText;
  final String rightValueText;
  final double leftFraction;
  final double rightFraction;
  final int winner;
  final String? footnote;

  const DuoStatBar({
    super.key,
    required this.label,
    required this.leftValueText,
    required this.rightValueText,
    required this.leftFraction,
    required this.rightFraction,
    this.winner = 0,
    this.footnote,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 12.5)),
          const SizedBox(height: 8),
          _bar(
            color: AppColors.compareA,
            valueText: leftValueText,
            fraction: leftFraction,
            trackColor: trackColor,
            highlighted: winner == -1,
          ),
          const SizedBox(height: 6),
          _bar(
            color: AppColors.compareB,
            valueText: rightValueText,
            fraction: rightFraction,
            trackColor: trackColor,
            highlighted: winner == 1,
          ),
          if (footnote != null) ...[
            const SizedBox(height: 4),
            Text(footnote!, style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade500)),
          ],
        ],
      ),
    );
  }

  Widget _bar({required Color color, required String valueText, required double fraction, required Color trackColor, required bool highlighted}) {
    return Row(
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0, 1),
              minHeight: 7,
              backgroundColor: trackColor,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 78,
          child: Text(
            valueText,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: highlighted ? FontWeight.bold : FontWeight.w500,
              color: highlighted ? AppColors.good : null,
            ),
          ),
        ),
        SizedBox(
          width: 16,
          child: highlighted ? Icon(Icons.check_circle, size: 14, color: AppColors.good) : null,
        ),
      ],
    );
  }
}

/// Opens a searchable bottom sheet listing every tracked district and
/// resolves with the one the user taps, or null if they dismiss it
/// without picking. Used anywhere a district needs to be chosen from a
/// generic list (e.g. Compare Districts, and the admin news editor).
Future<DistrictData?> showDistrictPickerSheet(
    BuildContext context, {
      required List<DistrictData> options,
      DistrictData? currentValue,
      String title = 'Choose a district',
      Color accentColor = AppColors.brand,
    }) {
  return showModalBottomSheet<DistrictData>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DistrictPickerSheet(
      title: title,
      accentColor: accentColor,
      options: options,
      currentValue: currentValue,
    ),
  );
}

class _DistrictPickerSheet extends StatefulWidget {
  final String title;
  final Color accentColor;
  final List<DistrictData> options;
  final DistrictData? currentValue;

  const _DistrictPickerSheet({
    required this.title,
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
                    Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
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

/// A tappable pill used for priority selection (multi-select) or
/// category selection (single-select). Lifts with a shadow and lightens
/// on hover (desktop/web), on top of its selected/unselected styling.
class SelectableChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<SelectableChip> createState() => _SelectableChipState();
}

class _SelectableChipState extends State<SelectableChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        onTap: widget.onTap,
        hoverColor: Colors.transparent, // handled manually via AnimatedContainer below
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? (_hovering ? AppColors.brandDark : AppColors.brand)
                : (_hovering ? AppColors.brand.withOpacity(0.08) : Colors.transparent),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? AppColors.brand
                  : (_hovering ? AppColors.brand : Colors.grey.shade400),
            ),
            boxShadow: (selected || _hovering)
                ? [
              BoxShadow(
                color: AppColors.brand.withOpacity(_hovering ? 0.35 : 0.2),
                blurRadius: _hovering ? 12 : 6,
                offset: const Offset(0, 3),
              ),
            ]
                : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: selected ? Colors.white : null,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

/// A tappable "card button" that lifts with a stronger shadow and shows
/// a brand-coloured glow/border when hovered (desktop/web) or pressed -
/// used anywhere a whole card acts like a button (home action cards,
/// onboarding identity picker, etc). Pass [selected] for a permanently
/// highlighted state (e.g. the chosen identity on the onboarding screen).
class HoverLiftCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool selected;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  const HoverLiftCard({
    super.key,
    required this.child,
    required this.onTap,
    this.selected = false,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  State<HoverLiftCard> createState() => _HoverLiftCardState();
}

class _HoverLiftCardState extends State<HoverLiftCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    final highlighted = widget.selected || _hovering;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: widget.selected ? AppColors.brand : cardColor,
          borderRadius: widget.borderRadius,
          border: Border.all(
            color: widget.selected
                ? AppColors.brand
                : (_hovering ? AppColors.brand.withOpacity(0.6) : Colors.grey.shade300),
            width: _hovering && !widget.selected ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: highlighted ? AppColors.brand.withOpacity(0.28) : Colors.black.withOpacity(0.06),
              blurRadius: highlighted ? 18 : 8,
              offset: Offset(0, highlighted ? 8 : 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: widget.borderRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: widget.borderRadius,
            hoverColor: Colors.transparent, // hover already expressed via the container above
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// A small circular "gauge" showing a 0-100 score as a colored ring with
/// the number in the middle - a livelier, more visual alternative to a
/// plain text badge for list rows.
class ScoreRing extends StatelessWidget {
  final double score;
  final double size;
  const ScoreRing({super.key, required this.score, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.scoreColor(score);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 4.5,
              valueColor: AlwaysStoppedAnimation(color.withOpacity(0.15)),
            ),
          ),
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: (score / 100).clamp(0, 1),
              strokeWidth: 4.5,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text(
            score.round().toString(),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: size * 0.34),
          ),
        ],
      ),
    );
  }
}

/// Small icon+label pill used to show a quick real-data stat inline in a
/// list card (e.g. income, density, school count, crime rate).
class MiniStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const MiniStatChip({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

/// A small circular rank badge (#1, #2, ...) - the top 3 get the brand
/// color to draw the eye, the rest a neutral grey.
class RankBadge extends StatelessWidget {
  final int rank;
  const RankBadge({super.key, required this.rank});

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isTop3 ? AppColors.brand : Colors.grey.shade300,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$rank',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isTop3 ? Colors.white : Colors.grey.shade800),
      ),
    );
  }
}

/// The rich list row used for districts and states throughout the app -
/// a colored score-tier accent bar, an optional rank badge, a title and
/// subtitle, a row of quick-stat chips built from real data, and a
/// [ScoreRing] instead of a plain number, all wrapped in a [HoverLiftCard]
/// so it lifts and lights up the same way every other tappable card does.
class RichListCard extends StatelessWidget {
  final int? rank;
  final String title;
  final String subtitle;
  final double score;
  final List<Widget> chips;
  final VoidCallback onTap;
  final bool flagged;

  const RichListCard({
    super.key,
    this.rank,
    required this.title,
    required this.subtitle,
    required this.score,
    this.chips = const [],
    required this.onTap,
    this.flagged = false,
  });

  @override
  Widget build(BuildContext context) {
    final tierColor = AppColors.scoreColor(score);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: HoverLiftCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: tierColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (rank != null) ...[
                        Padding(padding: const EdgeInsets.only(top: 2), child: RankBadge(rank: rank!)),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (flagged) ...[
                                  const SizedBox(width: 6),
                                  Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.bad),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                            if (chips.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(spacing: 6, runSpacing: 6, children: chips),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Padding(padding: const EdgeInsets.only(top: 2), child: ScoreRing(score: score)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small badge used in list rows, e.g. "89 Good". Wrapped in a bounded
/// FittedBox so it can never trigger a bottom (RenderFlex) overflow
/// inside a ListTile's trailing slot, regardless of the tile's computed
/// height on a given device/font scale - it simply scales down slightly
/// instead of overflowing.
class ScoreBadge extends StatelessWidget {
  final double score;
  const ScoreBadge({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.scoreColor(score);
    return SizedBox(
      height: 40,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(score.round().toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(AppColors.scoreLabel(score), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Line chart for the "Trend" panel, drawn with CustomPainter so the
/// project has no charting-library dependency. Unlike a bare unlabeled
/// sparkline, this shows the actual year range, a colour-coded % change
/// from first to last point, the endpoint values, and visually
/// distinguishes real data points (solid dots) from points borrowed from
/// a broader state-level estimate (hollow rings) - see
/// [TrendPoint.isEstimated] - so a chart that blends real and estimated
/// years is never misread as more precise than it is.
class TrendSparkline extends StatelessWidget {
  final List<TrendPoint> points;
  final String Function(double) formatValue;

  const TrendSparkline({super.key, required this.points, this.formatValue = _defaultFormat});

  static String _defaultFormat(double v) => v.round().toString();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final boxDecoration = BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
    );

    if (points.length < 2) {
      return Container(
        height: 110,
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: boxDecoration,
        child: Center(
          child: Text('Not enough data points yet', style: TextStyle(color: Colors.grey.shade500)),
        ),
      );
    }

    final first = points.first.value;
    final last = points.last.value;
    final changePct = first == 0 ? 0.0 : (last - first) / first * 100;
    final isUp = changePct > 0.5;
    final isDown = changePct < -0.5;
    final changeColor = isUp ? AppColors.good : (isDown ? const Color(0xFFE05252) : Colors.grey.shade500);
    final changeIcon = isUp ? Icons.trending_up : (isDown ? Icons.trending_down : Icons.trending_flat);
    final hasEstimate = points.any((p) => p.isEstimated);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: boxDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${points.first.year} – ${points.last.year}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              Row(
                children: [
                  Icon(changeIcon, size: 16, color: changeColor),
                  const SizedBox(width: 4),
                  Text('${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: changeColor)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 66,
            width: double.infinity,
            child: CustomPaint(painter: _TrendPainter(points), child: Container()),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatValue(first), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              Text(formatValue(last),
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
          if (hasEstimate) ...[
            const SizedBox(height: 4),
            Text(
              '○ hollow points are a state-average estimate for that year, not this district\'s own figure.',
              style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<TrendPoint> points;
  _TrendPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final values = points.map((p) => p.value).toList();
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 1e-6 ? 1 : (maxV - minV);
    final dx = points.length > 1 ? size.width / (points.length - 1) : 0.0;

    Offset offsetFor(int i) {
      final x = dx * i;
      final y = size.height - ((values[i] - minV) / range) * size.height;
      return Offset(x, y);
    }

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final o = offsetFor(i);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }

    final linePaint = Paint()
      ..color = AppColors.brand
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fillPaint = Paint()..color = AppColors.brand.withOpacity(0.12);
    canvas.drawPath(fillPath, fillPaint);

    // Dot markers: solid for a district/state's own real data point,
    // hollow ring for a point borrowed from a broader estimate - so the
    // two never look like the same kind of figure at a glance.
    for (int i = 0; i < points.length; i++) {
      final o = offsetFor(i);
      if (points[i].isEstimated) {
        final ringPaint = Paint()
          ..color = AppColors.brand
          ..strokeWidth = 1.6
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(o, 3.5, ringPaint);
      } else {
        final dotPaint = Paint()..color = AppColors.brand;
        canvas.drawCircle(o, 3, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) => oldDelegate.points != points;
}

/// Persistent bottom navigation used by the Home shell.
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.star_border), activeIcon: Icon(Icons.star), label: 'Favorites'),
        BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: 'Settings'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}

/// Drop this into any PUSHED screen's `bottomNavigationBar` (detail pages,
/// filter forms, results lists, etc.) to keep the same persistent tab bar
/// visible everywhere, not just on the four top-level tab screens.
/// Tapping a tab pops back to the root (the home shell) and switches to
/// that tab, backed by the app-wide [NavService.currentTab].
class GlobalBottomNav extends StatelessWidget {
  const GlobalBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NavService.currentTab,
      builder: (context, index, _) {
        return AppBottomNav(
          currentIndex: index,
          onTap: (i) {
            NavService.currentTab.value = i;
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        );
      },
    );
  }
}

/// Simple search box used across list screens.
class AppSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const AppSearchField({super.key, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey)),
    );
  }
}

class LoadingList extends StatelessWidget {
  const LoadingList({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Padding(
    padding: EdgeInsets.all(40),
    child: CircularProgressIndicator(),
  ));
}





