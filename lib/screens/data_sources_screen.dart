import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class _DatasetInfo {
  final String name;
  final String datasetId;
  final String description;
  const _DatasetInfo({required this.name, required this.datasetId, required this.description});
}

const _datasets = [
  _DatasetInfo(
    name: 'Household Income & Poverty',
    datasetId: 'hies_district',
    description: 'Mean and median household income, and the poverty rate, per district. Powers "Where should I live?" and the district score breakdown.',
  ),
  _DatasetInfo(
    name: 'Population',
    datasetId: 'population_district',
    description: 'Total population per district, combined with a static land-area reference to compute population density.',
  ),
  _DatasetInfo(
    name: 'Household Amenities',
    datasetId: 'hh_access_amenities',
    description: '% of households with electricity and piped water access. Powers "How is the infrastructure?".',
  ),
  _DatasetInfo(
    name: 'Schools',
    datasetId: 'schools_district',
    description: 'Real counts of primary, secondary, and tertiary PUBLIC schools per district (Ministry of Education). Powers "Where to study?".',
  ),
  _DatasetInfo(
    name: 'Forest Reserves',
    datasetId: 'forest_reserve_state',
    description: 'Permanent forest reserve area per state, shown on the state infrastructure detail screen.',
  ),
  _DatasetInfo(
    name: 'Crime',
    datasetId: 'crime_district',
    description: 'Recorded crimes per police district, aggregated to state level (police districts don\'t map 1:1 to administrative ones). Powers the Safety indicator.',
  ),
];

/// Purely informational: lists every live Malaysian government dataset
/// UrbanEx actually pulls from, so the "real data" claim throughout the
/// app is transparent and checkable.
class DataSourcesScreen extends StatelessWidget {
  const DataSourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Sources')),
      bottomNavigationBar: const GlobalBottomNav(),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'All of the following are fetched live from Malaysia\'s Open Data initiative (data.gov.my) each session.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ..._datasets.map((d) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.dataset_outlined, size: 18, color: AppColors.brand),
                          const SizedBox(width: 8),
                          Expanded(child: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(d.datasetId, style: TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: Colors.grey.shade500)),
                      const SizedBox(height: 8),
                      Text(d.description, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.35)),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 8),
          Text(
            'Land area (used only to compute population density) and the list of tracked districts are static reference data - no live Malaysian API publishes those.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}



