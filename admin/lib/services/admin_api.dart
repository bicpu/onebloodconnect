import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// API client for the admin panel.
/// Uses the same backend as the user app — just admin-only endpoints.
class AdminApi {
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
      HttpHeaders.contentTypeHeader:  'application/json',
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
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception(body['error'] ?? 'HTTP ${r.statusCode}');
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStats() async {
    final h = await _headers();
    final r = await http.get(Uri.parse('$baseUrl/admin/stats'), headers: h).timeout(_timeout);
    return _handle(r);
  }

  // ── Users ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getUsers() async {
    final h = await _headers();
    final r = await http.get(Uri.parse('$baseUrl/admin/users'), headers: h).timeout(_timeout);
    return _handleList(r);
  }

  // ── Blood Banks ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getBloodBanks() async {
    final h = await _headers();
    final r = await http.get(Uri.parse('$baseUrl/blood-banks'), headers: h).timeout(_timeout);
    return _handleList(r);
  }

  Future<List<Map<String, dynamic>>> getPendingBloodBankAccounts() async {
    final h = await _headers();
    final r = await http
        .get(Uri.parse('$baseUrl/admin/blood-bank-accounts/pending'), headers: h)
        .timeout(_timeout);
    return _handleList(r);
  }

  Future<Map<String, dynamic>> approveBloodBankAccount(String id) async {
    final h = await _headers();
    final r = await http
        .patch(
          Uri.parse('$baseUrl/admin/blood-bank-accounts/$id/approve'),
          headers: h,
        )
        .timeout(_timeout);
    return _handle(r);
  }

  Future<Map<String, dynamic>> createBloodBank({
    required String name,
    required String address,
    required String phone,
    required String city,
    required String hours,
    required Map<String, int> stock,
  }) async {
    final h = await _headers();
    final r = await http
        .post(
          Uri.parse('$baseUrl/blood-banks'),
          headers: h,
          body: jsonEncode({
            'name':       name,
            'address':    address,
            'phone':      phone,
            'city':       city,
            'hours':      hours,
            'isVerified': true,
            'stock':      stock,
          }),
        )
        .timeout(_timeout);
    return _handle(r);
  }

  Future<void> deleteBloodBank(String id) async {
    final h = await _headers();
    await http.delete(Uri.parse('$baseUrl/blood-banks/$id'), headers: h).timeout(_timeout);
  }

  // ── Manual Donors ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getManualDonors() async {
    final h = await _headers();
    final r = await http.get(Uri.parse('$baseUrl/donors/manual'), headers: h).timeout(_timeout);
    return _handleList(r);
  }

  Future<Map<String, dynamic>> addManualDonor({
    required String fullName,
    required String bloodGroup,
    required String phone,
    required String city,
    required String donationStream,
  }) async {
    final h = await _headers();
    final r = await http
        .post(
          Uri.parse('$baseUrl/donors/manual'),
          headers: h,
          body: jsonEncode({
            'fullName':       fullName,
            'bloodGroup':     bloodGroup,
            'phone':          phone,
            'city':           city,
            'donationStream': donationStream,
            'readyAnyTime':   true,
            'showToOthers':   true,
            'manualEntry':    true,
          }),
        )
        .timeout(_timeout);
    return _handle(r);
  }

  Future<void> deleteManualDonor(String id) async {
    final h = await _headers();
    await http.delete(Uri.parse('$baseUrl/donors/manual/$id'), headers: h).timeout(_timeout);
  }

  Future<List<Map<String, dynamic>>> getPendingDonations() async {
    final h = await _headers();
    final r = await http
        .get(Uri.parse('$baseUrl/admin/donations/pending'), headers: h)
        .timeout(_timeout);
    return _handleList(r);
  }

  Future<Map<String, dynamic>> verifyDonation(
      String id, {required bool approved, String note = ''}) async {
    final h = await _headers();
    final r = await http
        .patch(
          Uri.parse('$baseUrl/admin/donations/$id/verify'),
          headers: h,
          body: jsonEncode({'approved': approved, 'note': note}),
        )
        .timeout(_timeout);
    return _handle(r);
  }
}
