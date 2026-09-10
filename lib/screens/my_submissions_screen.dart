import 'package:flutter/material.dart';
import '../models.dart';
import '../services/application_service.dart';
import '../services/local_store_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Shows the signed-in user's own school-application / business-registration
/// submissions and their review status. Read-only - editing or
/// withdrawing a submission isn't supported yet.
class MySubmissionsScreen extends StatefulWidget {
  const MySubmissionsScreen({super.key});

  @override
  State<MySubmissionsScreen> createState() => _MySubmissionsScreenState();
}

class _MySubmissionsScreenState extends State<MySubmissionsScreen> {
  List<ListingApplication> _submissions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    LocalStoreService.applicationsRevision.addListener(_load);
  }

  @override
  void dispose() {
    LocalStoreService.applicationsRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final account = await LocalStoreService.instance.getCurrentUser();
    final submissions = account == null ? <ListingApplication>[] : await ApplicationService.instance.getMine(account.email);
    if (!mounted) return;
    setState(() {
      _submissions = submissions;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My submissions')),
      bottomNavigationBar: const GlobalBottomNav(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _submissions.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            "You haven't applied to any schools or registered a business yet. "
                'Do that from a district\'s page — tap any district, then "Apply to study here" or '
                '"Register a business here".',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      )
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: _submissions.map((a) => _SubmissionTile(application: a)).toList(),
        ),
      ),
    );
  }
}

class _SubmissionTile extends StatelessWidget {
  final ListingApplication application;
  const _SubmissionTile({required this.application});

  Color get _statusColor {
    switch (application.status) {
      case 'approved':
        return AppColors.good;
      case 'rejected':
        return AppColors.bad;
      default:
        return AppColors.moderate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = application.status;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    application.category == 'school' ? Icons.school_outlined : Icons.storefront_outlined,
                    color: AppColors.brandDark,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(application.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: _statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      status[0].toUpperCase() + status.substring(1),
                      style: TextStyle(color: _statusColor, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${application.subtype} · ${application.state}${application.district != null ? ', ${application.district}' : ''}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
              ),
              if (application.matchedOption != null && application.matchedOption!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Matched to: ${application.matchedOption}', style: const TextStyle(fontSize: 12.5)),
              ],
              if (application.documents.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Documents confirmed: ${application.documents.join(', ')}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
              if (application.reviewNote != null && application.reviewNote!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Admin note: ${application.reviewNote}', style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}




