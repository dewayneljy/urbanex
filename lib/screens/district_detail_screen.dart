import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models.dart';
import '../services/data_service.dart';
import '../services/local_store_service.dart';
import '../services/upload_utils.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/document_upload_tile.dart';
import '../services/auth_screen.dart';
import 'business_application_screen.dart';
import 'school_application_screen.dart';
import '../widgets/location_info_widgets.dart';

class DistrictDetailScreen extends StatefulWidget {
  final DistrictData district;
  final double? overrideScore;

  const DistrictDetailScreen({super.key, required this.district, this.overrideScore});

  @override
  State<DistrictDetailScreen> createState() => _DistrictDetailScreenState();
}

class _DistrictDetailScreenState extends State<DistrictDetailScreen> {
  bool _isFavorite = false;
  List<TrendPoint> _trend = [];
  bool _loadingTrend = true;
  List<DistrictNews> _news = [];
  bool _loadingNews = true;
  List<DistrictReview> _reviews = [];
  bool _loadingReviews = true;
  UserAccount? _currentUser;

  FavoriteEntry get _entry => FavoriteEntry(
    type: 'district',
    state: widget.district.state,
    district: widget.district.district,
    score: widget.overrideScore ?? widget.district.livabilityScore(),
  );

  @override
  void initState() {
    super.initState();
    LocalStoreService.instance.isFavorite(_entry.id).then((v) => setState(() => _isFavorite = v));
    DataService.instance.getIncomeTrend(widget.district.state, widget.district.district).then((t) {
      if (mounted) setState(() {
        _trend = t;
        _loadingTrend = false;
      });
    });
    _loadNews();
    LocalStoreService.districtNewsRevision.addListener(_loadNews);
    _loadReviews();
    LocalStoreService.districtReviewsRevision.addListener(_loadReviews);
    _loadCurrentUser();
    LocalStoreService.currentUserRevision.addListener(_loadCurrentUser);
  }

  @override
  void dispose() {
    LocalStoreService.districtNewsRevision.removeListener(_loadNews);
    LocalStoreService.districtReviewsRevision.removeListener(_loadReviews);
    LocalStoreService.currentUserRevision.removeListener(_loadCurrentUser);
    super.dispose();
  }

  Future<void> _loadNews() async {
    final news = await LocalStoreService.instance.getNewsForDistrict(widget.district.state, widget.district.district);
    if (!mounted) return;
    setState(() {
      _news = news;
      _loadingNews = false;
    });
  }

  Future<void> _loadReviews() async {
    final reviews = await LocalStoreService.instance.getReviewsForDistrict(widget.district.state, widget.district.district);
    if (!mounted) return;
    setState(() {
      _reviews = reviews;
      _loadingReviews = false;
    });
  }

  Future<void> _loadCurrentUser() async {
    final user = await LocalStoreService.instance.getCurrentUser();
    if (mounted) setState(() => _currentUser = user);
  }

  double get _averageRating =>
      _reviews.isEmpty ? 0 : _reviews.map((r) => r.rating).reduce((a, b) => a + b) / _reviews.length;

  /// Makes sure someone's signed in (an application needs an applicant
  /// to attach to), then opens the school or business application form
  /// locked to this district. Guest users are sent to log in / register
  /// first; if that's cancelled, nothing opens.
  Future<void> _openApplication({required bool isSchool}) async {
    final account = await LocalStoreService.instance.getCurrentUser();
    if (account == null) {
      final loggedIn = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
      if (loggedIn != true || !mounted) return;
    }
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => isSchool
          ? SchoolApplicationScreen(district: widget.district)
          : BusinessApplicationScreen(district: widget.district),
    ));
  }

  /// Leaving a review needs an identity to attach it to (so its author
  /// can later delete it) - same sign-in-first pattern as applications.
  Future<void> _openWriteReview() async {
    var account = _currentUser;
    if (account == null) {
      final loggedIn = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
      if (loggedIn != true || !mounted) return;
      account = await LocalStoreService.instance.getCurrentUser();
      if (account == null || !mounted) return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _WriteReviewSheet(district: widget.district, author: account!),
    );
  }

  Future<void> _openReportIssue() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ReportIssueSheet(district: widget.district),
    );
  }

  Future<void> _confirmDeleteReview(DistrictReview review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this review?'),
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
      await LocalStoreService.instance.deleteDistrictReview(review.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.district;
    final score = widget.overrideScore ?? d.livabilityScore();

    return Scaffold(
      appBar: AppBar(
        title: Text(d.district),
        actions: [
          IconButton(
            icon: Icon(_isFavorite ? Icons.star : Icons.star_border),
            color: _isFavorite ? AppColors.moderate : null,
            tooltip: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
            onPressed: () async {
              await LocalStoreService.instance.toggleFavorite(_entry);
              setState(() => _isFavorite = !_isFavorite);
            },
          ),
        ],
      ),
      bottomNavigationBar: const GlobalBottomNav(),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          LocationHeaderImage(district: d.district, state: d.state),
          const SizedBox(height: 16),
          ScoreHeader(
            score: score,
            subtitle: d.state,
            trailing: IconButton(
              icon: Icon(Icons.flag_outlined, color: AppColors.brand),
              tooltip: 'Report an issue',
              onPressed: _openReportIssue,
            ),
          ),
          const SizedBox(height: 16),
          WeatherInfoCard(district: d.district, state: d.state),
          const SizedBox(height: 24),

          // --- Apply to study / register a business here -----------------
          HoverLiftCard(
            onTap: () => _openApplication(isSchool: true),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.school_outlined, color: AppColors.brand),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Apply to study here', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
                      Text('Submit a school application for this district',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
          const SizedBox(height: 12),
          HoverLiftCard(
            onTap: () => _openApplication(isSchool: false),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.storefront_outlined, color: AppColors.brand),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Register a business here', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
                      Text('Submit a business registration for this district',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text('Location', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 10),
          LocationMapCard(district: d.district, state: d.state),

          const SizedBox(height: 24),
          const Text('Score breakdown', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 14),
          StatBarRow(
            label: 'Mean income',
            valueText: d.incomeMean != null ? 'RM${d.incomeMean!.round()}/mo' : 'No data',
            fraction: (d.incomeMean ?? 0) / 15000,
            footnote: d.estimatedFields.contains('income')
                ? '${d.district} has no income survey row of its own yet - this is the average of the other districts UrbanEx tracks in ${d.state}.'
                : null,
          ),
          StatBarRow(
            label: 'Median income',
            valueText: d.incomeMedian != null ? 'RM${d.incomeMedian!.round()}/mo' : 'No data',
            fraction: (d.incomeMedian ?? 0) / 15000,
            footnote: d.estimatedFields.contains('income') ? 'Same ${d.state}-average fallback as mean income above.' : null,
          ),
          StatBarRow(
            label: 'Population density',
            valueText: d.populationDensity != null ? '${d.populationDensity!.round()} per km²' : 'No data',
            fraction: (d.populationDensity ?? 0) / 10000,
          ),
          StatBarRow(
            label: 'Schools (primary + secondary)',
            valueText: d.totalSchools != null ? '${d.totalSchools!.round()} schools' : 'No data',
            fraction: (d.totalSchools ?? 0) / 40,
          ),
          StatBarRow(
            label: 'Crime rate (state, per 1,000 residents)',
            valueText: d.stateCrimesPerCapita != null ? d.stateCrimesPerCapita!.toStringAsFixed(1) : 'No data',
            fraction: 1 - ((d.stateCrimesPerCapita ?? 8) / 30).clamp(0, 1),
            footnote: d.estimatedFields.contains('crime')
                ? 'No crime figure for ${d.state} yet - showing the national average across states that do have one, as a rough placeholder.'
                : 'Approximate: state total crimes ÷ population of districts this app tracks, not the true state population.',
          ),
          const SizedBox(height: 10),
          const Text('Trend', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 10),
          _loadingTrend
              ? const SizedBox(height: 110, child: Center(child: CircularProgressIndicator()))
              : TrendSparkline(points: _trend, formatValue: (v) => 'RM${v.round()}'),
          const SizedBox(height: 6),
          Text(
            'Mean household income over recent years (data.gov.my). Schools are a live figure too, from the Ministry of Education.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          const SizedBox(height: 24),

          // --- Latest news for this district ------------------------------
          const Text('Latest news', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 8),
          if (_loadingNews)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_news.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No news yet for this district.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            )
          else
            ..._news.map((n) => _NewsCard(news: n)),

          const SizedBox(height: 24),
          Row(
            children: [
              const Text('Reviews & Ratings', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const Spacer(),
              TextButton.icon(
                onPressed: _openWriteReview,
                icon: const Icon(Icons.rate_review_outlined, size: 18),
                label: const Text('Write a review'),
              ),
            ],
          ),
          if (!_loadingReviews && _reviews.isNotEmpty) ...[
            Row(
              children: [
                StarRating(rating: _averageRating.round()),
                const SizedBox(width: 8),
                Text(
                  '${_averageRating.toStringAsFixed(1)} (${_reviews.length} review${_reviews.length == 1 ? '' : 's'})',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 8),
          if (_loadingReviews)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_reviews.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No reviews yet for this district — be the first to leave one.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            )
          else
            ..._reviews.map((r) => _ReviewCard(
              review: r,
              canDelete: _currentUser != null && (_currentUser!.email == r.authorEmail || _currentUser!.isAdmin),
              onDelete: () => _confirmDeleteReview(r),
            )),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final DistrictReview review;
  final bool canDelete;
  final VoidCallback onDelete;
  const _ReviewCard({required this.review, required this.canDelete, required this.onDelete});

  String get _relativeTime {
    final diff = DateTime.now().difference(review.createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }

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
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.brand.withOpacity(0.15),
                  child: Text(
                    review.authorName.isNotEmpty ? review.authorName[0].toUpperCase() : '?',
                    style: TextStyle(color: AppColors.brandDark, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(review.authorName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Row(
                        children: [
                          StarRating(rating: review.rating, size: 14),
                          const SizedBox(width: 6),
                          Text(_relativeTime, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (canDelete)
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 20, color: AppColors.bad),
                    tooltip: 'Delete review',
                    onPressed: onDelete,
                  ),
              ],
            ),
            if (review.comment.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(review.comment, style: const TextStyle(fontSize: 13, height: 1.4)),
            ],
            if (review.image != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => showDialog(context: context, builder: (_) => _ReviewImageDialog(image: review.image!)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _reviewThumbnail(review.image!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _reviewThumbnail(UploadedDocument image) {
    if (image.base64Data == null) {
      return Container(
        height: 80,
        width: 80,
        color: Colors.grey.shade200,
        child: Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade400),
      );
    }
    try {
      return Image.memory(base64Decode(image.base64Data!), height: 120, width: 120, fit: BoxFit.cover);
    } catch (_) {
      return Container(
        height: 80,
        width: 80,
        color: Colors.grey.shade200,
        child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade400),
      );
    }
  }
}

class _ReviewImageDialog extends StatelessWidget {
  final UploadedDocument image;
  const _ReviewImageDialog({required this.image});

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    try {
      if (image.base64Data != null) bytes = base64Decode(image.base64Data!);
    } catch (_) {
      bytes = null;
    }
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: bytes == null
          ? const Padding(padding: EdgeInsets.all(24), child: Text('Image not available'))
          : InteractiveViewer(maxScale: 4, child: Image.memory(bytes, fit: BoxFit.contain)),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final DistrictNews news;
  const _NewsCard({required this.news});

  String get _relativeTime {
    final diff = DateTime.now().difference(news.postedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }

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
                Icon(Icons.newspaper_outlined, size: 16, color: AppColors.brand),
                const SizedBox(width: 6),
                Expanded(child: Text(news.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5))),
              ],
            ),
            const SizedBox(height: 6),
            Text(news.body, style: const TextStyle(fontSize: 13, height: 1.4)),
            const SizedBox(height: 8),
            Text(_relativeTime, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}



/// Bottom sheet for leaving a 0-5 star review with an optional comment
/// and an optional photo. [author] is the already-signed-in account this
/// review will be attached to (see _openWriteReview, which handles
/// signing in first).
class _WriteReviewSheet extends StatefulWidget {
  final DistrictData district;
  final UserAccount author;
  const _WriteReviewSheet({required this.district, required this.author});

  @override
  State<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<_WriteReviewSheet> {
  int _rating = 0;
  final _commentController = TextEditingController();
  UploadedDocument? _image;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
      if (picked == null || !mounted) return;
      final doc = await uploadedDocumentFromXFile('Review Photo', picked);
      if (!mounted) return;
      setState(() => _image = doc);
    } catch (_) {
      // Best-effort - leave unattached if the picker fails.
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: true, type: FileType.image);
      if (result == null || result.files.isEmpty || !mounted) return;
      setState(() => _image = uploadedDocumentFromPlatformFile('Review Photo', result.files.first));
    } catch (_) {
      // Best-effort - leave unattached if the picker fails.
    }
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final review = DistrictReview(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        state: widget.district.state,
        district: widget.district.district,
        authorEmail: widget.author.email,
        authorName: widget.author.name,
        rating: _rating,
        comment: _commentController.text.trim(),
        image: _image,
        createdAt: DateTime.now(),
      );
      await LocalStoreService.instance.addDistrictReview(review);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for your review!')),
      );
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't submit your review. Please try again.");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Review ${widget.district.district}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 16),
              Center(child: StarRating(rating: _rating, size: 34, onChanged: (r) => setState(() => _rating = r))),
              const SizedBox(height: 16),
              TextField(
                controller: _commentController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Your comment (optional)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              DocumentUploadTile(
                label: 'Add Photo (optional)',
                attachmentName: _image?.fileName,
                onTakePhoto: () => _pickImage(ImageSource.camera),
                onChooseGalleryPhoto: () => _pickImage(ImageSource.gallery),
                onChooseFile: _pickFile,
                onRemoveAttachment: () => setState(() => _image = null),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: AppColors.bad, fontSize: 12.5)),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Review'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for reporting a bug/issue scoped to this district -
/// submission can be anonymous, same as the general Contact & feedback
/// form.
class _ReportIssueSheet extends StatefulWidget {
  final DistrictData district;
  const _ReportIssueSheet({required this.district});

  @override
  State<_ReportIssueSheet> createState() => _ReportIssueSheetState();
}

class _ReportIssueSheetState extends State<_ReportIssueSheet> {
  static const _categories = ['Bug', 'Incorrect data', 'Other'];

  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String _category = _categories.first;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    LocalStoreService.instance.getCurrentUser().then((account) {
      if (account != null && mounted) {
        _nameController.text = account.name;
        _emailController.text = account.email;
      }
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final report = DistrictIssueReport(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        state: widget.district.state,
        district: widget.district.district,
        category: _category,
        description: _descriptionController.text.trim(),
        reporterName: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
        reporterEmail: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        submittedAt: DateTime.now(),
      );
      await LocalStoreService.instance.submitDistrictIssueReport(report);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks — your report has been sent to the team.')),
      );
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't submit your report. Please try again.");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Report an issue in ${widget.district.district}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                const SizedBox(height: 6),
                Text(
                  'This goes straight to the admin team — only they can see it.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _categories.map((c) {
                    return SelectableChip(label: c, selected: _category == c, onTap: () => setState(() => _category = c));
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Describe the issue',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please describe the issue' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Your name (optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Your email (optional, for follow-up)', border: OutlineInputBorder()),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: AppColors.bad, fontSize: 12.5)),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Submit Report'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



