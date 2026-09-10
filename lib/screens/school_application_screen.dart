import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models.dart';
import '../services/application_service.dart';
import '../services/local_store_service.dart';
import '../services/upload_utils.dart';
import '../static_geo_data.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/document_upload_tile.dart';

/// Holds the editable state for a single parent/guardian row in the
/// Parent / Guardian Information section. Kept as controllers (rather
/// than plain strings) so text entered into a guardian's fields survives
/// rebuilds without losing cursor position/focus - mirrors
/// [_PartnerFormEntry] in the business-registration form.
class _GuardianFormEntry {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController occupationController = TextEditingController();
  String relationship = 'Father';

  void dispose() {
    fullNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    occupationController.dispose();
  }

  Guardian toGuardian() => Guardian(
    fullName: fullNameController.text.trim(),
    relationship: relationship,
    phone: phoneController.text.trim(),
    email: emailController.text.trim(),
    occupation: occupationController.text.trim(),
  );
}

/// A student applying to study in [district]. Pushed from a district's
/// detail page - the district and state are locked to wherever the
/// person came from, since this is "apply to study *here*", not a
/// general school search.
///
/// UrbanEx doesn't have a directory of individual named schools (only
/// real per-district school *counts* from the Ministry of Education),
/// so there's no real institution to place someone into. Instead, once
/// submitted, the app matches the application to an education track
/// using that real count, and an admin gives the final confirmation from
/// the dashboard.
class SchoolApplicationScreen extends StatefulWidget {
  final DistrictData district;
  const SchoolApplicationScreen({super.key, required this.district});

  @override
  State<SchoolApplicationScreen> createState() => _SchoolApplicationScreenState();
}

class _SchoolApplicationScreenState extends State<SchoolApplicationScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- Section 1: Student Information ------------------------------------
  final _fullNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _studentEmailController = TextEditingController();
  final _studentPhoneController = TextEditingController();
  String _gender = _genders.first;
  String _nationality = 'Malaysian';
  String _idType = 'MyKad';
  DateTime? _dob;

  // --- Section 2: School Information --------------------------------------
  String _schoolType = _schoolTypes.first;
  late String _levelApplyingFor = _levelsFor(_schoolTypes.first).first;

  // --- Section 3: Parent / Guardian Information ---------------------------
  final List<_GuardianFormEntry> _guardians = [_GuardianFormEntry()];

  // --- Section 4: Address Information -------------------------------------
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _postcodeController = TextEditingController();
  late String _addressState = widget.district.state;

  // --- Section 5: Academic Information ------------------------------------
  final _previousSchoolController = TextEditingController();
  final _achievementsController = TextEditingController();
  String _previousLevel = _previousLevels.first;
  UploadedDocument? _academicResultsDocument;

  // --- Section 6: Supporting Documents -------------------------------------
  final Map<String, UploadedDocument> _attachments = {};

  // --- Section 7: Declaration ----------------------------------------------
  bool _declareAccurate = false;
  bool _declareAuthorized = false;
  bool _declareTerms = false;

  bool _submitting = false;
  String? _error;

  static const _genders = ['Male', 'Female', 'Other'];
  static const _nationalities = ['Malaysian', 'Permanent Resident', 'Other'];
  static const _idTypes = ['MyKad', 'Birth Certificate', 'Passport', 'Other'];
  static const _relationships = ['Father', 'Mother', 'Guardian', 'Other'];
  static const _previousLevels = ['Kindergarten', 'Primary', 'Secondary', 'Pre-University', 'Other'];

  static const _schoolTypes = [
    'Primary School',
    'Secondary School',
    'International School',
    'Private School',
    'Vocational School',
  ];

  /// The "Level Applying For" options change depending on the selected
  /// [schoolType] - e.g. Primary School shows Year 1-6, Secondary School
  /// shows Form 1-5.
  static List<String> _levelsFor(String schoolType) {
    switch (schoolType) {
      case 'Primary School':
        return List.generate(6, (i) => 'Year ${i + 1}');
      case 'Secondary School':
        return List.generate(5, (i) => 'Form ${i + 1}');
      case 'International School':
        return List.generate(12, (i) => 'Grade ${i + 1}');
      case 'Private School':
        return List.generate(13, (i) => 'Year ${i + 1}');
      case 'Vocational School':
        return const ['Certificate Level 1', 'Certificate Level 2', 'Certificate Level 3', 'Diploma', 'Advanced Diploma'];
      default:
        return const ['Other'];
    }
  }

  // Required documents shown as tap-to-upload fields. Purely
  // informational, like the business-registration form - UrbanEx doesn't
  // require an actual upload to submit.
  static const _requiredDocumentLabels = [
    "Birth Certificate",
    'Previous School Report',
    'Proof of Address',
  ];
  static const _optionalDocumentLabels = [
    'Academic Certificates',
    'Co-curricular Certificates',
    'Sports Certificates',
    'Other Supporting Documents',
  ];

  String _stageFor(String schoolType) {
    switch (schoolType) {
      case 'Primary School':
        return 'primary';
      case 'Secondary School':
        return 'secondary';
      default:
        return 'tertiary';
    }
  }

  double? _countFor(String stage) {
    switch (stage) {
      case 'primary':
        return widget.district.primarySchools;
      case 'secondary':
        return widget.district.secondarySchools;
      default:
        return widget.district.tertiarySchools;
    }
  }

  @override
  void initState() {
    super.initState();
    LocalStoreService.instance.getCurrentUser().then((u) {
      if (u != null && mounted) {
        _fullNameController.text = u.name;
        _studentEmailController.text = u.email;
      }
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _dobController.dispose();
    _idNumberController.dispose();
    _studentEmailController.dispose();
    _studentPhoneController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _postcodeController.dispose();
    _previousSchoolController.dispose();
    _achievementsController.dispose();
    for (final g in _guardians) {
      g.dispose();
    }
    super.dispose();
  }

  // --- Document picking (shared by every DocumentUploadTile below) -------

  Future<void> _pickImage(void Function(UploadedDocument) onPicked, String label, ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
      if (picked == null || !mounted) return;
      final doc = await uploadedDocumentFromXFile(label, picked);
      if (!mounted) return;
      setState(() => onPicked(doc));
    } catch (_) {
      // Attaching is optional/best-effort - if the picker fails or isn't
      // available on this device, just leave it unattached rather than
      // interrupting the rest of the form.
    }
  }

  Future<void> _pickFile(void Function(UploadedDocument) onPicked, String label) async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty || !mounted) return;
      final doc = uploadedDocumentFromPlatformFile(label, result.files.first);
      setState(() => onPicked(doc));
    } catch (_) {
      // Same as above - fail quietly.
    }
  }

  Widget _documentTile(String label) {
    return DocumentUploadTile(
      label: label,
      attachmentName: _attachments[label]?.fileName,
      onTakePhoto: () => _pickImage((doc) => _attachments[label] = doc, label, ImageSource.camera),
      onChooseGalleryPhoto: () => _pickImage((doc) => _attachments[label] = doc, label, ImageSource.gallery),
      onChooseFile: () => _pickFile((doc) => _attachments[label] = doc, label),
      onRemoveAttachment: () => setState(() => _attachments.remove(label)),
    );
  }

  // --- Guardian section actions -------------------------------------------

  void _addGuardian() => setState(() => _guardians.add(_GuardianFormEntry()));

  void _removeGuardian(int index) {
    setState(() {
      _guardians[index].dispose();
      _guardians.removeAt(index);
    });
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 10),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _dob = picked;
      _dobController.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    });
  }

  // --- Submit ----------------------------------------------------------------

  Future<void> _submit() async {
    // Demo build: fields still show a "Required" hint if left blank (see
    // the validators below), but nothing here actually blocks submission
    // on missing info - not the form fields, not the required documents,
    // and not the declaration checkboxes.
    _formKey.currentState!.validate();

    final documentsWithAttachments = [..._requiredDocumentLabels, ..._optionalDocumentLabels]
        .where((doc) => _attachments.containsKey(doc))
        .map((doc) => _attachments[doc]!)
        .toList();

    final stage = _stageFor(_schoolType);
    final count = _countFor(stage);
    final matchedOption = count != null && count > 0
        ? '$_schoolType — $_levelApplyingFor — matched using $count recorded ${stage} school${count == 1 ? '' : 's'} '
        'in ${widget.district.district}, ${widget.district.state}.'
        : '$_schoolType — $_levelApplyingFor — no school-count data recorded for this district; '
        'an admin will confirm placement manually.';

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await ApplicationService.instance.submit(
        category: 'school',
        name: _fullNameController.text,
        subtype: _levelApplyingFor,
        state: widget.district.state,
        district: widget.district.district,
        contact: '${_studentEmailController.text.trim()} / ${_studentPhoneController.text.trim()}',
        description: _achievementsController.text,
        matchedOption: matchedOption,
        documents: documentsWithAttachments,
        studentDob: _dobController.text.trim(),
        studentGender: _gender,
        studentNationality: _nationality,
        studentIdType: _idType,
        studentIdNumber: _idNumberController.text.trim(),
        studentEmail: _studentEmailController.text.trim(),
        studentPhone: _studentPhoneController.text.trim(),
        schoolType: _schoolType,
        guardians: _guardians.map((g) => g.toGuardian()).toList(),
        studentAddressLine1: _addressLine1Controller.text.trim(),
        studentAddressLine2: _addressLine2Controller.text.trim().isEmpty ? null : _addressLine2Controller.text.trim(),
        studentAddressCity: _cityController.text.trim(),
        studentAddressState: _addressState,
        studentAddressPostcode: _postcodeController.text.trim(),
        previousSchool: _previousSchoolController.text.trim(),
        previousLevel: _previousLevel,
        previousAchievements: _achievementsController.text.trim(),
        academicResultsDocument: _academicResultsDocument,
        declarationInfoAccurate: _declareAccurate,
        declarationAgreeTerms: _declareTerms,
        declarationAuthorizedToSubmit: _declareAuthorized,
      );

      if (!mounted) return;

      if (result.success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application submitted — track your status from your profile.')),
        );
      } else {
        setState(() => _error = result.error);
      }
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't submit your application. Please try again.");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // --- Small shared builders ---------------------------------------------

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12, top: 8),
    child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
  );

  Widget _subHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
  );

  Widget _chipGroup({
    required List<String> options,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((o) {
        return SelectableChip(label: o, selected: value == o, onTap: () => onChanged(o));
      }).toList(),
    );
  }

  Widget _dropdownField({
    required String label,
    required IconData icon,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      isExpanded: true,
      items: options
          .map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  String? _requiredValidator(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final d = widget.district;
    final levelOptions = _levelsFor(_schoolType);
    return Scaffold(
      appBar: AppBar(title: const Text('Apply to study here')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.brand.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined, color: AppColors.brand, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('${d.district}, ${d.state}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),

              // === 1. Student Information ====================================
              _sectionHeader('1. Student Information'),
              TextFormField(
                controller: _fullNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.badge_outlined)),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _dobController,
                readOnly: true,
                onTap: _pickDob,
                decoration: const InputDecoration(labelText: 'Date of Birth', prefixIcon: Icon(Icons.cake_outlined)),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 20),
              _subHeader('Gender'),
              _chipGroup(options: _genders, value: _gender, onChanged: (v) => setState(() => _gender = v)),
              const SizedBox(height: 20),
              _subHeader('Nationality'),
              _chipGroup(options: _nationalities, value: _nationality, onChanged: (v) => setState(() => _nationality = v)),
              const SizedBox(height: 18),
              _dropdownField(
                label: 'Identification Type',
                icon: Icons.badge_outlined,
                value: _idType,
                options: _idTypes,
                onChanged: (v) => setState(() => _idType = v),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _idNumberController,
                decoration: const InputDecoration(labelText: 'Identification Number', prefixIcon: Icon(Icons.pin_outlined)),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _studentEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Student Email', prefixIcon: Icon(Icons.email_outlined)),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _studentPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Student Phone Number', prefixIcon: Icon(Icons.call_outlined)),
                validator: _requiredValidator,
              ),

              // === 2. School Information ======================================
              _sectionHeader('2. School Information'),
              _subHeader('School Type'),
              _chipGroup(
                options: _schoolTypes,
                value: _schoolType,
                onChanged: (v) => setState(() {
                  _schoolType = v;
                  // Level options depend on school type - reset to the
                  // first valid option whenever the type changes so the
                  // dropdown never shows a stale, mismatched value.
                  _levelApplyingFor = _levelsFor(v).first;
                }),
              ),
              const SizedBox(height: 18),
              _dropdownField(
                label: 'Level Applying For',
                icon: Icons.layers_outlined,
                value: _levelApplyingFor,
                options: levelOptions,
                onChanged: (v) => setState(() => _levelApplyingFor = v),
              ),

              // === 3. Parent / Guardian Information ===========================
              _sectionHeader('3. Parent / Guardian Information'),
              ..._guardians.asMap().entries.map((entry) {
                final index = entry.key;
                final guardian = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('Parent / Guardian ${index + 1}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                            ),
                            if (_guardians.length > 1)
                              IconButton(
                                icon: Icon(Icons.close, size: 18, color: AppColors.bad),
                                onPressed: () => _removeGuardian(index),
                                tooltip: 'Remove parent/guardian',
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: guardian.fullNameController,
                          decoration: const InputDecoration(labelText: 'Full Name'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: guardian.relationship,
                          decoration: const InputDecoration(labelText: 'Relationship'),
                          isExpanded: true,
                          items: _relationships.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                          onChanged: (v) => setState(() => guardian.relationship = v ?? guardian.relationship),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: guardian.phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Phone Number'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: guardian.emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Email Address'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: guardian.occupationController,
                          decoration: const InputDecoration(labelText: 'Occupation'),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              OutlinedButton.icon(
                onPressed: _addGuardian,
                icon: const Icon(Icons.add),
                label: const Text('Add Another Parent/Guardian'),
              ),

              // === 4. Address Information ======================================
              _sectionHeader('4. Address Information'),
              _subHeader('Student Residential Address'),
              TextFormField(
                controller: _addressLine1Controller,
                decoration: const InputDecoration(labelText: 'Address Line 1', prefixIcon: Icon(Icons.home_outlined)),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _addressLine2Controller,
                decoration: const InputDecoration(labelText: 'Address Line 2 (optional)', prefixIcon: Icon(Icons.home_outlined)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'City', prefixIcon: Icon(Icons.location_city_outlined)),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 14),
              _dropdownField(
                label: 'State',
                icon: Icons.map_outlined,
                value: _addressState,
                options: kAllStates,
                onChanged: (v) => setState(() => _addressState = v),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _postcodeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Postcode', prefixIcon: Icon(Icons.local_post_office_outlined)),
                validator: _requiredValidator,
              ),

              // === 5. Academic Information ======================================
              _sectionHeader('5. Academic Information'),
              TextFormField(
                controller: _previousSchoolController,
                decoration: const InputDecoration(labelText: 'Previous School', prefixIcon: Icon(Icons.school_outlined)),
              ),
              const SizedBox(height: 14),
              _dropdownField(
                label: 'Previous Year / Level',
                icon: Icons.layers_outlined,
                value: _previousLevel,
                options: _previousLevels,
                onChanged: (v) => setState(() => _previousLevel = v),
              ),
              const SizedBox(height: 14),
              DocumentUploadTile(
                label: 'Academic Results',
                attachmentName: _academicResultsDocument?.fileName,
                onTakePhoto: () => _pickImage((doc) => _academicResultsDocument = doc, 'Academic Results', ImageSource.camera),
                onChooseGalleryPhoto: () => _pickImage((doc) => _academicResultsDocument = doc, 'Academic Results', ImageSource.gallery),
                onChooseFile: () => _pickFile((doc) => _academicResultsDocument = doc, 'Academic Results'),
                onRemoveAttachment: () => setState(() => _academicResultsDocument = null),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _achievementsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Previous Achievements',
                  hintText: 'Enter academic, sports or other achievements',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.emoji_events_outlined),
                ),
              ),

              // === 6. Supporting Documents ========================================
              _sectionHeader('6. Supporting Documents'),
              _subHeader('Required Documents'),
              ..._requiredDocumentLabels.map(_documentTile),
              const SizedBox(height: 6),
              _subHeader('Optional Documents'),
              ..._optionalDocumentLabels.map(_documentTile),

              // === 7. Declaration ================================================
              _sectionHeader('7. Declaration'),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _declareAccurate,
                onChanged: (v) => setState(() => _declareAccurate = v ?? false),
                title: const Text('I confirm that the information provided is true and accurate.'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _declareAuthorized,
                onChanged: (v) => setState(() => _declareAuthorized = v ?? false),
                title: const Text('I confirm that I am authorized to submit this application.'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _declareTerms,
                onChanged: (v) => setState(() => _declareTerms = v ?? false),
                title: const Text("I agree to the school's terms and conditions."),
              ),

              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.bad.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.bad, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: TextStyle(color: AppColors.bad, fontSize: 12.5))),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Application'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}



