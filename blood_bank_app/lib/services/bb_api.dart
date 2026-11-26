import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// HTTP client for the Blood Bank Portal.
/// Shares the same backend as the user app and admin app.
class BbApi {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
  static const Duration _timeout = Duration(seconds: 8);

  Future<Map<String, String>> _headers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');
    final token = await user.getIdToken(false);
    return {
      HttpHeaders.contentTypeHeader:   'application/json',
      HttpHeaders.authorizationHeader: 'Bearer $token',
    };
  }

  Map<String, dynamic> _handle(http.Response r) {
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode >= 200 && r.statusCode < 300) return body;
    throw Exception(body['error'] ?? 'HTTP ${r.statusCode}');
  }

  List<Map<String, dynamic>> _handleList(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
    }
    throw Exception((jsonDecode(r.body) as Map)['error'] ?? 'HTTP ${r.statusCode}');
  }

  // ── Registration ──────────────────────────────────────────────────────────

  /// POST /blood-bank-accounts/register
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String address,
    required String city,
    required String state,
    required String pincode,
    String registrationNo = '',
    String hours          = '8:00 AM – 6:00 PM',
    String website        = '',
  }) async {
    final h = await _headers();
    final r = await http.post(
      Uri.parse('$baseUrl/blood-bank-accounts/register'),
      headers: h,
      body: jsonEncode({
        'name': name, 'email': email, 'phone': phone,
        'address': address, 'city': city, 'state': state,
        'pincode': pincode, 'registrationNo': registrationNo,
        'hours': hours, 'website': website,
      }),
    ).timeout(_timeout);
    return _handle(r);
  }

  // ── Profile ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMe() async {
    final h = await _headers();
    final r = await http.get(Uri.parse('$baseUrl/blood-bank-accounts/me'), headers: h).timeout(_timeout);
    return _handle(r);
  }

  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> fields) async {
    final h = await _headers();
    final r = await http.patch(
      Uri.parse('$baseUrl/blood-bank-accounts/me'),
      headers: h,
      body: jsonEncode(fields),
    ).timeout(_timeout);
    return _handle(r);
  }

  // ── Dashboard ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStats() async {
    final h = await _headers();
    final r = await http.get(Uri.parse('$baseUrl/blood-bank-accounts/stats'), headers: h).timeout(_timeout);
    return _handle(r);
  }

  Future<List<Map<String, dynamic>>> getActiveRequests() async {
    final h = await _headers();
    final r = await http.get(Uri.parse('$baseUrl/blood-bank-accounts/active-requests'), headers: h).timeout(_timeout);
    return _handleList(r);
  }

  Future<Map<String, dynamic>> reviewBloodRequest(
      String id, {required bool accepted, required String comment}) async {
    final h = await _headers();
    final r = await http.patch(
      Uri.parse('$baseUrl/blood-bank-accounts/requests/$id/review'),
      headers: h,
      body: jsonEncode({'accepted': accepted, 'comment': comment}),
    ).timeout(_timeout);
    return _handle(r);
  }

  Future<List<Map<String, dynamic>>> getPendingDonations() async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$baseUrl/blood-bank-accounts/donations/pending'),
      headers: h,
    ).timeout(_timeout);
    return _handleList(r);
  }

  Future<Uint8List> getDonationProofImage(String donationId, String kind) async {
    final h = await _headers();
    final r = await http.get(
      Uri.parse('$baseUrl/blood-bank-accounts/donations/$donationId/proof/$kind'),
      headers: h,
    ).timeout(_timeout);
    if (r.statusCode >= 200 && r.statusCode < 300) return r.bodyBytes;
    String error = 'HTTP ${r.statusCode}';
    try {
      error = (jsonDecode(r.body) as Map<String, dynamic>)['error']?.toString() ?? error;
    } catch (_) {}
    throw Exception(error);
  }

  Future<Map<String, dynamic>> verifyDonation(
      String id, {required bool approved}) async {
    final h = await _headers();
    final r = await http.patch(
      Uri.parse('$baseUrl/blood-bank-accounts/donations/$id/verify'),
      headers: h,
      body: jsonEncode({'approved': approved}),
    ).timeout(_timeout);
    return _handle(r);
  }
}
