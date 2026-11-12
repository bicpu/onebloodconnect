import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/bb_api.dart';
import 'edit_profile_page.dart';
import 'donations_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const Color _red   = Color(0xFFC0152A);
  static const Color _sub   = Color(0xFF64748B);

  int _tab = 0;

  // ── Dashboard state ──────────────────────────────────────────────────────
  Map<String, dynamic> _stats   = {};
  bool _statsLoading = true;

  // ── Active requests state ────────────────────────────────────────────────
  List<Map<String, dynamic>> _requests = [];
  bool _reqLoading = true;
  Timer? _requestPoller;

  // ── Profile state ────────────────────────────────────────────────────────
  Map<String, dynamic> _profile = {};
  bool _profileLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _requestPoller = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadRequests(),
    );
  }

  @override
  void dispose() {
    _requestPoller?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    _loadStats();
    _loadRequests();
    _loadProfile();
  }

  Future<void> _loadStats() async {
    setState(() => _statsLoading = true);
    try {
      final s = await BbApi().getStats();
      if (mounted) setState(() { _stats = s; _statsLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  Future<void> _loadRequests() async {
    setState(() => _reqLoading = true);
    try {
      final r = await BbApi().getActiveRequests();
      if (mounted) setState(() { _requests = r; _reqLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _reqLoading = false);
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _profileLoading = true);
    try {
      final p = await BbApi().getMe();
      if (mounted) setState(() { _profile = p; _profileLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: _red,
        elevation: 0,
        title: Row(children: const [
          Icon(Icons.local_hospital, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text('Blood Bank Portal',
              style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 17)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadAll,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Row(children: [
            _tabBtn(0, Icons.dashboard_outlined,   'Dashboard'),
            _tabBtn(1, Icons.bloodtype_outlined,    'Requests'),
            _tabBtn(2, Icons.verified_outlined,      'Donations'),
            _tabBtn(3, Icons.manage_accounts_outlined, 'Profile'),
          ]),
        ),
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _buildDashboard(),
          _buildRequestsTab(),
          const DonationsPage(),
          _buildProfileTab(),
        ],
      ),
    );
  }

  Widget _tabBtn(int idx, IconData icon, String label) {
    final active = _tab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = idx),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: active ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
            border: Border(bottom: BorderSide(
                color: active ? Colors.white : Colors.transparent, width: 2)),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.white, size: 17),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Colors.white,
                    fontSize: 10, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  // ── Dashboard tab ─────────────────────────────────────────────────────────
  Widget _buildDashboard() {
    if (_statsLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFC0152A)));
    }

    final bankName  = _stats['name']         as String? ?? 'Your Blood Bank';
    final verified  = _stats['isVerified']   == true;
    final units     = _stats['totalUnits']   ?? 0;
    final groups    = _stats['stockGroups']  ?? 0;
    final users     = _stats['totalUsers']   ?? 0;
    final openReqs  = _stats['openRequests'] ?? 0;
    final doctors   = _stats['doctors']      ?? 0;
    final nurses    = _stats['nurses']       ?? 0;
    final slots     = _stats['slots']        ?? 0;

    final cards = [
      _Stat('Total Blood Units', units,   Icons.water_drop,          const Color(0xFFC0152A), const Color(0xFFFFEAEA)),
      _Stat('Blood Groups',      groups,  Icons.category_outlined,   const Color(0xFF7C3AED), const Color(0xFFF5F3FF)),
      _Stat('App Users',         users,   Icons.people_outline,      const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
      _Stat('Open Requests',     openReqs,Icons.pending_actions,     const Color(0xFFD97706), const Color(0xFFFFFBEB)),
      _Stat('Doctors',           doctors, Icons.medical_services_outlined, const Color(0xFF15803D), const Color(0xFFDCFCE7)),
      _Stat('Nurses',            nurses,  Icons.people_alt_outlined, const Color(0xFF0891B2), const Color(0xFFCFFAFE)),
    ];

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Welcome banner ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B0000), Color(0xFFC0152A)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: _red.withValues(alpha: 0.3),
                  blurRadius: 14, offset: const Offset(0, 5))],
            ),
            child: Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bankName,
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 17),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(verified ? Icons.verified : Icons.pending_outlined,
                        color: verified ? const Color(0xFF4ADE80) : Colors.white60,
                        size: 14),
                    const SizedBox(width: 4),
                    Text(verified ? 'Verified Partner' : 'Pending Verification',
                        style: TextStyle(
                            color: verified ? const Color(0xFF4ADE80) : Colors.white60,
                            fontSize: 12)),
                  ]),
                  const SizedBox(height: 6),
                  Text('$slots donation slot${slots != 1 ? 's' : ''} configured',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11)),
                ],
              )),
              const Icon(Icons.local_hospital, color: Colors.white38, size: 48),
            ]),
          ),

          const SizedBox(height: 18),

          const Text('Overview',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 10),

          // ── Stat grid ───────────────────────────────────────────────────
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cards.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 12,
              mainAxisSpacing: 12, childAspectRatio: 1.5,
            ),
            itemBuilder: (_, i) {
              final c = cards[i];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(color: c.bg,
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(c.icon, color: c.color, size: 18),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${c.value}',
                          style: TextStyle(fontSize: 26,
                              fontWeight: FontWeight.bold, color: c.color)),
                      Text(c.label,
                          style: const TextStyle(fontSize: 11,
                              color: Color(0xFF64748B))),
                    ]),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 18),

          // ── Quick action ────────────────────────────────────────────────
          GestureDetector(
            onTap: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const EditProfilePage()));
              _loadAll();
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFEAEA), shape: BoxShape.circle),
                  child: const Icon(Icons.edit_outlined,
                      color: Color(0xFFC0152A), size: 20),
                ),
                const SizedBox(width: 14),
                const Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Edit Profile & Stock',
                        style: TextStyle(fontWeight: FontWeight.bold,
                            fontSize: 14, color: Color(0xFF0F172A))),
                    Text('Update blood stock, slots, doctors, hours',
                        style: TextStyle(fontSize: 12,
                            color: Color(0xFF64748B))),
                  ],
                )),
                const Icon(Icons.arrow_forward_ios,
                    size: 14, color: Color(0xFF94A3B8)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Requests tab ──────────────────────────────────────────────────────────
  Widget _buildRequestsTab() {
    if (_reqLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFC0152A)));
    }
    if (_requests.isEmpty) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.check_circle_outline, color: Color(0xFF15803D), size: 48),
          SizedBox(height: 12),
          Text('No active blood requests',
              style: TextStyle(color: Color(0xFF64748B),
                  fontSize: 15, fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('Requests from the user app will appear here.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        ],
      ));
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        itemBuilder: (_, i) => _requestCard(_requests[i]),
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> r) {
    final bloodGroup = r['bloodGroup']  as String? ?? '?';
    final hospital   = r['hospital']    as String? ?? 'Hospital';
    final urgency    = r['urgency']     as String? ?? 'Urgent';
    final units      = r['units']       ?? 1;
    final patient    = r['patientName'] as String? ?? 'Patient';
    final phone      = r['contactPhone'] as String? ?? '';
    final component  = r['component']  as String? ?? 'Whole Blood';
    final remaining  = r['unitsRemaining'] ?? units;

    Color uColor;
    switch (urgency) {
      case 'Critical Red': uColor = const Color(0xFFCC0000); break;
      case 'Urgent':       uColor = const Color(0xFFD97706); break;
      default:             uColor = const Color(0xFF2563EB);
    }

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _showRequestDetails(r),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: uColor.withValues(alpha: 0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Blood group badge
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: uColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(bloodGroup,
                style: TextStyle(color: uColor,
                    fontWeight: FontWeight.w900, fontSize: 16)),
            Text('$remaining u',
                style: TextStyle(color: uColor.withValues(alpha: 0.7),
                    fontSize: 9, fontWeight: FontWeight.bold)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(patient,
                  style: const TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 14, color: Color(0xFF0F172A)))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: uColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(urgency,
                    style: TextStyle(fontSize: 10,
                        color: uColor, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 3),
            Text(hospital,
                style: const TextStyle(fontSize: 12,
                    color: Color(0xFF64748B)),
                overflow: TextOverflow.ellipsis),
            Text('$component · $units unit${units != 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 11,
                    color: Color(0xFF94A3B8))),
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 5),
              Row(children: [
                const Icon(Icons.phone_outlined, size: 12,
                    color: Color(0xFF2563EB)),
                const SizedBox(width: 4),
                Text(phone,
                    style: const TextStyle(fontSize: 12,
                        color: Color(0xFF2563EB), fontWeight: FontWeight.w500)),
              ]),
            ],
          ],
        )),
      ]),
      ),
    );
  }

  Future<void> _showRequestDetails(Map<String, dynamic> request) async {
    final commentController = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final urgency = request['urgency'] as String? ?? 'Urgent';
        final status = request['facilityReviewStatus'] as String? ?? 'pending';
        final color = urgency == 'Critical Red'
            ? const Color(0xFFCC0000)
            : urgency == 'Urgent'
                ? const Color(0xFFD97706)
                : const Color(0xFF2563EB);
        return Padding(
          padding: EdgeInsets.only(
              top: 50, bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Material(
            color: const Color(0xFFF7F9FC),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: StatefulBuilder(
              builder: (context, setSheetState) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 42, height: 5,
                        decoration: BoxDecoration(color: Colors.black12,
                            borderRadius: BorderRadius.circular(8)))),
                    const SizedBox(height: 18),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: color.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(14)),
                        child: Icon(Icons.bloodtype_rounded, color: color, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Blood request details',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A))),
                          Text(status == 'pending' ? 'Awaiting your review' : status.toUpperCase(),
                              style: TextStyle(fontSize: 11, color: color,
                                  fontWeight: FontWeight.w700)),
                        ],
                      )),
                    ]),
                    const SizedBox(height: 20),
                    _detailGrid(request),
                    if (status == 'pending') ...[
                      const SizedBox(height: 20),
                      const Text('Review comment',
                          style: TextStyle(fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A))),
                      const SizedBox(height: 8),
                      TextField(
                        controller: commentController,
                        maxLines: 3,
                        onChanged: (_) => setSheetState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Explain the decision to the requester',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: OutlinedButton.icon(
                          onPressed: commentController.text.trim().isEmpty
                              ? null
                              : () => _submitReview(request, false, commentController.text.trim(), sheetContext),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFB91C1C),
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: ElevatedButton.icon(
                          onPressed: commentController.text.trim().isEmpty
                              ? null
                              : () => _submitReview(request, true, commentController.text.trim(), sheetContext),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Accept'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF15803D),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        )),
                      ]),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    commentController.dispose();
    if (result == true) {
      await _loadRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request review saved and requester notified.'),
            backgroundColor: Color(0xFF15803D),
          ),
        );
      }
    }
  }

  Widget _detailGrid(Map<String, dynamic> r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(children: [
        _detailLine(Icons.person_outline, 'Patient', r['patientName'] ?? '—'),
        _detailLine(Icons.bloodtype_outlined, 'Requirement',
            '${r['bloodGroup'] ?? '—'} · ${r['component'] ?? 'Whole Blood'}'),
        _detailLine(Icons.numbers_outlined, 'Units',
            '${r['units'] ?? 1} required · ${r['unitsRemaining'] ?? r['units'] ?? 1} remaining'),
        _detailLine(Icons.local_hospital_outlined, 'Hospital', r['hospital'] ?? '—'),
        _detailLine(Icons.meeting_room_outlined, 'Ward / bed',
            '${r['ward'] ?? '—'} · ${r['bedNumber'] ?? '—'}'),
        _detailLine(Icons.contact_phone_outlined, 'Attender',
            '${r['attender'] ?? '—'} · ${r['contactPhone'] ?? '—'}'),
      ]),
    );
  }

  Widget _detailLine(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        SizedBox(width: 88, child: Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
        Expanded(child: Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: Color(0xFF172033)))),
      ]),
    );
  }

  Future<void> _submitReview(Map<String, dynamic> request, bool accepted,
      String comment, BuildContext sheetContext) async {
    try {
      await BbApi().reviewBloodRequest(
        request['_id'] as String,
        accepted: accepted,
        comment: comment,
      );
      if (sheetContext.mounted) {
        Navigator.of(sheetContext).pop(true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update request: $error')),
        );
      }
    }
  }

  // ── Profile tab ───────────────────────────────────────────────────────────
  Widget _buildProfileTab() {
    if (_profileLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFC0152A)));
    }

    final p        = _profile;
    final name     = p['name']           as String? ?? '–';
    final address  = p['address']        as String? ?? '';
    final city     = p['city']           as String? ?? '';
    final state    = p['state']          as String? ?? '';
    final phone    = p['phone']          as String? ?? '';
    final hours    = p['hours']          as String? ?? '';
    final regNo    = p['registrationNo'] as String? ?? '';
    final verified = p['isVerified']     == true;
    final rawStock = p['stock'];
    final stock = rawStock is Map
        ? rawStock.cast<String, dynamic>()
        : <String, dynamic>{};
    final doctors = (p['doctors'] as List?) ?? [];
    final nurses  = (p['nurses']  as List?) ?? [];
    final slots   = (p['slots']   as List?) ?? [];

    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Bank header ────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(name,
                    style: const TextStyle(fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A)))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: verified
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    verified ? 'Verified ✓' : 'Pending',
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold,
                      color: verified
                          ? const Color(0xFF15803D)
                          : const Color(0xFFD97706),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              if (regNo.isNotEmpty) _row(Icons.badge_outlined, 'Reg No', regNo),
              if (phone.isNotEmpty) _row(Icons.phone_outlined, 'Phone', phone),
              if (hours.isNotEmpty) _row(Icons.access_time_outlined, 'Hours', hours),
              if (address.isNotEmpty)
                _row(Icons.location_on_outlined, 'Address',
                    [address, city, state].where((s) => s.isNotEmpty).join(', ')),
            ]),
          ),
          const SizedBox(height: 14),

          // ── Blood stock ────────────────────────────────────────────────
          _sectionCard('Blood Stock', Icons.water_drop, children: [
            if (stock.isEmpty)
              const Text('No stock added yet.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13))
            else
              Wrap(
                spacing: 8, runSpacing: 8,
                children: stock.entries.map((e) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEAEA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${e.key}: ${e.value}',
                      style: const TextStyle(color: Color(0xFFC0152A),
                          fontWeight: FontWeight.bold, fontSize: 13)),
                )).toList(),
              ),
          ]),
          const SizedBox(height: 10),

          // ── Slots ──────────────────────────────────────────────────────
          _sectionCard('Donation Slots', Icons.schedule_outlined, children: [
            if (slots.isEmpty)
              const Text('No slots configured.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13))
            else
              Wrap(
                spacing: 8, runSpacing: 8,
                children: slots.map((s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(s.toString(),
                      style: const TextStyle(color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w600, fontSize: 12)),
                )).toList(),
              ),
          ]),
          const SizedBox(height: 10),

          // ── Doctors ────────────────────────────────────────────────────
          _sectionCard('Doctors', Icons.medical_services_outlined, children: [
            if (doctors.isEmpty)
              const Text('No doctors added.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13))
            else
              ...doctors.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold,
                          fontSize: 13, color: Color(0xFF0F172A))),
                  if ((d['speciality'] as String?)?.isNotEmpty == true)
                    Text(d['speciality']!,
                        style: const TextStyle(fontSize: 12,
                            color: Color(0xFF64748B))),
                  if ((d['phone'] as String?)?.isNotEmpty == true)
                    Text(d['phone']!,
                        style: const TextStyle(fontSize: 12,
                            color: Color(0xFF2563EB))),
                  if ((d['available'] as String?)?.isNotEmpty == true)
                    Text('Available: ${d['available']}',
                        style: const TextStyle(fontSize: 11,
                            color: Color(0xFF94A3B8))),
                ]),
              )),
          ]),
          const SizedBox(height: 10),

          // ── Nurses ────────────────────────────────────────────────────
          _sectionCard('Nurses', Icons.people_alt_outlined, children: [
            if (nurses.isEmpty)
              const Text('No nurses added.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13))
            else
              ...nurses.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(child: Text(n['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold,
                          fontSize: 13))),
                  if ((n['phone'] as String?)?.isNotEmpty == true)
                    Text(n['phone']!,
                        style: const TextStyle(fontSize: 12,
                            color: Color(0xFF2563EB))),
                ]),
              )),
          ]),

          const SizedBox(height: 16),

          // ── Edit button ─────────────────────────────────────────────────
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const EditProfilePage()));
                _loadAll();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.edit_outlined,
                  color: Colors.white, size: 18),
              label: const Text('Edit Profile & Stock',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────
  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 14, color: _sub),
      const SizedBox(width: 6),
      Expanded(child: Text('$label: $value',
          style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
    ]),
  );

  Widget _sectionCard(String title, IconData icon,
      {required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 15, color: _red),
          const SizedBox(width: 6),
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold,
                  fontSize: 13, color: Color(0xFF0F172A))),
        ]),
        const SizedBox(height: 10),
        ...children,
      ]),
    );
  }
}

class _Stat {
  final String label;
  final dynamic value;
  final IconData icon;
  final Color color;
  final Color bg;
  const _Stat(this.label, this.value, this.icon, this.color, this.bg);
}
