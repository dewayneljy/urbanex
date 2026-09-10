import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models.dart';
import '../services/application_service.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../services/local_store_service.dart';
import '../services/news_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Admin dashboard - only reachable from Profile, and only shown there
/// for a signed-in account with isAdmin == true.
///
/// Six tabs:
///  - Users: view every account registered on this device, search them,
///    promote/demote other admins, and delete accounts.
///  - Applications: view every school-application / business-registration
///    submission, filter by status, and approve / reject / reset it.
///  - Feedback: view every message submitted from Contact & feedback,
///    mark it read/unread, or delete it.
///  - News: add, edit, or delete a district news update - moved here
///    from the district detail page so every district's news is managed
///    from one place, rather than one at a time from within each page.
///  - Reviews: view every district review left by users (across every
///    district at once), and delete any of them.
///  - Issues: view every district-scoped bug/issue report, mark it
///    read/resolved, or delete it.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin dashboard'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Users'),
              Tab(text: 'Applications'),
              Tab(text: 'Feedback'),
              Tab(text: 'News'),
              Tab(text: 'Reviews'),
              Tab(text: 'Issues'),
              Tab(text: 'Analytics'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _UsersTab(),
            _ApplicationsTab(),
            _FeedbackTab(),
            _NewsTab(),
            _ReviewsTab(),
            _IssuesTab(),
            _AnalyticsTab(),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Users tab
// ============================================================

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  List<UserAccount> _users = [];
  String? _currentEmail;
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
    LocalStoreService.usersRevision.addListener(_load);
  }

  @override
  void dispose() {
    LocalStoreService.usersRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final users = await AuthService.instance.getAllUsers();
    final currentEmail = await LocalStoreService.instance.getCurrentUserEmail();
    if (!mounted) return;
    setState(() {
      _users = users;
      _currentEmail = currentEmail;
      _loading = false;
    });
  }

  List<UserAccount> get _filtered {
    if (_query.trim().isEmpty) return _users;
    final q = _query.trim().toLowerCase();
    return _users.where((u) => u.email.contains(q) || u.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final adminCount = _users.where((u) => u.isAdmin).length;

    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(child: _StatTile(icon: Icons.people_outline, label: 'Total users', value: '${_users.length}')),
              const SizedBox(width: 12),
              Expanded(child: _StatTile(icon: Icons.admin_panel_settings_outlined, label: 'Admins', value: '$adminCount')),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search by name or email',
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
          const SizedBox(height: 16),
          if (_filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  _users.isEmpty ? 'No registered accounts on this device yet' : 'No users match your search',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            )
          else
            ..._filtered.map((u) => _UserTile(
              user: u,
              isSelf: u.email == _currentEmail,
              onTap: () => _showUserActions(u),
            )),
        ],
      ),
    );
  }

  void _showUserActions(UserAccount user) {
    final isSelf = user.email == _currentEmail;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.brand,
                        child: Icon(user.isAdmin ? Icons.admin_panel_settings : Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(user.email, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(user.isAdmin ? Icons.remove_moderator_outlined : Icons.add_moderator_outlined),
                  title: Text(user.isAdmin ? 'Remove admin' : 'Make admin'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final result = await AuthService.instance.setAdminStatus(user.email, !user.isAdmin);
                    _showResultSnackBar(result, successMessage: user.isAdmin ? 'Admin removed' : 'Admin granted');
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: AppColors.bad),
                  title: Text('Delete account', style: TextStyle(color: AppColors.bad)),
                  subtitle: isSelf ? const Text("This is your own account") : null,
                  onTap: () async {
                    Navigator.pop(ctx);
                    _confirmDelete(user);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(UserAccount user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this account?'),
        content: Text("This permanently removes ${user.email} from this device. This can't be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.bad, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await AuthService.instance.deleteUser(user.email);
    _showResultSnackBar(result, successMessage: 'Account deleted');
  }

  void _showResultSnackBar(AuthResult result, {required String successMessage}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.success ? successMessage : (result.error ?? 'Something went wrong'))),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.brand, size: 20),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final UserAccount user;
  final bool isSelf;
  final VoidCallback onTap;
  const _UserTile({required this.user, required this.isSelf, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: user.isAdmin ? AppColors.brand : Colors.grey.shade300,
            child: Icon(
              user.isAdmin ? Icons.admin_panel_settings : Icons.person_outline,
              color: user.isAdmin ? Colors.white : Colors.grey.shade700,
            ),
          ),
          title: Row(
            children: [
              Flexible(child: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              if (isSelf) ...[
                const SizedBox(width: 6),
                Text('(you)', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ],
          ),
          subtitle: Text(user.email, style: const TextStyle(fontSize: 12.5)),
          trailing: user.isAdmin
              ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.brand.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Admin', style: TextStyle(color: AppColors.brand, fontSize: 11, fontWeight: FontWeight.w600)),
          )
              : const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}

// ============================================================
// Applications tab
// ============================================================

class _ApplicationsTab extends StatefulWidget {
  const _ApplicationsTab();

  @override
  State<_ApplicationsTab> createState() => _ApplicationsTabState();
}

class _ApplicationsTabState extends State<_ApplicationsTab> {
  List<ListingApplication> _applications = [];
  bool _loading = true;
  String _statusFilter = 'all'; // all | pending | approved | rejected

  static const _filters = ['all', 'pending', 'approved', 'rejected'];

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
    final apps = await ApplicationService.instance.getAll();
    if (!mounted) return;
    setState(() {
      _applications = apps;
      _loading = false;
    });
  }

  List<ListingApplication> get _filtered {
    if (_statusFilter == 'all') return _applications;
    return _applications.where((a) => a.status == _statusFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final pendingCount = _applications.where((a) => a.status == 'pending').length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(child: _StatTile(icon: Icons.assignment_outlined, label: 'Total applications', value: '${_applications.length}')),
              const SizedBox(width: 12),
              Expanded(child: _StatTile(icon: Icons.pending_actions_outlined, label: 'Pending review', value: '$pendingCount')),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: _filters.map((f) {
              final selected = _statusFilter == f;
              return ChoiceChip(
                label: Text(f[0].toUpperCase() + f.substring(1)),
                selected: selected,
                onSelected: (_) => setState(() => _statusFilter = f),
                selectedColor: AppColors.brand.withOpacity(0.15),
                labelStyle: TextStyle(color: selected ? AppColors.brand : Colors.grey.shade700, fontWeight: FontWeight.w600),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          if (_filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  _applications.isEmpty ? 'No applications submitted yet' : 'No applications match this filter',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            )
          else
            ..._filtered.map((a) => _ApplicationTile(application: a, onTap: () => _showApplicationActions(a))),
        ],
      ),
    );
  }

  void _showApplicationActions(ListingApplication app) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.brand,
                        child: Icon(app.category == 'school' ? Icons.school : Icons.storefront, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(app.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('${app.subtype} · ${app.state}${app.district != null ? ', ${app.district}' : ''}',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                          ],
                        ),
                      ),
                      _StatusBadge(status: app.status),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 20),
                      _DetailRow(label: 'Applicant', value: '${app.applicantName} (${app.applicantEmail})'),
                      _DetailRow(label: 'Contact', value: app.contact),
                      _DetailRow(label: 'Description', value: app.description),
                      if (app.matchedOption != null && app.matchedOption!.isNotEmpty)
                        _DetailRow(label: 'Matched to', value: app.matchedOption!),
                      if (app.category == 'business') ..._businessDetailRows(app),
                      if (app.category == 'school') ..._schoolDetailRows(app),
                      if (app.documents.isNotEmpty) _DocumentsSection(label: 'Documents submitted', documents: app.documents),
                      if (app.reviewNote != null && app.reviewNote!.isNotEmpty)
                        _DetailRow(label: 'Review note', value: app.reviewNote!),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                if (app.status != 'approved')
                  ListTile(
                    leading: const Icon(Icons.check_circle_outline, color: AppColors.good),
                    title: const Text('Approve'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final result = await ApplicationService.instance.approve(app.id);
                      _showResultSnackBar(result, successMessage: 'Application approved');
                    },
                  ),
                if (app.status != 'rejected')
                  ListTile(
                    leading: Icon(Icons.cancel_outlined, color: AppColors.bad),
                    title: const Text('Reject'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _rejectWithNote(app);
                    },
                  ),
                if (app.status != 'pending')
                  ListTile(
                    leading: const Icon(Icons.restart_alt),
                    title: const Text('Reset to pending'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final result = await ApplicationService.instance.resetToPending(app.id);
                      _showResultSnackBar(result, successMessage: 'Status reset to pending');
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _rejectWithNote(ListingApplication app) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject this application?'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'Let the applicant know why',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Reject', style: TextStyle(color: AppColors.bad, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await ApplicationService.instance.reject(app.id, note: controller.text.trim());
    _showResultSnackBar(result, successMessage: 'Application rejected');
  }

  void _showResultSnackBar(AuthResult result, {required String successMessage}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.success ? successMessage : (result.error ?? 'Something went wrong'))),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13.5)),
        ],
      ),
    );
  }
}

/// The extended set of business-registration fields shown to an admin
/// reviewing a 'business' category application - everything the new
/// multi-section registration form collects beyond what school and
/// business applications already share.
List<Widget> _businessDetailRows(ListingApplication app) {
  final rows = <Widget>[];

  if (app.businessType != null && app.businessType!.isNotEmpty) {
    rows.add(_DetailRow(label: 'Business type', value: app.businessType!));
  }

  final addressParts = [app.addressLine1, app.addressLine2, app.addressCity, app.addressState, app.addressPostcode]
      .where((p) => p != null && p.trim().isNotEmpty)
      .join(', ');
  if (addressParts.isNotEmpty) {
    rows.add(_DetailRow(label: 'Business address', value: addressParts));
  }

  if ((app.ownerIdType != null && app.ownerIdType!.isNotEmpty) || (app.ownerIdNumber != null && app.ownerIdNumber!.isNotEmpty)) {
    rows.add(_DetailRow(label: 'Owner ID', value: '${app.ownerIdType ?? '-'} · ${app.ownerIdNumber ?? '-'}'));
  }
  if (app.ownerEmail != null && app.ownerEmail!.isNotEmpty) {
    rows.add(_DetailRow(label: 'Owner email', value: app.ownerEmail!));
  }
  if (app.ownerPhone != null && app.ownerPhone!.isNotEmpty) {
    rows.add(_DetailRow(label: 'Owner phone', value: app.ownerPhone!));
  }
  if (app.ownerResidentialAddress != null && app.ownerResidentialAddress!.isNotEmpty) {
    rows.add(_DetailRow(label: 'Owner residential address', value: app.ownerResidentialAddress!));
  }
  if (app.ownerNationality != null && app.ownerNationality!.isNotEmpty) {
    rows.add(_DetailRow(label: 'Nationality', value: app.ownerNationality!));
  }

  if (app.partners.isNotEmpty) {
    final partnersText = app.partners
        .map((p) => '${p.fullName} (${p.idType} ${p.idNumber}, ${p.email}, ${p.phone})')
        .join('\n');
    rows.add(_DetailRow(label: 'Partners', value: partnersText));
  }

  rows.add(_DetailRow(label: 'Requires licence/permit', value: app.requiresLicence ? 'Yes' : 'No'));
  if (app.requiresLicence) {
    if (app.licenceType != null && app.licenceType!.isNotEmpty) {
      rows.add(_DetailRow(label: 'Licence type', value: app.licenceType!));
    }
    if (app.licenceNumber != null && app.licenceNumber!.isNotEmpty) {
      rows.add(_DetailRow(label: 'Licence number', value: app.licenceNumber!));
    }
    if (app.licenceDocument != null) {
      rows.add(_DocumentsSection(label: 'Licence document', documents: [app.licenceDocument!]));
    }
  }

  final declarations = <String>[
    if (app.declarationInfoAccurate) 'Confirmed information is accurate',
    if (app.declarationAgreeTerms) 'Agreed to Terms and Conditions',
    if (app.declarationUnderstandVerification) 'Acknowledged additional documents may be requested',
  ];
  if (declarations.isNotEmpty) {
    rows.add(_DetailRow(label: 'Declaration', value: declarations.join('\n')));
  }

  return rows;
}

/// The extended set of school-application fields shown to an admin
/// reviewing a 'school' category application - everything the new
/// multi-section application form collects beyond what school and
/// business applications already share.
List<Widget> _schoolDetailRows(ListingApplication app) {
  final rows = <Widget>[];

  if (app.schoolType != null && app.schoolType!.isNotEmpty) {
    rows.add(_DetailRow(label: 'School type', value: app.schoolType!));
  }

  final studentIdParts = <String>[
    if (app.studentDob != null && app.studentDob!.isNotEmpty) 'DOB: ${app.studentDob}',
    if (app.studentGender != null && app.studentGender!.isNotEmpty) app.studentGender!,
    if (app.studentNationality != null && app.studentNationality!.isNotEmpty) app.studentNationality!,
  ];
  if (studentIdParts.isNotEmpty) {
    rows.add(_DetailRow(label: 'Student', value: studentIdParts.join(' · ')));
  }
  if ((app.studentIdType != null && app.studentIdType!.isNotEmpty) || (app.studentIdNumber != null && app.studentIdNumber!.isNotEmpty)) {
    rows.add(_DetailRow(label: 'Student ID', value: '${app.studentIdType ?? '-'} · ${app.studentIdNumber ?? '-'}'));
  }
  if (app.studentEmail != null && app.studentEmail!.isNotEmpty) {
    rows.add(_DetailRow(label: 'Student email', value: app.studentEmail!));
  }
  if (app.studentPhone != null && app.studentPhone!.isNotEmpty) {
    rows.add(_DetailRow(label: 'Student phone', value: app.studentPhone!));
  }

  if (app.guardians.isNotEmpty) {
    final guardiansText = app.guardians
        .map((g) => '${g.fullName} (${g.relationship}) · ${g.phone} · ${g.email}${g.occupation.isNotEmpty ? ' · ${g.occupation}' : ''}')
        .join('\n');
    rows.add(_DetailRow(label: 'Parent(s)/Guardian(s)', value: guardiansText));
  }

  final addressParts = [
    app.studentAddressLine1,
    app.studentAddressLine2,
    app.studentAddressCity,
    app.studentAddressState,
    app.studentAddressPostcode,
  ].where((p) => p != null && p.trim().isNotEmpty).join(', ');
  if (addressParts.isNotEmpty) {
    rows.add(_DetailRow(label: 'Student address', value: addressParts));
  }

  if (app.previousSchool != null && app.previousSchool!.isNotEmpty) {
    rows.add(_DetailRow(label: 'Previous school', value: app.previousSchool!));
  }
  if (app.previousLevel != null && app.previousLevel!.isNotEmpty) {
    rows.add(_DetailRow(label: 'Previous year/level', value: app.previousLevel!));
  }
  if (app.academicResultsDocument != null) {
    rows.add(_DocumentsSection(label: 'Academic results', documents: [app.academicResultsDocument!]));
  }
  if (app.previousAchievements != null && app.previousAchievements!.isNotEmpty) {
    rows.add(_DetailRow(label: 'Previous achievements', value: app.previousAchievements!));
  }

  final declarations = <String>[
    if (app.declarationInfoAccurate) 'Confirmed information is true and accurate',
    if (app.declarationAuthorizedToSubmit) 'Confirmed authorized to submit',
    if (app.declarationAgreeTerms) "Agreed to the school's terms and conditions",
  ];
  if (declarations.isNotEmpty) {
    rows.add(_DetailRow(label: 'Declaration', value: declarations.join('\n')));
  }

  return rows;
}

/// A label + a row of tappable chips, one per attached document, shown
/// wherever an admin needs to review what an applicant actually
/// uploaded. Tapping a chip opens [_DocumentViewerDialog] with the real
/// file - not just its name.
class _DocumentsSection extends StatelessWidget {
  final String label;
  final List<UploadedDocument> documents;

  const _DocumentsSection({required this.label, required this.documents});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: documents.map((doc) => _DocumentChip(document: doc)).toList(),
          ),
        ],
      ),
    );
  }
}

class _DocumentChip extends StatelessWidget {
  final UploadedDocument document;
  const _DocumentChip({required this.document});

  bool get _isImage => document.mimeType?.startsWith('image/') ?? false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => showDialog(context: context, builder: (_) => _DocumentViewerDialog(document: document)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.brand.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.brand.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_isImage ? Icons.image_outlined : Icons.description_outlined, size: 16, color: AppColors.brandDark),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(document.fileName,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: AppColors.brandDark)),
            ),
            const SizedBox(width: 4),
            Icon(Icons.visibility_outlined, size: 14, color: AppColors.brandDark),
          ],
        ),
      ),
    );
  }
}

/// Renders the actual uploaded file, not just its name: a real preview
/// for images, a text preview for plain-text formats, and an honest
/// fallback (with the file's real size) for anything this build can't
/// render in-app, like PDFs - there's no PDF-rendering package wired up
/// in this project yet.
class _DocumentViewerDialog extends StatelessWidget {
  final UploadedDocument document;
  const _DocumentViewerDialog({required this.document});

  @override
  Widget build(BuildContext context) {
    final base64Data = document.base64Data;
    Uint8List? bytes;
    if (base64Data != null) {
      try {
        bytes = base64Decode(base64Data);
      } catch (_) {
        bytes = null;
      }
    }

    final mime = document.mimeType ?? '';
    final isImage = mime.startsWith('image/');
    final isText = mime.startsWith('text/') || mime == 'application/json';

    Widget content;
    if (bytes == null) {
      content = _fallbackNotice(
        "This file's data wasn't kept in local storage (it may have been "
            "too large, or read failed when it was picked), so only its name is available.",
      );
    } else if (isImage) {
      content = InteractiveViewer(
        maxScale: 4,
        child: Image.memory(bytes, fit: BoxFit.contain),
      );
    } else if (isText) {
      String text;
      try {
        text = utf8.decode(bytes);
      } catch (_) {
        text = '(Could not decode this file as text)';
      }
      content = SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Text(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5)),
      );
    } else {
      content = _fallbackNotice(
        "Preview isn't available for this file type in the app, but the actual uploaded file "
            "(${_formatBytes(bytes.length)}) is stored - this isn't just a filename.",
      );
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(document.fileName,
                        style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(child: Padding(padding: const EdgeInsets.all(12), child: content)),
          ],
        ),
      ),
    );
  }

  Widget _fallbackNotice(String message) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.insert_drive_file_outlined, size: 48, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  Color get _color {
    switch (status) {
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: _color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ApplicationTile extends StatelessWidget {
  final ListingApplication application;
  final VoidCallback onTap;
  const _ApplicationTile({required this.application, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey.shade200,
            child: Icon(
              application.category == 'school' ? Icons.school_outlined : Icons.storefront_outlined,
              color: AppColors.brandDark,
            ),
          ),
          title: Text(application.name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          subtitle: Text('${application.subtype} · ${application.state} · by ${application.applicantName}',
              style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
          trailing: _StatusBadge(status: application.status),
          onTap: onTap,
        ),
      ),
    );
  }
}

// ============================================================
// Feedback tab
// ============================================================

class _FeedbackTab extends StatefulWidget {
  const _FeedbackTab();

  @override
  State<_FeedbackTab> createState() => _FeedbackTabState();
}

class _FeedbackTabState extends State<_FeedbackTab> {
  List<FeedbackEntry> _feedback = [];
  bool _loading = true;
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
    LocalStoreService.feedbackRevision.addListener(_load);
  }

  @override
  void dispose() {
    LocalStoreService.feedbackRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final feedback = await LocalStoreService.instance.getFeedback();
    feedback.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    if (!mounted) return;
    setState(() {
      _feedback = feedback;
      _loading = false;
    });
  }

  List<FeedbackEntry> get _filtered => _unreadOnly ? _feedback.where((f) => !f.read).toList() : _feedback;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final unreadCount = _feedback.where((f) => !f.read).length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(child: _StatTile(icon: Icons.mail_outline, label: 'Total messages', value: '${_feedback.length}')),
              const SizedBox(width: 12),
              Expanded(child: _StatTile(icon: Icons.markunread_outlined, label: 'Unread', value: '$unreadCount')),
            ],
          ),
          const SizedBox(height: 16),
          FilterChip(
            label: const Text('Unread only'),
            selected: _unreadOnly,
            onSelected: (v) => setState(() => _unreadOnly = v),
            selectedColor: AppColors.brand.withOpacity(0.15),
            labelStyle: TextStyle(color: _unreadOnly ? AppColors.brand : Colors.grey.shade700, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          if (_filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  _feedback.isEmpty ? 'No feedback submitted yet' : 'No unread feedback',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            )
          else
            ..._filtered.map((f) => _FeedbackTile(entry: f, onTap: () => _showFeedbackActions(f))),
        ],
      ),
    );
  }

  void _showFeedbackActions(FeedbackEntry entry) {
    // Opening the sheet implies the admin has seen it - mark it read.
    if (!entry.read) LocalStoreService.instance.setFeedbackRead(entry.id, true);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.brand,
                        child: Icon(_iconFor(entry.category), color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(
                              entry.name ?? entry.email ?? 'Anonymous',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 20),
                      if (entry.email != null) _DetailRow(label: 'Reply-to', value: entry.email!),
                      _DetailRow(label: 'Message', value: entry.message),
                      if (entry.hasReply) ...[
                        const SizedBox(height: 4),
                        _DetailRow(label: 'Your reply', value: entry.adminReply!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(entry.hasReply ? Icons.edit_outlined : Icons.reply_outlined, color: AppColors.brand),
                  title: Text(entry.hasReply ? 'Edit reply' : 'Reply'),
                  subtitle: entry.submittedByEmail == null
                      ? const Text("Submitted anonymously — they won't get an in-app notification")
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showReplyDialog(entry);
                  },
                ),
                ListTile(
                  leading: Icon(entry.read ? Icons.markunread_outlined : Icons.mark_email_read_outlined),
                  title: Text(entry.read ? 'Mark as unread' : 'Mark as read'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await LocalStoreService.instance.setFeedbackRead(entry.id, !entry.read);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: AppColors.bad),
                  title: Text('Delete', style: TextStyle(color: AppColors.bad)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDelete(entry);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(FeedbackEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this feedback?'),
        content: const Text("This can't be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.bad, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await LocalStoreService.instance.deleteFeedback(entry.id);
  }

  Future<void> _showReplyDialog(FeedbackEntry entry) async {
    final controller = TextEditingController(text: entry.adminReply ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(entry.hasReply ? 'Edit reply' : 'Reply to this feedback'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Write your reply...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    await _replyToFeedback(entry, result);
  }

  Future<void> _replyToFeedback(FeedbackEntry entry, String reply) async {
    final admin = await LocalStoreService.instance.getCurrentUser();
    await LocalStoreService.instance.replyToFeedback(entry.id, reply, admin?.email ?? 'admin');

    // Only a signed-in submitter has an account to notify - an
    // anonymous/guest submission has nowhere for the reply to land.
    if (entry.submittedByEmail != null) {
      await LocalStoreService.instance.addNotification(NotificationEntry(
        id: '${DateTime.now().microsecondsSinceEpoch}-reply',
        type: 'feedback_reply',
        title: 'Reply to your feedback',
        body: reply,
        createdAt: DateTime.now(),
        recipientEmail: entry.submittedByEmail,
        relatedFeedbackId: entry.id,
      ));
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(entry.submittedByEmail != null ? 'Reply sent' : 'Reply saved (submitted anonymously, so no notification was sent)')),
    );
  }

  IconData _iconFor(String category) {
    switch (category) {
      case 'Bug report':
        return Icons.bug_report_outlined;
      case 'Feature request':
        return Icons.lightbulb_outline;
      default:
        return Icons.forum_outlined;
    }
  }
}

class _FeedbackTile extends StatelessWidget {
  final FeedbackEntry entry;
  final VoidCallback onTap;
  const _FeedbackTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        color: entry.read ? null : AppColors.brand.withOpacity(0.04),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: entry.read ? Colors.grey.shade200 : AppColors.brand.withOpacity(0.15),
            child: Icon(Icons.mail_outline, color: entry.read ? Colors.grey.shade600 : AppColors.brandDark),
          ),
          title: Text(
            entry.name ?? entry.email ?? 'Anonymous',
            style: TextStyle(fontWeight: entry.read ? FontWeight.w500 : FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text('${entry.category} · ${entry.message}', maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: entry.hasReply
              ? Icon(Icons.reply, size: 18, color: Colors.grey.shade400)
              : entry.read
              ? null
              : Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.brand, shape: BoxShape.circle)),
          onTap: onTap,
        ),
      ),
    );
  }
}

// ============================================================
// News tab
// ============================================================

class _NewsTab extends StatefulWidget {
  const _NewsTab();

  @override
  State<_NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends State<_NewsTab> {
  List<DistrictNews> _news = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
    LocalStoreService.districtNewsRevision.addListener(_load);
  }

  @override
  void dispose() {
    LocalStoreService.districtNewsRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final news = await LocalStoreService.instance.getDistrictNews();
    news.sort((a, b) => b.postedAt.compareTo(a.postedAt));
    if (!mounted) return;
    setState(() {
      _news = news;
      _loading = false;
    });
  }

  List<DistrictNews> get _filtered {
    if (_query.trim().isEmpty) return _news;
    final q = _query.trim().toLowerCase();
    return _news
        .where((n) => n.district.toLowerCase().contains(q) || n.state.toLowerCase().contains(q) || n.title.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final districtsCovered = _news.map((n) => '${n.state}|${n.district}').toSet().length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(child: _StatTile(icon: Icons.newspaper_outlined, label: 'Total updates', value: '${_news.length}')),
              const SizedBox(width: 12),
              Expanded(child: _StatTile(icon: Icons.map_outlined, label: 'Districts covered', value: '$districtsCovered')),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add),
            label: const Text('Add news update'),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search by district, state, or title',
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
          const SizedBox(height: 16),
          if (_filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  _news.isEmpty ? 'No district news posted yet' : 'No updates match your search',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            )
          else
            ..._filtered.map((n) => _NewsTile(news: n, onTap: () => _showNewsActions(n))),
        ],
      ),
    );
  }

  Future<void> _openEditor({DistrictNews? existing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _NewsEditorScreen(existing: existing)),
    );
    if (saved == true) _load();
  }

  void _showNewsActions(DistrictNews entry) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.brand,
                        child: const Icon(Icons.newspaper_outlined, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text('${entry.district}, ${entry.state}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 20),
                      _DetailRow(label: 'Message', value: entry.body),
                      _DetailRow(label: 'Posted by', value: entry.postedByEmail),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.edit_outlined, color: AppColors.brand),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openEditor(existing: entry);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: AppColors.bad),
                  title: Text('Delete', style: TextStyle(color: AppColors.bad)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDelete(entry);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(DistrictNews entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this update?'),
        content: Text("This removes \"${entry.title}\" for ${entry.district}. This can't be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.bad, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await NewsService.instance.deleteNews(entry.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.success ? 'Update deleted' : (result.error ?? 'Something went wrong'))),
    );
  }
}

class _NewsTile extends StatelessWidget {
  final DistrictNews news;
  final VoidCallback onTap;
  const _NewsTile({required this.news, required this.onTap});

  String get _relativeTime {
    final diff = DateTime.now().difference(news.postedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey.shade200,
            child: Icon(Icons.newspaper_outlined, color: AppColors.brandDark),
          ),
          title: Text(news.title, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${news.district}, ${news.state} · $_relativeTime', style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}

/// Full-screen form for adding a new district news update or editing an
/// existing one. Pops with `true` when a save succeeds so the News tab
/// knows to refresh (it also listens to districtNewsRevision, but the
/// explicit signal lets it show a snackbar right away).
class _NewsEditorScreen extends StatefulWidget {
  final DistrictNews? existing;
  const _NewsEditorScreen({this.existing});

  @override
  State<_NewsEditorScreen> createState() => _NewsEditorScreenState();
}

class _NewsEditorScreenState extends State<_NewsEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  List<DistrictData> _allDistricts = [];
  DistrictData? _selectedDistrict;
  bool _loadingDistricts = true;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existing?.title ?? '');
    _bodyController = TextEditingController(text: widget.existing?.body ?? '');
    DataService.instance.getDistricts().then((districts) {
      if (!mounted) return;
      setState(() {
        _allDistricts = [...districts]..sort((a, b) => a.district.compareTo(b.district));
        _loadingDistricts = false;
        if (widget.existing != null) {
          final e = widget.existing!;
          _selectedDistrict = _allDistricts.firstWhere(
                (d) => d.state == e.state && d.district == e.district,
            orElse: () => DistrictData(state: e.state, district: e.district),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickDistrict() async {
    final picked = await showDistrictPickerSheet(
      context,
      options: _allDistricts,
      currentValue: _selectedDistrict,
      title: 'Choose a district',
    );
    if (picked != null) setState(() => _selectedDistrict = picked);
  }

  Future<void> _save() async {
    final district = _selectedDistrict;
    if (district == null) {
      setState(() => _error = 'Please choose a district for this update.');
      return;
    }
    if (_titleController.text.trim().isEmpty || _bodyController.text.trim().isEmpty) {
      setState(() => _error = 'Please fill in both a title and a message.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final result = _isEditing
        ? await NewsService.instance.updateNews(
      existing: widget.existing!,
      state: district.state,
      district: district.district,
      title: _titleController.text,
      body: _bodyController.text,
    )
        : await NewsService.instance.postNews(
      state: district.state,
      district: district.district,
      title: _titleController.text,
      body: _bodyController.text,
    );

    if (!mounted) return;
    if (result.success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? 'Update saved' : 'Update posted')),
      );
    } else {
      setState(() {
        _saving = false;
        _error = result.error ?? 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit news update' : 'Add news update')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Post an update that shows up on a district\'s detail page, and notifies anyone who has that district favorited.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 20),
          const Text('District', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 10),
          HoverLiftCard(
            onTap: _loadingDistricts ? () {} : _pickDistrict,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.location_city_outlined, color: AppColors.brand),
                const SizedBox(width: 10),
                Expanded(
                  child: _loadingDistricts
                      ? Text('Loading districts...', style: TextStyle(color: Colors.grey.shade500))
                      : _selectedDistrict == null
                      ? Text('Tap to choose a district', style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic))
                      : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_selectedDistrict!.district, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(_selectedDistrict!.state, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _bodyController,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Message',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12.5)),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
              ),
            )
                : Text(_isEditing ? 'Save changes' : 'Post update'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Analytics tab
// ============================================================

/// At-a-glance charts built entirely from data already stored on this
/// device (applications, feedback, registered users) - no new datasets
/// or backend needed. Stays live the same way every other tab does, by
/// listening to the relevant revision notifiers.
class _AnalyticsTab extends StatefulWidget {
  const _AnalyticsTab();

  @override
  State<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<_AnalyticsTab> {
  List<ListingApplication> _applications = [];
  List<FeedbackEntry> _feedback = [];
  List<UserAccount> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    LocalStoreService.applicationsRevision.addListener(_load);
    LocalStoreService.feedbackRevision.addListener(_load);
    LocalStoreService.usersRevision.addListener(_load);
  }

  @override
  void dispose() {
    LocalStoreService.applicationsRevision.removeListener(_load);
    LocalStoreService.feedbackRevision.removeListener(_load);
    LocalStoreService.usersRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final apps = await ApplicationService.instance.getAll();
    final feedback = await LocalStoreService.instance.getFeedback();
    final users = await AuthService.instance.getAllUsers();
    if (!mounted) return;
    setState(() {
      _applications = apps;
      _feedback = feedback;
      _users = users;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final pending = _applications.where((a) => a.status == 'pending').length;
    final approved = _applications.where((a) => a.status == 'approved').length;
    final rejected = _applications.where((a) => a.status == 'rejected').length;
    final schoolCount = _applications.where((a) => a.category == 'school').length;
    final businessCount = _applications.where((a) => a.category == 'business').length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(child: _StatTile(icon: Icons.description_outlined, label: 'Total applications', value: '${_applications.length}')),
              const SizedBox(width: 12),
              Expanded(child: _StatTile(icon: Icons.hourglass_top_outlined, label: 'Pending review', value: '$pending')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatTile(icon: Icons.forum_outlined, label: 'Feedback received', value: '${_feedback.length}')),
              const SizedBox(width: 12),
              Expanded(child: _StatTile(icon: Icons.people_outline, label: 'Registered users', value: '${_users.length}')),
            ],
          ),
          const SizedBox(height: 24),

          _ChartCard(
            title: 'Applications - last 14 days',
            subtitle: 'School and business submissions combined',
            child: _ApplicationsTrendChart(applications: _applications),
          ),
          const SizedBox(height: 20),

          _ChartCard(
            title: 'Applications by status',
            subtitle: '$pending pending · $approved approved · $rejected rejected',
            child: _StatusPieChart(pending: pending, approved: approved, rejected: rejected),
          ),
          const SizedBox(height: 20),

          _ChartCard(
            title: 'Applications by type',
            subtitle: 'School vs. business registrations',
            child: DuoStatBar(
              label: 'Submissions',
              leftValueText: '$schoolCount school',
              rightValueText: '$businessCount business',
              leftFraction: _applications.isEmpty ? 0 : schoolCount / _applications.length,
              rightFraction: _applications.isEmpty ? 0 : businessCount / _applications.length,
              winner: schoolCount == businessCount ? 0 : (schoolCount > businessCount ? -1 : 1),
            ),
          ),
          const SizedBox(height: 20),

          _ChartCard(
            title: 'Feedback by category',
            subtitle: 'What people are contacting you about',
            child: _FeedbackCategoryChart(feedback: _feedback),
          ),
          const SizedBox(height: 20),

          _ChartCard(
            title: 'Registered users over time',
            subtitle: 'Cumulative sign-ups on this device, in registration order',
            child: _UserGrowthChart(users: _users),
          ),
        ],
      ),
    );
  }
}

/// Shared card shell for every chart on the Analytics tab - title,
/// subtitle, then the chart itself - so they all read as one consistent
/// dashboard instead of differently-styled widgets bolted together.
class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _ChartCard({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// Daily count of applications submitted (any status) over the last 14
/// days, so an admin can see whether submissions are trending up.
class _ApplicationsTrendChart extends StatelessWidget {
  final List<ListingApplication> applications;
  const _ApplicationsTrendChart({required this.applications});

  @override
  Widget build(BuildContext context) {
    if (applications.isEmpty) {
      return const SizedBox(height: 160, child: Center(child: Text('No applications submitted yet')));
    }

    final now = DateTime.now();
    final days = List.generate(14, (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 13 - i)));
    final counts = <int>[
      for (final day in days)
        applications.where((a) {
          final d = a.submittedAt;
          return d.year == day.year && d.month == day.month && d.day == day.day;
        }).length,
    ];
    final maxCount = counts.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 190,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maxCount == 0 ? 1 : maxCount).toDouble() + 1,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final day = days[group.x.toInt()];
                return BarTooltipItem('${day.day}/${day.month}\n${rod.toY.round()} applications', const TextStyle(color: Colors.white, fontSize: 11));
              },
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24, interval: 1)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: 2,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= days.length) return const SizedBox.shrink();
                  final day = days[i];
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${day.day}/${day.month}', style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < days.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(toY: counts[i].toDouble(), color: AppColors.brand, width: 12, borderRadius: BorderRadius.circular(4)),
              ]),
          ],
        ),
      ),
    );
  }
}

/// Donut chart of pending vs. approved vs. rejected applications, using
/// the same colors as [_StatusBadge] so the two views agree visually.
class _StatusPieChart extends StatelessWidget {
  final int pending;
  final int approved;
  final int rejected;
  const _StatusPieChart({required this.pending, required this.approved, required this.rejected});

  @override
  Widget build(BuildContext context) {
    final total = pending + approved + rejected;
    if (total == 0) {
      return const SizedBox(height: 160, child: Center(child: Text('No applications submitted yet')));
    }
    return SizedBox(
      height: 180,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 34,
                sections: [
                  if (pending > 0)
                    PieChartSectionData(
                      value: pending.toDouble(),
                      color: AppColors.moderate,
                      title: '$pending',
                      radius: 50,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  if (approved > 0)
                    PieChartSectionData(
                      value: approved.toDouble(),
                      color: AppColors.good,
                      title: '$approved',
                      radius: 50,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  if (rejected > 0)
                    PieChartSectionData(
                      value: rejected.toDouble(),
                      color: AppColors.bad,
                      title: '$rejected',
                      radius: 50,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _legendDot(AppColors.moderate, 'Pending'),
                const SizedBox(height: 8),
                _legendDot(AppColors.good, 'Approved'),
                const SizedBox(height: 8),
                _legendDot(AppColors.bad, 'Rejected'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12.5)),
      ],
    );
  }
}

/// Bar chart of feedback counts per category (Bug report / Feature
/// request / General feedback), matching the category list in
/// FeedbackScreen.
class _FeedbackCategoryChart extends StatelessWidget {
  final List<FeedbackEntry> feedback;
  const _FeedbackCategoryChart({required this.feedback});

  static const _categories = ['Bug report', 'Feature request', 'General feedback'];

  @override
  Widget build(BuildContext context) {
    if (feedback.isEmpty) {
      return const SizedBox(height: 150, child: Center(child: Text('No feedback submitted yet')));
    }
    final counts = [for (final c in _categories) feedback.where((f) => f.category == c).length];
    final maxCount = counts.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 170,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceEvenly,
          maxY: (maxCount == 0 ? 1 : maxCount).toDouble() + 1,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24, interval: 1)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= _categories.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_categories[i], textAlign: TextAlign.center, style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < _categories.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(toY: counts[i].toDouble(), color: AppColors.compareB, width: 28, borderRadius: BorderRadius.circular(6)),
              ]),
          ],
        ),
      ),
    );
  }
}

/// Cumulative registered-user count, in registration order - a simple
/// growth curve for this device's local account list.
class _UserGrowthChart extends StatelessWidget {
  final List<UserAccount> users;
  const _UserGrowthChart({required this.users});

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const SizedBox(height: 150, child: Center(child: Text('No registered accounts yet')));
    }
    final sorted = [...users]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final points = <FlSpot>[
      for (var i = 0; i < sorted.length; i++) FlSpot(i.toDouble(), (i + 1).toDouble()),
    ];

    return SizedBox(
      height: 170,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 1)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          minY: 0,
          maxY: (sorted.length + 1).toDouble(),
          lineBarsData: [
            LineChartBarData(
              spots: points,
              isCurved: true,
              color: AppColors.brand,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: AppColors.brand.withOpacity(0.12)),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Reviews tab
// ============================================================

class _ReviewsTab extends StatefulWidget {
  const _ReviewsTab();

  @override
  State<_ReviewsTab> createState() => _ReviewsTabState();
}

class _ReviewsTabState extends State<_ReviewsTab> {
  List<DistrictReview> _reviews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    LocalStoreService.districtReviewsRevision.addListener(_load);
  }

  @override
  void dispose() {
    LocalStoreService.districtReviewsRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final reviews = await LocalStoreService.instance.getDistrictReviews();
    reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (!mounted) return;
    setState(() {
      _reviews = reviews;
      _loading = false;
    });
  }

  Future<void> _confirmDelete(DistrictReview review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this review?'),
        content: Text('This removes ${review.authorName}\'s review of ${review.district}. This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.bad, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await LocalStoreService.instance.deleteDistrictReview(review.id);
    }
  }

  double get _averageRating =>
      _reviews.isEmpty ? 0 : _reviews.map((r) => r.rating).reduce((a, b) => a + b) / _reviews.length;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(child: _StatTile(icon: Icons.reviews_outlined, label: 'Total reviews', value: '${_reviews.length}')),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatTile(
                      icon: Icons.star_outline, label: 'Avg. rating', value: _reviews.isEmpty ? '-' : _averageRating.toStringAsFixed(1))),
            ],
          ),
          const SizedBox(height: 16),
          if (_reviews.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('No reviews submitted yet', style: TextStyle(color: Colors.grey.shade500))),
            )
          else
            ..._reviews.map((r) => _AdminReviewTile(review: r, onDelete: () => _confirmDelete(r))),
        ],
      ),
    );
  }
}

class _AdminReviewTile extends StatelessWidget {
  final DistrictReview review;
  final VoidCallback onDelete;
  const _AdminReviewTile({required this.review, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${review.district}, ${review.state}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                      Text('${review.authorName} (${review.authorEmail})',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(icon: Icon(Icons.delete_outline, color: AppColors.bad), onPressed: onDelete),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                ...List.generate(5, (i) => Icon(i < review.rating ? Icons.star : Icons.star_border, size: 16, color: Colors.amber.shade600)),
                const SizedBox(width: 8),
                Text('${review.createdAt.toLocal()}'.split('.').first, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              ],
            ),
            if (review.comment.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(review.comment, style: const TextStyle(fontSize: 13, height: 1.4)),
            ],
            if (review.image != null) ...[
              const SizedBox(height: 10),
              _DocumentsSection(label: 'Photo', documents: [review.image!]),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Issues tab
// ============================================================

class _IssuesTab extends StatefulWidget {
  const _IssuesTab();

  @override
  State<_IssuesTab> createState() => _IssuesTabState();
}

class _IssuesTabState extends State<_IssuesTab> {
  List<DistrictIssueReport> _issues = [];
  bool _loading = true;
  bool _unresolvedOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
    LocalStoreService.districtIssuesRevision.addListener(_load);
  }

  @override
  void dispose() {
    LocalStoreService.districtIssuesRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final issues = await LocalStoreService.instance.getDistrictIssueReports();
    issues.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    if (!mounted) return;
    setState(() {
      _issues = issues;
      _loading = false;
    });
  }

  List<DistrictIssueReport> get _filtered => _unresolvedOnly ? _issues.where((i) => !i.resolved).toList() : _issues;

  Future<void> _confirmDelete(DistrictIssueReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this report?'),
        content: const Text("This can't be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.bad, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await LocalStoreService.instance.deleteDistrictIssueReport(report.id);
    }
  }

  void _showIssueActions(DistrictIssueReport report) {
    if (!report.read) LocalStoreService.instance.setDistrictIssueReportRead(report.id, true);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.brand,
                        child: Icon(report.category == 'Bug' ? Icons.bug_report_outlined : Icons.flag_outlined, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(report.category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('${report.district}, ${report.state}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 20),
                      _DetailRow(label: 'Reported by', value: report.reporterName ?? report.reporterEmail ?? 'Anonymous'),
                      if (report.reporterEmail != null) _DetailRow(label: 'Email', value: report.reporterEmail!),
                      _DetailRow(label: 'Description', value: report.description),
                      _DetailRow(label: 'Status', value: report.resolved ? 'Resolved' : 'Open'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(report.resolved ? Icons.undo_outlined : Icons.check_circle_outline,
                      color: report.resolved ? null : AppColors.good),
                  title: Text(report.resolved ? 'Mark as unresolved' : 'Mark as resolved'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await LocalStoreService.instance.setDistrictIssueReportResolved(report.id, !report.resolved);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: AppColors.bad),
                  title: Text('Delete', style: TextStyle(color: AppColors.bad)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDelete(report);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final unresolvedCount = _issues.where((i) => !i.resolved).length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(child: _StatTile(icon: Icons.flag_outlined, label: 'Total reports', value: '${_issues.length}')),
              const SizedBox(width: 12),
              Expanded(child: _StatTile(icon: Icons.error_outline, label: 'Unresolved', value: '$unresolvedCount')),
            ],
          ),
          const SizedBox(height: 16),
          FilterChip(
            label: const Text('Unresolved only'),
            selected: _unresolvedOnly,
            onSelected: (v) => setState(() => _unresolvedOnly = v),
            selectedColor: AppColors.brand.withOpacity(0.15),
            labelStyle: TextStyle(color: _unresolvedOnly ? AppColors.brand : Colors.grey.shade700, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          if (_filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  _issues.isEmpty ? 'No issues reported yet' : 'No unresolved issues',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            )
          else
            ..._filtered.map((r) => _IssueTile(report: r, onTap: () => _showIssueActions(r))),
        ],
      ),
    );
  }
}

class _IssueTile extends StatelessWidget {
  final DistrictIssueReport report;
  final VoidCallback onTap;
  const _IssueTile({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: report.read ? Colors.grey.shade200 : AppColors.brand.withOpacity(0.15),
          child: Icon(
            report.category == 'Bug' ? Icons.bug_report_outlined : Icons.flag_outlined,
            color: report.read ? Colors.grey.shade600 : AppColors.brandDark,
          ),
        ),
        title: Text('${report.category} · ${report.district}, ${report.state}',
            style: TextStyle(fontWeight: report.read ? FontWeight.normal : FontWeight.bold, fontSize: 14)),
        subtitle: Text(report.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
        trailing: report.resolved
            ? Icon(Icons.check_circle, color: AppColors.good, size: 18)
            : Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400, size: 18),
      ),
    );
  }
}



