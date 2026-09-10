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

/// Holds the editable state for a single partner row in the Partnership
/// section. Kept as controllers (rather than plain strings) so text
/// entered into a partner's fields survives rebuilds without losing
/// cursor position/focus.
class _PartnerFormEntry {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController idNumberController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  String idType = 'MyKad';

  void dispose() {
    fullNameController.dispose();
    idNumberController.dispose();
    emailController.dispose();
    phoneController.dispose();
  }

  BusinessPartner toPartner() => BusinessPartner(
    fullName: fullNameController.text.trim(),
    idType: idType,
    idNumber: idNumberController.text.trim(),
    email: emailController.text.trim(),
    phone: phoneController.text.trim(),
  );

  bool get isComplete =>
      fullNameController.text.trim().isNotEmpty &&
          idNumberController.text.trim().isNotEmpty &&
          emailController.text.trim().isNotEmpty &&
          phoneController.text.trim().isNotEmpty;
}

/// Registering a business in [district]. Pushed from a district's detail
/// page - the district and state are locked to wherever the person came
/// from. UrbanEx has no real registration backend (no SSM integration or
/// similar), so this just records the submission for an admin to review
/// from the dashboard; it doesn't actually register anything with any
/// authority.
class BusinessApplicationScreen extends StatefulWidget {
  final DistrictData district;
  const BusinessApplicationScreen({super.key, required this.district});

  @override
  State<BusinessApplicationScreen> createState() => _BusinessApplicationScreenState();
}

class _BusinessApplicationScreenState extends State<BusinessApplicationScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- Section 1: Business information ---------------------------------
  final _businessNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _businessType = 'Sole Proprietorship';
  String _businessCategory = _businessCategories.first;

  // --- Section 2: Business address --------------------------------------
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _postcodeController = TextEditingController();
  late String _addressState = widget.district.state;

  // --- Section 3: Owner / applicant information -------------------------
  final _ownerNameController = TextEditingController();
  final _ownerIdNumberController = TextEditingController();
  final _ownerEmailController = TextEditingController();
  final _ownerPhoneController = TextEditingController();
  final _ownerResidentialAddressController = TextEditingController();
  String _ownerIdType = 'MyKad';
  String _ownerNationality = 'Malaysian';

  // --- Section 4: Partnership information --------------------------------
  final List<_PartnerFormEntry> _partners = [_PartnerFormEntry()];

  // --- Section 5: Supporting documents ------------------------------------
  final Map<String, UploadedDocument> _attachments = {};

  // --- Section 6: Business licence / permit -------------------------------
  bool _requiresLicence = false;
  String _licenceType = _licenceTypes.first;
  final _licenceNumberController = TextEditingController();
  UploadedDocument? _licenceDocument;

  // --- Section 7: Declaration ---------------------------------------------
  bool _declareAccurate = false;
  bool _declareTerms = false;
  bool _declareVerification = false;

  bool _submitting = false;
  String? _error;

  static const _businessTypes = [
    'Sole Proprietorship',
    'Partnership',
    'Private Limited Company (Sdn. Bhd.)',
  ];
  static const _businessCategories = [
    'Retail',
    'Food & Beverage',
    'Education',
    'Technology',
    'Healthcare',
    'Services',
    'Construction',
    'Other',
  ];
  static const _idTypes = ['MyKad', 'Passport', 'Other'];
  static const _nationalities = ['Malaysian', 'Permanent Resident', 'Other'];
  static const _licenceTypes = [
    'Food Premise Licence',
    'Signboard Licence',
    'Education/Training Permit',
    'Health-related Licence',
    'Construction Permit',
    'Other',
  ];

  bool get _isPartnership => _businessType == 'Partnership';

  @override
  void initState() {
    super.initState();
    LocalStoreService.instance.getCurrentUser().then((u) {
      if (u != null && mounted) {
        _ownerNameController.text = u.name;
        _ownerEmailController.text = u.email;
      }
    });
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _descriptionController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _postcodeController.dispose();
    _ownerNameController.dispose();
    _ownerIdNumberController.dispose();
    _ownerEmailController.dispose();
    _ownerPhoneController.dispose();
    _ownerResidentialAddressController.dispose();
    _licenceNumberController.dispose();
    for (final p in _partners) {
      p.dispose();
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

  List<String> get _requiredDocumentLabels => const [
    'Identification Document',
    'Proof of Business Address',
  ];

  List<String> get _additionalDocumentLabels => [
    'Business Permit / Licence',
    if (_isPartnership) 'Partnership Agreement',
    'Other Supporting Document',
  ];

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

  // --- Partnership section actions ----------------------------------------

  void _addPartner() => setState(() => _partners.add(_PartnerFormEntry()));

  void _removePartner(int index) {
    setState(() {
      _partners[index].dispose();
      _partners.removeAt(index);
    });
  }

  // --- Submit ----------------------------------------------------------------

  bool get _declarationsComplete => _declareAccurate && _declareTerms && _declareVerification;

  Future<void> _submit() async {
    // Demo build: fields still show a "Required" hint if left blank (see
    // the validators below), but nothing here actually blocks submission
    // on missing info - not the form fields, not the required documents,
    // not incomplete partner rows, and not the declaration checkboxes.
    _formKey.currentState!.validate();

    final documentsWithAttachments = [..._requiredDocumentLabels, ..._additionalDocumentLabels]
        .where((doc) => _attachments.containsKey(doc))
        .map((doc) => _attachments[doc]!)
        .toList();

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await ApplicationService.instance.submit(
        category: 'business',
        name: _businessNameController.text,
        subtype: _businessCategory,
        state: widget.district.state,
        district: widget.district.district,
        contact: '${_ownerEmailController.text.trim()} / ${_ownerPhoneController.text.trim()}',
        description: _descriptionController.text,
        documents: documentsWithAttachments,
        businessType: _businessType,
        addressLine1: _addressLine1Controller.text.trim(),
        addressLine2: _addressLine2Controller.text.trim().isEmpty ? null : _addressLine2Controller.text.trim(),
        addressCity: _cityController.text.trim(),
        addressState: _addressState,
        addressPostcode: _postcodeController.text.trim(),
        ownerIdType: _ownerIdType,
        ownerIdNumber: _ownerIdNumberController.text.trim(),
        ownerEmail: _ownerEmailController.text.trim(),
        ownerPhone: _ownerPhoneController.text.trim(),
        ownerResidentialAddress: _ownerResidentialAddressController.text.trim(),
        ownerNationality: _ownerNationality,
        partners: _isPartnership ? _partners.map((p) => p.toPartner()).toList() : const [],
        requiresLicence: _requiresLicence,
        licenceType: _requiresLicence ? _licenceType : null,
        licenceNumber: _requiresLicence ? _licenceNumberController.text.trim() : null,
        licenceDocument: _requiresLicence ? _licenceDocument : null,
        declarationInfoAccurate: _declareAccurate,
        declarationAgreeTerms: _declareTerms,
        declarationUnderstandVerification: _declareVerification,
      );

      if (!mounted) return;

      if (result.success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration submitted — track your status from your profile.')),
        );
      } else {
        setState(() => _error = result.error);
      }
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't submit your registration. Please try again.");
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

  @override
  Widget build(BuildContext context) {
    final d = widget.district;
    return Scaffold(
      appBar: AppBar(title: const Text('Register a business here')),
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

              // === 1. Business Information ==================================
              _sectionHeader('1. Business Information'),
              TextFormField(
                controller: _businessNameController,
                decoration: const InputDecoration(labelText: 'Business Name', prefixIcon: Icon(Icons.storefront_outlined)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 18),
              _dropdownField(
                label: 'Business Type',
                icon: Icons.account_balance_outlined,
                value: _businessType,
                options: _businessTypes,
                onChanged: (v) => setState(() => _businessType = v),
              ),
              const SizedBox(height: 20),
              _subHeader('Business Category'),
              _chipGroup(
                options: _businessCategories,
                value: _businessCategory,
                onChanged: (v) => setState(() => _businessCategory = v),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Business Description',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),

              // === 2. Business Address =======================================
              _sectionHeader('2. Business Address'),
              TextFormField(
                controller: _addressLine1Controller,
                decoration: const InputDecoration(labelText: 'Address Line 1', prefixIcon: Icon(Icons.home_outlined)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),

              // === 3. Owner / Applicant Information ==========================
              _sectionHeader('3. Owner / Applicant Information'),
              TextFormField(
                controller: _ownerNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.badge_outlined)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 18),
              _dropdownField(
                label: 'Identification Type',
                icon: Icons.badge_outlined,
                value: _ownerIdType,
                options: _idTypes,
                onChanged: (v) => setState(() => _ownerIdType = v),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _ownerIdNumberController,
                decoration: const InputDecoration(labelText: 'Identification Number', prefixIcon: Icon(Icons.pin_outlined)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _ownerEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _ownerPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.call_outlined)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _ownerResidentialAddressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Residential Address',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.house_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              _subHeader('Nationality'),
              _chipGroup(
                options: _nationalities,
                value: _ownerNationality,
                onChanged: (v) => setState(() => _ownerNationality = v),
              ),

              // === 4. Partnership Information (conditional) ==================
              if (_isPartnership) ...[
                _sectionHeader('4. Partnership Information'),
                Text(
                  'Add every partner involved in this business.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                ),
                const SizedBox(height: 14),
                ..._partners.asMap().entries.map((entry) {
                  final index = entry.key;
                  final partner = entry.value;
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
                                child: Text('Partner ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                              ),
                              if (_partners.length > 1)
                                IconButton(
                                  icon: Icon(Icons.close, size: 18, color: AppColors.bad),
                                  onPressed: () => _removePartner(index),
                                  tooltip: 'Remove partner',
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: partner.fullNameController,
                            decoration: const InputDecoration(labelText: 'Full Name'),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: partner.idType,
                            decoration: const InputDecoration(labelText: 'Identification Type'),
                            isExpanded: true,
                            items: _idTypes.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                            onChanged: (v) => setState(() => partner.idType = v ?? partner.idType),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: partner.idNumberController,
                            decoration: const InputDecoration(labelText: 'Identification No.'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: partner.emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(labelText: 'Email'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: partner.phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(labelText: 'Phone'),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                OutlinedButton.icon(
                  onPressed: _addPartner,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Another Partner'),
                ),
              ],

              // === 5. Supporting Documents ====================================
              _sectionHeader('5. Supporting Documents'),
              _subHeader('Required Documents'),
              ..._requiredDocumentLabels.map(_documentTile),
              const SizedBox(height: 6),
              _subHeader('Additional Documents (if applicable)'),
              ..._additionalDocumentLabels.map(_documentTile),

              // === 6. Business Licence / Permit ===============================
              _sectionHeader('6. Business Licence / Permit'),
              Text(
                'Does your business require a special licence or permit?',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Yes'),
                      value: true,
                      groupValue: _requiresLicence,
                      onChanged: (v) => setState(() => _requiresLicence = v ?? _requiresLicence),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('No'),
                      value: false,
                      groupValue: _requiresLicence,
                      onChanged: (v) => setState(() => _requiresLicence = v ?? _requiresLicence),
                    ),
                  ),
                ],
              ),
              if (_requiresLicence) ...[
                const SizedBox(height: 10),
                _subHeader('Licence Type'),
                _chipGroup(
                  options: _licenceTypes,
                  value: _licenceType,
                  onChanged: (v) => setState(() => _licenceType = v),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _licenceNumberController,
                  decoration: const InputDecoration(labelText: 'Licence Number', prefixIcon: Icon(Icons.confirmation_number_outlined)),
                ),
                const SizedBox(height: 14),
                DocumentUploadTile(
                  label: 'Upload Licence',
                  attachmentName: _licenceDocument?.fileName,
                  onTakePhoto: () => _pickImage((doc) => _licenceDocument = doc, 'Upload Licence', ImageSource.camera),
                  onChooseGalleryPhoto: () => _pickImage((doc) => _licenceDocument = doc, 'Upload Licence', ImageSource.gallery),
                  onChooseFile: () => _pickFile((doc) => _licenceDocument = doc, 'Upload Licence'),
                  onRemoveAttachment: () => setState(() => _licenceDocument = null),
                ),
              ],

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
                value: _declareTerms,
                onChanged: (v) => setState(() => _declareTerms = v ?? false),
                title: const Text('I agree to the Terms and Conditions.'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _declareVerification,
                onChanged: (v) => setState(() => _declareVerification = v ?? false),
                title: const Text('I understand that additional documents may be requested during the verification process.'),
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
                    : const Text('Submit Registration'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}





