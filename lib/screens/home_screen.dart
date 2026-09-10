import 'package:flutter/material.dart';
import '../models.dart';
import '../services/data_service.dart';
import '../services/local_store_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'where_should_i_live_screen.dart';
import 'infrastructure_screen.dart';
import 'where_to_study_screen.dart';
import 'where_to_open_business_screen.dart';
import 'compare_districts_screen.dart';
import 'browse_districts_screen.dart';
import 'district_detail_screen.dart';
import 'map_explorer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _cardDefs = {
    'Where should I live?': (
    icon: Icons.home_outlined,
    color: Color(0xFF3B82F6),
    subtitle: 'Income, density and safety match',
    ),
    'How is the infrastructure?': (
    icon: Icons.bolt,
    color: Color(0xFFF2A93B),
    subtitle: 'Electricity, water and crime data',
    ),
    'Where to study?': (
    icon: Icons.school_outlined,
    color: Color(0xFFF2874B),
    subtitle: 'Real school counts by district',
    ),
    'Where to open a business?': (
    icon: Icons.storefront_outlined,
    color: Color(0xFFE05252),
    subtitle: 'Population and spending power',
    ),
    'Browse districts': (
    icon: Icons.travel_explore_outlined,
    color: Color(0xFF14B8A6),
    subtitle: 'Explore every state and district',
    ),
    'Compare Districts': (
    icon: Icons.compare_arrows,
    color: Color(0xFF8B5CF6),
    subtitle: 'Put two districts side by side',
    ),
    'District map': (
    icon: Icons.map_outlined,
    color: Color(0xFF0EA5A5),
    subtitle: 'See every district on one map',
    ),
  };

  // Identity-based ordering: whichever flow matters most to that identity
  // is surfaced first, instead of always showing the same fixed order.
  static const _orderByIdentity = {
    'Student': ['Where to study?', 'Where should I live?', 'How is the infrastructure?', 'Where to open a business?', 'Browse districts', 'Compare Districts', 'District map'],
    'Professional': ['Where should I live?', 'How is the infrastructure?', 'Where to open a business?', 'Where to study?', 'Browse districts', 'Compare Districts', 'District map'],
    'Business Owner': ['Where to open a business?', 'How is the infrastructure?', 'Where should I live?', 'Where to study?', 'Browse districts', 'Compare Districts', 'District map'],
    'Other': ['Where should I live?', 'Where to study?', 'How is the infrastructure?', 'Where to open a business?', 'Browse districts', 'Compare Districts', 'District map'],
  };

  String? _identity;
  List<DistrictData> _topDistricts = [];
  bool _loadingTop = true;
  bool _showTopRated = true;

  @override
  void initState() {
    super.initState();
    _loadIdentity();
    _loadHomeConfig();
    // Refresh the greeting/card order immediately when identity changes
    // from Profile - no tab switch or reload needed, since this screen
    // stays alive (and un-rebuilt) in the bottom-nav's IndexedStack.
    LocalStoreService.identityRevision.addListener(_loadIdentity);
    // Same idea for the "show top-rated leaderboard" preference, changed
    // from Settings.
    LocalStoreService.homeConfigRevision.addListener(_loadHomeConfig);
    DataService.instance.getDistricts().then((districts) {
      final sorted = [...districts]..sort((a, b) => b.livabilityScore().compareTo(a.livabilityScore()));
      if (mounted) {
        setState(() {
          _topDistricts = sorted.take(5).toList();
          _loadingTop = false;
        });
      }
    });
  }

  @override
  void dispose() {
    LocalStoreService.identityRevision.removeListener(_loadIdentity);
    LocalStoreService.homeConfigRevision.removeListener(_loadHomeConfig);
    super.dispose();
  }

  void _loadIdentity() {
    LocalStoreService.instance.getIdentity().then((v) {
      if (mounted) setState(() => _identity = v);
    });
  }

  void _loadHomeConfig() {
    LocalStoreService.instance.getShowTopRated().then((v) {
      if (mounted) setState(() => _showTopRated = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final order = _orderByIdentity[_identity] ?? _cardDefs.keys.toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('UrbanEx', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.brand)),
        const SizedBox(height: 16),
        Text(
          _identity != null ? 'Welcome back, $_identity!' : 'What are you up to today?',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          _identity != null
              ? "Here's what's most relevant to you, based on your profile."
              : 'Select what you would like to explore.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 20),
        ...order.map((title) {
          final def = _cardDefs[title]!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _HomeCard(
              icon: def.icon,
              color: def.color,
              title: title,
              subtitle: def.subtitle,
              onTap: () => _navigate(context, title),
            ),
          );
        }),
        const SizedBox(height: 8),
        if (_showTopRated) ...[
          const Text('Top-rated districts right now', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 4),
          Text('Ranked live from income, density, schools and safety data.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const SizedBox(height: 12),
          _loadingTop
              ? const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator()))
              : SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _topDistricts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final d = _topDistricts[i];
                return _TopDistrictCard(
                  district: d,
                  rank: i + 1,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DistrictDetailScreen(district: d))),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  void _navigate(BuildContext context, String title) {
    Widget screen;
    switch (title) {
      case 'Where should I live?':
        screen = const WhereShouldILiveScreen();
        break;
      case 'How is the infrastructure?':
        screen = const InfrastructureListScreen();
        break;
      case 'Where to study?':
        screen = const WhereToStudyScreen();
        break;
      case 'Browse districts':
        screen = const BrowseDistrictsScreen();
        break;
      case 'Compare Districts':
        screen = const CompareDistrictsScreen();
        break;
      case 'District map':
        screen = const MapExplorerScreen();
        break;
      default:
        screen = const WhereToOpenBusinessScreen();
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HomeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HoverLiftCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey.shade400),
        ],
      ),
    );
  }
}

class _TopDistrictCard extends StatelessWidget {
  final DistrictData district;
  final int rank;
  final VoidCallback onTap;

  const _TopDistrictCard({required this.district, required this.rank, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final score = district.livabilityScore();
    return SizedBox(
      width: 160,
      child: HoverLiftCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: AppColors.brand,
                  child: Text('$rank', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                ScoreBadge(score: score),
              ],
            ),
            const Spacer(),
            Text(district.district, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(district.state, style: TextStyle(color: Colors.grey.shade600, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}


