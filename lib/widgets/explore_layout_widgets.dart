import 'package:flutter/material.dart';
import '../services/location_info_service.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';

/// Big descriptive card at the top of a matching screen - icon, title,
/// short blurb - playing the role of the illustration banner in the
/// reference design, but built from the app's existing brand color +
/// icon language (same colors used for each flow's card on Home).
class ExploreHeroBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const ExploreHeroBanner({super.key, required this.icon, required this.color, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.16), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: color.withOpacity(0.18), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Search field + filter button, matching the reference layout. Reuses
/// AppSearchField's look; the filter button just opens whatever bottom
/// sheet the caller provides (each screen's existing filter controls).
class ExploreSearchBar extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback onFilterTap;
  const ExploreSearchBar({
    super.key,
    required this.hint,
    required this.onChanged,
    this.onSubmitted,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: onChanged,
            onSubmitted: onSubmitted,
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
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: AppColors.brand.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onFilterTap,
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Icon(Icons.tune, color: AppColors.brand),
            ),
          ),
        ),
      ],
    );
  }
}

class ExploreAction {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const ExploreAction({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});
}

/// 2x2 quick-action grid, matching the reference layout's four cards.
class ExploreQuickActionsGrid extends StatelessWidget {
  final List<ExploreAction> actions;
  const ExploreQuickActionsGrid({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < actions.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(child: _ActionCard(action: actions[i])),
                const SizedBox(width: 12),
                if (i + 1 < actions.length) Expanded(child: _ActionCard(action: actions[i + 1])) else const Spacer(),
              ],
            ),
          ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final ExploreAction action;
  const _ActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return HoverLiftCard(
      onTap: action.onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: action.color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(action.icon, color: action.color, size: 18),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(height: 10),
          Text(action.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          const SizedBox(height: 2),
          Text(action.subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// "Section title ... See all" row from the reference design.
class ExploreSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const ExploreSectionHeader({super.key, required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [Text('See all'), SizedBox(width: 2), Icon(Icons.chevron_right, size: 16)],
            ),
          ),
      ],
    );
  }
}

/// Ranked card with a real thumbnail photo, title, location line, tag
/// chips, and a score badge - the "Popular schools near you" card from
/// the reference, built from real district/state data instead of
/// invented ratings/reviews.
class ExploreThumbnailListCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final double score;
  final List<Widget> tags;
  final VoidCallback onTap;
  const ExploreThumbnailListCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.score,
    this.tags = const [],
    required this.onTap,
  });

  @override
  State<ExploreThumbnailListCard> createState() => _ExploreThumbnailListCardState();
}

class _ExploreThumbnailListCardState extends State<ExploreThumbnailListCard> {
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    LocationInfoService.instance.getImageUrl(district: widget.title, state: widget.subtitle).then((url) {
      if (mounted) setState(() => _imageUrl = url);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: HoverLiftCard(
        onTap: widget.onTap,
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 72,
                child: _imageUrl == null
                    ? Container(
                  color: AppColors.brand.withOpacity(0.12),
                  child: Icon(Icons.location_city, color: AppColors.brand.withOpacity(0.6)),
                )
                    : Image.network(
                  _imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.brand.withOpacity(0.12),
                    child: Icon(Icons.location_city, color: AppColors.brand.withOpacity(0.6)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.place_outlined, size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Expanded(child: Text(widget.subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  if (widget.tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: widget.tags),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            Column(
              children: [
                ScoreBadge(score: widget.score),
                const SizedBox(height: 18),
                Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet shell used by every matching screen's filter button, so
/// they all share the same rounded-sheet-with-drag-handle look already
/// used elsewhere in the app (compare picker, news editor).
Future<void> showExploreFilterSheet(BuildContext context, {required String title, required WidgetBuilder builder}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
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
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: builder(context),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}


