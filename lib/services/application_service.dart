import '../models.dart';
import 'auth_service.dart';
import 'local_store_service.dart';

/// Handles submitting a school-application or business-registration
/// request tied to a district, and the admin actions that review it.
/// Everything here is local-only, like the rest of UrbanEx's account
/// system - there's no backend to actually place a student in a school
/// or register a business; this just records the submission and its
/// status so it can be tracked.
class ApplicationService {
  ApplicationService._();
  static final ApplicationService instance = ApplicationService._();

  int _idCounter = 0;

  /// A unique-enough id for a single device's local storage: current
  /// timestamp plus a monotonic counter, so two applications submitted
  /// in the same microsecond still get distinct ids. Deliberately avoids
  /// Random/bitwise tricks, which behave inconsistently across compiled
  /// targets (web vs native) for values this large.
  String _generateId() {
    _idCounter++;
    return '${DateTime.now().microsecondsSinceEpoch}-$_idCounter';
  }

  /// Submits a new application on behalf of the currently signed-in
  /// user. Fails if nobody is signed in - callers should send the person
  /// through AuthScreen first (see the "Apply to study here" / "Register
  /// a business here" cards on a district's detail page). Never throws -
  /// any unexpected error comes back as a failed [AuthResult] instead, so
  /// the caller's UI can always recover cleanly.
  ///
  /// The extended parameters (businessType through
  /// declarationUnderstandVerification) are only ever populated by the
  /// business-registration form - the school-application form leaves
  /// them at their defaults.
  Future<AuthResult> submit({
    required String category, // 'school' or 'business'
    required String name,
    required String subtype,
    required String state,
    String? district,
    required String contact,
    required String description,
    String? matchedOption,
    List<UploadedDocument> documents = const [],
    String? businessType,
    String? addressLine1,
    String? addressLine2,
    String? addressCity,
    String? addressState,
    String? addressPostcode,
    String? ownerIdType,
    String? ownerIdNumber,
    String? ownerEmail,
    String? ownerPhone,
    String? ownerResidentialAddress,
    String? ownerNationality,
    List<BusinessPartner> partners = const [],
    bool requiresLicence = false,
    String? licenceType,
    String? licenceNumber,
    UploadedDocument? licenceDocument,
    bool declarationInfoAccurate = false,
    bool declarationAgreeTerms = false,
    bool declarationUnderstandVerification = false,
    String? studentDob,
    String? studentGender,
    String? studentNationality,
    String? studentIdType,
    String? studentIdNumber,
    String? studentEmail,
    String? studentPhone,
    String? schoolType,
    List<Guardian> guardians = const [],
    String? studentAddressLine1,
    String? studentAddressLine2,
    String? studentAddressCity,
    String? studentAddressState,
    String? studentAddressPostcode,
    String? previousSchool,
    String? previousLevel,
    String? previousAchievements,
    UploadedDocument? academicResultsDocument,
    bool declarationAuthorizedToSubmit = false,
  }) async {
    try {
      final user = await LocalStoreService.instance.getCurrentUser();
      if (user == null) {
        return const AuthResult.fail('Please log in first to submit an application.');
      }
      // Note: this is a demo build, so fields that look "required" in the
      // form (name, contact, etc.) aren't actually enforced here - an
      // application can be submitted even if they're left blank.

      final application = ListingApplication(
        id: _generateId(),
        category: category,
        name: name.trim(),
        subtype: subtype,
        state: state,
        district: (district == null || district.trim().isEmpty) ? null : district.trim(),
        contact: contact.trim(),
        description: description.trim(),
        applicantEmail: user.email,
        applicantName: user.name,
        submittedAt: DateTime.now(),
        matchedOption: matchedOption,
        documents: documents,
        businessType: businessType,
        addressLine1: addressLine1,
        addressLine2: addressLine2,
        addressCity: addressCity,
        addressState: addressState,
        addressPostcode: addressPostcode,
        ownerIdType: ownerIdType,
        ownerIdNumber: ownerIdNumber,
        ownerEmail: ownerEmail,
        ownerPhone: ownerPhone,
        ownerResidentialAddress: ownerResidentialAddress,
        ownerNationality: ownerNationality,
        partners: partners,
        requiresLicence: requiresLicence,
        licenceType: licenceType,
        licenceNumber: licenceNumber,
        licenceDocument: licenceDocument,
        declarationInfoAccurate: declarationInfoAccurate,
        declarationAgreeTerms: declarationAgreeTerms,
        declarationUnderstandVerification: declarationUnderstandVerification,
        studentDob: studentDob,
        studentGender: studentGender,
        studentNationality: studentNationality,
        studentIdType: studentIdType,
        studentIdNumber: studentIdNumber,
        studentEmail: studentEmail,
        studentPhone: studentPhone,
        schoolType: schoolType,
        guardians: guardians,
        studentAddressLine1: studentAddressLine1,
        studentAddressLine2: studentAddressLine2,
        studentAddressCity: studentAddressCity,
        studentAddressState: studentAddressState,
        studentAddressPostcode: studentAddressPostcode,
        previousSchool: previousSchool,
        previousLevel: previousLevel,
        previousAchievements: previousAchievements,
        academicResultsDocument: academicResultsDocument,
        declarationAuthorizedToSubmit: declarationAuthorizedToSubmit,
      );

      await LocalStoreService.instance.saveApplication(application);
      return const AuthResult.ok();
    } catch (_) {
      return const AuthResult.fail("Something went wrong submitting your application. Please try again.");
    }
  }

  Future<List<ListingApplication>> getAll() async {
    final apps = await LocalStoreService.instance.getApplications();
    apps.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return apps;
  }

  /// Applications submitted by [email], newest first - used by Profile's
  /// "My submissions" so anyone can track the status of what they sent
  /// in, without needing admin rights.
  Future<List<ListingApplication>> getMine(String email) async {
    final apps = await getAll();
    return apps.where((a) => a.applicantEmail == email).toList();
  }

  /// Sets [id]'s status to [status] ('pending' | 'approved' | 'rejected'),
  /// with an optional review note. Admin-only - re-checked here even
  /// though the admin dashboard is the only place that calls this.
  Future<AuthResult> setStatus(String id, String status, {String? note}) async {
    try {
      if (!await AuthService.instance.currentUserIsAdmin()) {
        return const AuthResult.fail('Only an admin can do that.');
      }
      final apps = await LocalStoreService.instance.getApplications();
      final match = apps.where((a) => a.id == id).toList();
      if (match.isEmpty) {
        return const AuthResult.fail('That application no longer exists.');
      }
      final updated = match.first.copyWith(
        status: status,
        reviewNote: note,
        reviewedAt: DateTime.now(),
      );
      await LocalStoreService.instance.saveApplication(updated);

      // Only a real decision is worth notifying about - resetting back
      // to pending isn't an outcome, so it stays quiet.
      if (status == 'approved' || status == 'rejected') {
        final label = updated.category == 'school' ? 'school application' : 'business registration';
        await LocalStoreService.instance.addNotification(NotificationEntry(
          id: '${DateTime.now().microsecondsSinceEpoch}-app',
          type: 'application_status',
          applicationStatus: status,
          title: status == 'approved' ? 'Application approved' : 'Application rejected',
          body: status == 'approved'
              ? 'Your $label for ${updated.name} in ${updated.district ?? updated.state} was approved.'
              : 'Your $label for ${updated.name} in ${updated.district ?? updated.state} was rejected.'
              '${note != null && note.trim().isNotEmpty ? ' Note: ${note.trim()}' : ''}',
          createdAt: DateTime.now(),
          recipientEmail: updated.applicantEmail,
          relatedApplicationId: updated.id,
        ));
      }

      return const AuthResult.ok();
    } catch (_) {
      return const AuthResult.fail('Something went wrong updating that application. Please try again.');
    }
  }

  Future<AuthResult> approve(String id, {String? note}) => setStatus(id, 'approved', note: note);
  Future<AuthResult> reject(String id, {String? note}) => setStatus(id, 'rejected', note: note);
  Future<AuthResult> resetToPending(String id) => setStatus(id, 'pending');
}





