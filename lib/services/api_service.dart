import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Central HTTP client for the One Blood Connect REST API.
class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  // Reduce timeout so failures are detected quickly instead of hanging for 15s
  static const Duration _timeout = Duration(seconds: 5);

  // ─── Auth header ────────────────────────────────────────────────────────────

  /// Returns the Authorization header map with a fresh Firebase ID token.
  /// Throws [Exception] if there is no signed-in user.
  Future<Map<String, String>> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No authenticated user');

    // forceRefresh: false — uses cached token unless it has expired
    final token = await user.getIdToken(false);
    return {
      HttpHeaders.contentTypeHeader: 'application/json',
      HttpHeaders.authorizationHeader: 'Bearer $token',
    };
  }

  // ─── Response handling ───────────────────────────────────────────────────────

  /// Throws a descriptive [Exception] for non-2xx responses.
  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    final msg = body['error'] ?? 'HTTP ${response.statusCode}';
    throw Exception(msg);
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // DONOR ENDPOINTS
  // ══════════════════════════════════════════════════════════════════════════════

  /// GET /donors/me
  ///
  /// Returns the current user's donor document.
  /// Returns `{'registered': false}` when the user has never registered.
  Future<Map<String, dynamic>> getMyDonorProfile() async {
    final headers  = await _authHeaders();
    final response = await http
        .get(Uri.parse('$baseUrl/donors/me'), headers: headers)
        .timeout(_timeout);
    return _handleResponse(response);
  }

  /// POST /donors/register
  ///
  /// Creates or replaces the donor profile after the user completes the
  /// DonateBloodPage registration flow.
  Future<Map<String, dynamic>> registerDonor({
    required String bloodGroup,
    required String donationStream,
    required Map<dynamic, bool> preScreeningAnswers,
    required bool readyAnyTime,
    required bool showToOthers,
    DateTime? lastDonationDate,
    int? lastDonationUnits,
    String phone = '',
    String profilePhotoUrl = '',
    DateTime? dateOfBirth,
    String gender = '',
    String city = '',
    String state = '',
    String pincode = '',
    String preferredVenue = '',
    String lastDonationType = '',
    String lastDonationHospital = '',
    Map<String, dynamic> healthEligibility = const {},
    bool emergencyAvailable = false,
    bool consentAccepted = false,
  }) async {
    final headers = await _authHeaders();
    final user    = FirebaseAuth.instance.currentUser!;

    final body = <String, dynamic>{
      'fullName':           user.displayName ?? 'Donor',
      'email':              user.email       ?? '',
      'bloodGroup':         bloodGroup,
      'donationStream':     donationStream,
      'preScreeningAnswers': preScreeningAnswers
          .map((k, v) => MapEntry(k.toString(), v)),
      'readyAnyTime':       readyAnyTime,
      'showToOthers':       showToOthers,
      'phone':              phone,
      'profilePhotoUrl':    profilePhotoUrl,
      'gender':             gender,
      'city':               city,
      'state':              state,
      'pincode':            pincode,
      'preferredVenue':     preferredVenue,
      'lastDonationType':   lastDonationType,
      'lastDonationHospital': lastDonationHospital,
      'healthEligibility': healthEligibility,
      'emergencyAvailable': emergencyAvailable,
      'consentAccepted':    consentAccepted,
      if (dateOfBirth != null) 'dateOfBirth': dateOfBirth.toIso8601String(),
      if (lastDonationDate  != null) 'lastDonationDate':  lastDonationDate.toIso8601String(),
      if (lastDonationUnits != null) 'lastDonationUnits': lastDonationUnits,
    };

    final response = await http
        .post(
          Uri.parse('$baseUrl/donors/register'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    return _handleResponse(response);
  }

  /// PATCH /donors/me
  ///
  /// Partial update for donor fields (venue, ready-any-time, blood group, etc.).
  Future<Map<String, dynamic>> updateDonorProfile(
      Map<String, dynamic> fields) async {
    final headers  = await _authHeaders();
    final response = await http
        .patch(
          Uri.parse('$baseUrl/donors/me'),
          headers: headers,
          body: jsonEncode(fields),
        )
        .timeout(_timeout);
    return _handleResponse(response);
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // BLOOD REQUEST ENDPOINTS
  // ══════════════════════════════════════════════════════════════════════════════

  /// POST /blood-requests
  ///
  /// Broadcasts a new blood request. Returns the created document including its
  /// `_id` which is used to navigate to TrackRequestPage.
  Future<Map<String, dynamic>> createBloodRequest({
    required String patientName,
    required int patientAge,
    required String patientGender,
    required String bloodGroup,
    required int units,
    required String component,
    required String urgency,
    required String hospital,
    required String ward,
    required String bedNumber,
    required String hubZone,
    required String attender,
    required String contactPhone,
    String targetFacilityName = '',
    String targetFacilityUid = '',
    String targetFacilityAddress = '',
    String targetFacilityPhone = '',
    bool emergencyPushEnabled = true,
    bool notifyNss = true,
    String? attachmentFileName,
  }) async {
    final headers = await _authHeaders();

    final body = <String, dynamic>{
      'patientName':           patientName,
      'patientAge':            patientAge,
      'patientGender':         patientGender,
      'bloodGroup':            bloodGroup,
      'units':                 units,
      'component':             component,
      'urgency':               urgency,
      'hospital':              hospital,
      'ward':                  ward,
      'bedNumber':             bedNumber,
      'hubZone':               hubZone,
      'attender':              attender,
      'contactPhone':          contactPhone,
      'targetFacilityName':    targetFacilityName,
      'targetFacilityUid':     targetFacilityUid,
      'targetFacilityAddress': targetFacilityAddress,
      'targetFacilityPhone':   targetFacilityPhone,
      'emergencyPushEnabled':  emergencyPushEnabled,
      'notifyNss':             notifyNss,
      if (attachmentFileName != null) 'attachmentFileName': attachmentFileName,
    };

    final response = await http
        .post(
          Uri.parse('$baseUrl/blood-requests'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    return _handleResponse(response);
  }

  /// GET /blood-requests/active
  ///
  /// Returns all open (non-cancelled, non-fulfilled) requests from OTHER users.
  /// Used by the dashboard Urgent Requests feed so donors can respond.
  Future<List<Map<String, dynamic>>> getActiveBloodRequests() async {
    final headers  = await _authHeaders();
    final response = await http
        .get(Uri.parse('$baseUrl/blood-requests/active'), headers: headers)
        .timeout(_timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(body['error'] ?? 'HTTP ${response.statusCode}');
  }

  /// GET /blood-requests/my
  ///
  /// Returns all blood requests made by the current user.
  Future<List<Map<String, dynamic>>> getMyBloodRequests() async {
    final headers  = await _authHeaders();
    final response = await http
        .get(Uri.parse('$baseUrl/blood-requests/my'), headers: headers)
        .timeout(_timeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(body['error'] ?? 'HTTP ${response.statusCode}');
  }

  /// GET /blood-requests/:id
  ///
  /// Fetches a single blood request by its MongoDB _id.
  /// Used by TrackRequestPage to show live status.
  Future<Map<String, dynamic>> getBloodRequest(String id) async {
    final headers  = await _authHeaders();
    final response = await http
        .get(Uri.parse('$baseUrl/blood-requests/$id'), headers: headers)
        .timeout(_timeout);
    return _handleResponse(response);
  }

  /// PATCH /blood-requests/:id/cancel
  ///
  /// Cancels an active blood request.
  Future<Map<String, dynamic>> cancelBloodRequest(String id) async {
    final headers  = await _authHeaders();
    final response = await http
        .patch(
          Uri.parse('$baseUrl/blood-requests/$id/cancel'),
          headers: headers,
          body: jsonEncode({}),
        )
        .timeout(_timeout);
    return _handleResponse(response);
  }

  /// PATCH /blood-requests/:id/withdraw
  ///
  /// Donor cancels their committed response before donation.
  /// Restores unitsRemaining on the request and clears activeCommitmentRequestId on the Donor.
  Future<Map<String, dynamic>> withdrawFromBloodRequest(String id) async {
    final headers  = await _authHeaders();
    final response = await http
        .patch(
          Uri.parse('$baseUrl/blood-requests/$id/withdraw'),
          headers: headers,
          body: jsonEncode({}),
        )
        .timeout(_timeout);
    return _handleResponse(response);
  }

  /// PATCH /blood-requests/:id/respond
  ///
  /// Donor commits [unitsCommitted] units to this request.
  /// Returns the updated BloodRequest document (includes new unitsRemaining).
  /// Throws an Exception with message 'already_responded' if this user already responded.
  Future<Map<String, dynamic>> respondToBloodRequest(
    String id, {
    required int    unitsCommitted,
    String          responderName = '',
  }) async {
    final headers  = await _authHeaders();
    final response = await http
        .patch(
          Uri.parse('$baseUrl/blood-requests/$id/respond'),
          headers: headers,
          body: jsonEncode({
            'unitsCommitted': unitsCommitted,
            'responderName':  responderName,
          }),
        )
        .timeout(_timeout);
    return _handleResponse(response);
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // BOOKING ENDPOINTS
  // ══════════════════════════════════════════════════════════════════════════════

  /// POST /bookings
  ///
  /// Creates a new hospital slot booking.
  Future<Map<String, dynamic>> createBooking({
    required String facilityName,
    required String slotDate,
    String facilityAddress = '',
    String facilityPhone   = '',
    String slotTime        = '',
    String donorName       = '',
    String bloodGroup      = '',
    String component       = 'Whole Blood',
    int coolingDays        = 90,
    int units              = 1,
  }) async {
    final headers = await _authHeaders();

    final body = <String, dynamic>{
      'facilityName':    facilityName,
      'facilityAddress': facilityAddress,
      'facilityPhone':   facilityPhone,
      'slotDate':        slotDate,
      'slotTime':        slotTime,
      'donorName':       donorName,
      'bloodGroup':      bloodGroup,
      'component':       component,
      'coolingDays':     coolingDays,
      'units':           units,
    };

    final response = await http
        .post(
          Uri.parse('$baseUrl/bookings'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    return _handleResponse(response);
  }

  /// GET /bookings/active
  ///
  /// Returns `{'active': false}` or `{'active': true, 'booking': {...}}`.
  /// Used by DashboardPage to check for an active booking on startup.
  Future<Map<String, dynamic>> getActiveBooking() async {
    final headers  = await _authHeaders();
    final response = await http
        .get(Uri.parse('$baseUrl/bookings/active'), headers: headers)
        .timeout(_timeout);
    return _handleResponse(response);
  }

  /// GET /bookings/:id
  Future<Map<String, dynamic>> getBooking(String id) async {
    final headers  = await _authHeaders();
    final response = await http
        .get(Uri.parse('$baseUrl/bookings/$id'), headers: headers)
        .timeout(_timeout);
    return _handleResponse(response);
  }

  /// GET /bookings/history
  Future<List<Map<String, dynamic>>> getDonationHistory() async {
    final headers = await _authHeaders();
    final response = await http
        .get(Uri.parse('$baseUrl/bookings/history'), headers: headers)
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _handleResponse(response);
    }
    return (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
  }

  /// GET /bookings/:id/certificate
  Future<Map<String, dynamic>> getCertificate(String bookingId) async {
    final headers = await _authHeaders();
    final response = await http
        .get(Uri.parse('$baseUrl/bookings/$bookingId/certificate'), headers: headers)
        .timeout(_timeout);
    return _handleResponse(response);
  }

  /// PATCH /bookings/:id/cancel
  Future<Map<String, dynamic>> cancelBooking(String id) async {
    final headers  = await _authHeaders();
    final response = await http
        .patch(
          Uri.parse('$baseUrl/bookings/$id/cancel'),
          headers: headers,
          body: jsonEncode({}),
        )
        .timeout(_timeout);
    return _handleResponse(response);
  }

  /// PATCH /bookings/:id/complete
  ///
  /// Marks the donation as completed.
  /// [donationPhotoUrl] and [doctorSlipUrl] are base-64 data-URIs or
  /// storage URLs — the backend stores them as-is for now.
  /// Returns the updated booking document.
  Future<Map<String, dynamic>> completeBooking({
    required String bookingId,
    String donationPhotoUrl = '',
    String doctorSlipUrl    = '',
  }) async {
    final headers  = await _authHeaders();
    final response = await http
        .patch(
          Uri.parse('$baseUrl/bookings/$bookingId/complete'),
          headers: headers,
          body: jsonEncode({
            'donationPhotoUrl': donationPhotoUrl,
            'doctorSlipUrl':    doctorSlipUrl,
          }),
        )
        .timeout(_timeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> markBookingNotDonated({
    required String bookingId,
    required String reason,
  }) async {
    final headers = await _authHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/bookings/$bookingId/not-donated'),
      headers: headers,
      body: jsonEncode({'reason': reason}),
    ).timeout(_timeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> appealBooking({
    required String bookingId,
    required String reason,
  }) async {
    final headers = await _authHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/bookings/$bookingId/appeal'),
      headers: headers,
      body: jsonEncode({'reason': reason}),
    ).timeout(_timeout);
    return _handleResponse(response);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BLOOD BANK ENDPOINTS
  // ════════════════════════════════════════════════════════════════════════════

  /// GET /blood-bank-accounts/all
  /// Returns all self-registered blood bank profiles (active ones).
  Future<List<Map<String, dynamic>>> getBloodBankAccounts() async {
    final headers = await _authHeaders();
    final response = await http
        .get(Uri.parse('$baseUrl/blood-bank-accounts/all'), headers: headers)
        .timeout(_timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(body['error'] ?? 'HTTP ${response.statusCode}');
  }

  /// GET /blood-banks
  /// Returns all blood banks. Pass [bloodGroup] to filter by available stock.
  Future<List<Map<String, dynamic>>> getBloodBanks({String? bloodGroup}) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$baseUrl/blood-banks').replace(
      queryParameters: (bloodGroup != null && bloodGroup.isNotEmpty)
          ? {'bloodGroup': bloodGroup}
          : null,
    );
    final response = await http.get(uri, headers: headers).timeout(_timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(body['error'] ?? 'HTTP ${response.statusCode}');
  }

  /// Returns every active facility, including admin-created blood banks and
  /// self-registered blood-bank accounts.
  Future<List<Map<String, dynamic>>> getAllDonationFacilities() async {
    final results = await Future.wait([
      getBloodBanks(),
      getBloodBankAccounts(),
    ]);
    final facilities = <Map<String, dynamic>>[];
    final keys = <String>{};
    for (final source in results) {
      for (final facility in source) {
        final id = facility['_id']?.toString() ??
            facility['uid']?.toString() ??
            '${facility['name']}-${facility['address']}';
        if (keys.add(id)) {
          facilities.add({
            ...facility,
            'isActive': facility['isActive'] ?? true,
          });
        }
      }
    }
    return facilities;
  }

  /// POST /blood-banks  (admin only)
  Future<Map<String, dynamic>> createBloodBank({
    required String name,
    required String address,
    required String phone,
    required String city,
    String hours = '8:00 AM – 6:00 PM',
    bool isVerified = true,
    Map<String, int> stock = const {},
  }) async {
    final headers  = await _authHeaders();
    final response = await http
        .post(
          Uri.parse('$baseUrl/blood-banks'),
          headers: headers,
          body: jsonEncode({
            'name': name, 'address': address, 'phone': phone,
            'city': city, 'hours': hours,
            'isVerified': isVerified, 'stock': stock,
          }),
        )
        .timeout(_timeout);
    return _handleResponse(response);
  }

  /// DELETE /blood-banks/:id  (admin only)
  Future<Map<String, dynamic>> deleteBloodBank(String id) async {
    final headers  = await _authHeaders();
    final response = await http
        .delete(Uri.parse('$baseUrl/blood-banks/$id'), headers: headers)
        .timeout(_timeout);
    return _handleResponse(response);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // DONOR REQUEST ENDPOINTS  (contact-a-donor flow)
  // ════════════════════════════════════════════════════════════════════════════

  /// POST /donor-requests
  /// Requester sends a direct contact request to a specific donor.
  Future<Map<String, dynamic>> sendDonorRequest({
    required String donorId,
    String  donorUid       = '',   // Firebase UID — primary lookup key on backend
    required String patientName,
    required String bloodGroup,
    required int    units,
    int?    patientAge,
    String  patientGender  = 'Male',
    String  component      = 'Whole Blood',
    String  urgency        = 'Urgent',
    String  hospital       = '',
    String  ward           = '',
    String  bedNumber      = '',
    String  attender       = '',
    String  contactPhone   = '',
    String  requesterName  = '',
    String  requesterPhone = '',
  }) async {
    final headers  = await _authHeaders();
    final response = await http
        .post(
          Uri.parse('$baseUrl/donor-requests'),
          headers: headers,
          body: jsonEncode({
            'donorId':       donorId,
            'donorUid':      donorUid,
            'patientName':   patientName,
            'patientAge':    patientAge,
            'patientGender': patientGender,
            'bloodGroup':    bloodGroup,
            'units':         units,
            'component':     component,
            'urgency':       urgency,
            'hospital':      hospital,
            'ward':          ward,
            'bedNumber':     bedNumber,
            'attender':      attender,
            'contactPhone':  contactPhone,
            'requesterName':  requesterName,
            'requesterPhone': requesterPhone,
          }),
        )
        .timeout(_timeout);
    return _handleResponse(response);
  }

  /// GET /donor-requests/sent
  /// All requests the current user sent to donors.
  Future<List<Map<String, dynamic>>> getMySentDonorRequests() async {
    final headers  = await _authHeaders();
    final response = await http
        .get(Uri.parse('$baseUrl/donor-requests/sent'), headers: headers)
        .timeout(_timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
    }
    throw Exception((jsonDecode(response.body) as Map)['error'] ?? 'HTTP ${response.statusCode}');
  }

  /// GET /donor-requests/inbox
  /// All requests sent TO the current user (donor inbox).
  Future<List<Map<String, dynamic>>> getDonorRequestInbox() async {
    final headers  = await _authHeaders();
    final response = await http
        .get(Uri.parse('$baseUrl/donor-requests/inbox'), headers: headers)
        .timeout(_timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
    }
    throw Exception((jsonDecode(response.body) as Map)['error'] ?? 'HTTP ${response.statusCode}');
  }

  /// GET /donor-requests/:id
  Future<Map<String, dynamic>> getDonorRequest(String id) async {
    final headers  = await _authHeaders();
    final response = await http
        .get(Uri.parse('$baseUrl/donor-requests/$id'), headers: headers)
        .timeout(_timeout);
    return _handleResponse(response);
  }

  /// PATCH /donor-requests/:id/accept
  Future<Map<String, dynamic>> acceptDonorRequest(String id, {String note = ''}) async {
    final headers  = await _authHeaders();
    final response = await http
        .patch(Uri.parse('$baseUrl/donor-requests/$id/accept'),
            headers: headers, body: jsonEncode({'donorNote': note}))
        .timeout(_timeout);
    return _handleResponse(response);
  }

  /// PATCH /donor-requests/:id/decline
  Future<Map<String, dynamic>> declineDonorRequest(String id, {String reason = ''}) async {
    final headers  = await _authHeaders();
    final response = await http
        .patch(Uri.parse('$baseUrl/donor-requests/$id/decline'),
            headers: headers, body: jsonEncode({'reason': reason}))
        .timeout(_timeout);
    return _handleResponse(response);
  }

  /// PATCH /donor-requests/:id/cancel
  Future<Map<String, dynamic>> cancelDonorRequest(String id) async {
    final headers  = await _authHeaders();
    final response = await http
        .patch(Uri.parse('$baseUrl/donor-requests/$id/cancel'),
            headers: headers, body: jsonEncode({}))
        .timeout(_timeout);
    return _handleResponse(response);
  }

  /// PATCH /donor-requests/:id/complete
  Future<Map<String, dynamic>> completeDonorRequest(String id,
      {String donationPhotoUrl = '', String doctorSlipUrl = ''}) async {
    final headers  = await _authHeaders();
    final response = await http
        .patch(
          Uri.parse('$baseUrl/donor-requests/$id/complete'),
          headers: headers,
          body: jsonEncode({
            'donationPhotoUrl': donationPhotoUrl,
            'doctorSlipUrl':    doctorSlipUrl,
          }),
        )
        .timeout(_timeout);
    return _handleResponse(response);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SEARCH / DONOR DIRECTORY ENDPOINTS
  // ════════════════════════════════════════════════════════════════════════════

  /// GET /donors/search?bloodGroup=O%2B
  /// Returns donors with showToOthers=true who are eligible to donate.
  Future<List<Map<String, dynamic>>> searchDonors({String? bloodGroup}) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$baseUrl/donors/search').replace(
      queryParameters: (bloodGroup != null && bloodGroup.isNotEmpty)
          ? {'bloodGroup': bloodGroup}
          : null,
    );
    final response = await http.get(uri, headers: headers).timeout(_timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(body['error'] ?? 'HTTP ${response.statusCode}');
  }

  /// POST /donors/manual  (admin only)
  Future<Map<String, dynamic>> addManualDonor({
    required String fullName,
    required String bloodGroup,
    required String phone,
    String city           = '',
    String donationStream = 'Whole Blood',
    bool   readyAnyTime   = true,
  }) async {
    final headers  = await _authHeaders();
    final response = await http
        .post(
          Uri.parse('$baseUrl/donors/manual'),
          headers: headers,
          body: jsonEncode({
            'fullName': fullName, 'bloodGroup': bloodGroup,
            'phone': phone, 'city': city,
            'donationStream': donationStream,
            'readyAnyTime': readyAnyTime,
            'showToOthers': true, 'manualEntry': true,
          }),
        )
        .timeout(_timeout);
    return _handleResponse(response);
  }

  /// DELETE /donors/manual/:id  (admin only)
  Future<Map<String, dynamic>> deleteManualDonor(String id) async {
    final headers  = await _authHeaders();
    final response = await http
        .delete(Uri.parse('$baseUrl/donors/manual/$id'), headers: headers)
        .timeout(_timeout);
    return _handleResponse(response);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ADMIN STATS ENDPOINTS
  // ════════════════════════════════════════════════════════════════════════════

  /// GET /admin/stats
  /// { totalUsers, registeredDonors, activeBookings,
  ///   completedDonations, bloodBanks, pendingRequests }
  Future<Map<String, dynamic>> getAdminStats() async {
    final headers  = await _authHeaders();
    final response = await http
        .get(Uri.parse('$baseUrl/admin/stats'), headers: headers)
        .timeout(_timeout);
    return _handleResponse(response);
  }

  /// GET /admin/users
  Future<List<Map<String, dynamic>>> getAdminUsers() async {
    final headers  = await _authHeaders();
    final response = await http
        .get(Uri.parse('$baseUrl/admin/users'), headers: headers)
        .timeout(_timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(body['error'] ?? 'HTTP ${response.statusCode}');
  }
}
