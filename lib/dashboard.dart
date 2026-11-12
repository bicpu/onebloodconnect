import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile.dart';
import 'request_blood_page.dart';
import 'donate_blood_page.dart';
import 'search_page.dart';
import 'verified_booking_page.dart';
import 'donation_processing_page.dart';
import 'book_hospital_slot_page.dart';
import 'blood_bank_details_page.dart';
import 'user_profile_store.dart';
import 'widgets/floating_nav.dart';
import 'services/api_service.dart';
import 'emergency_response_page.dart';
import 'notifications_page.dart';
import 'donor_request_inbox_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // ── Palette ────────────────────────────────────────────────────────────────
  static const Color primaryRed  = Color(0xFFC0152A);
  static const Color darkText    = Color(0xFF0F172A);
  static const Color subText     = Color(0xFF64748B);
  static const Color cardBg      = Color(0xFFFFFFFF);

  final int _selectedIndex = 0;

  // ── State ─────────────────────────────────────────────────────────────────
  String _displayName = 'Alex';
  String _bloodGroup  = '--';
  bool   _dataLoading = true;
  bool   _isDonor     = false;
  int    _donations   = 0;
  int    _myRequests  = 0;
  String _bookingStatus = '';
  String _facilityName  = '';
  Map<String, dynamic> _activeBookingData = {};
  List<Map<String, dynamic>> _banks           = [];
  List<Map<String, dynamic>> _activeRequests  = []; // live urgent requests from other users
  int _pendingInboxCount = 0;
  Timer? _inboxRefreshTimer;
  Map<String, dynamic>       _donor           = {}; // current user's donor profile

  int get _livesSaved => _donations * 3;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _inboxRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _loadInboxCount();
    });
  }

  @override
  void dispose() {
    _inboxRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _dataLoading = true);
    await Future.wait([_loadIdentity(), _loadDonorData()]);
    if (mounted) setState(() => _dataLoading = false);
  }

  Future<void> _loadInboxCount() async {
    try {
      final requests = await ApiService().getDonorRequestInbox();
      if (!mounted) return;
      final pending = requests.where((request) =>
          (request['status']?.toString() ?? 'pending') == 'pending').length;
      if (pending != _pendingInboxCount) {
        setState(() => _pendingInboxCount = pending);
      }
    } catch (_) {
      // Keep the last known badge state during temporary connectivity loss.
    }
  }

  Future<void> _loadIdentity() async {
    final user = FirebaseAuth.instance.currentUser;
    final bg   = await UserProfileStore.getBloodGroup();
    if (!mounted) return;
    setState(() {
      _displayName = user?.displayName?.trim().isNotEmpty == true
          ? user!.displayName!.trim()
          : 'Donor';
      _bloodGroup = (bg == null || bg.isEmpty) ? '--' : bg;
    });
  }

  Future<void> _loadDonorData() async {
    try {
      final results = await Future.wait([
        ApiService().getMyDonorProfile(),
        ApiService().getActiveBooking(),
        ApiService().getMyBloodRequests(),
        ApiService().getBloodBanks(),
        ApiService().getActiveBloodRequests(),
        ApiService().getDonorRequestInbox(),
      ]);

      final donor          = results[0] as Map<String, dynamic>;
      final booking        = results[1] as Map<String, dynamic>;
      final requests       = results[2] as List<Map<String, dynamic>>;
      final banks          = results[3] as List<Map<String, dynamic>>;
      final activeRequests = results[4] as List<Map<String, dynamic>>;
      final inboxRequests = results[5] as List<Map<String, dynamic>>;

      if (!mounted) return;
      setState(() {
        _isDonor   = donor['registered'] == true;
        final u    = donor['lastDonationUnits'];
        _donations = (u is int) ? u : (u as num?)?.toInt() ?? 0;
        final apiBg = donor['bloodGroup'] as String?;
        if (apiBg != null && apiBg.isNotEmpty) _bloodGroup = apiBg;

        if (booking['active'] == true) {
          _bookingStatus    = 'active';
          _facilityName     = (booking['booking'] as Map?)?['facilityName'] as String? ?? '';
          _activeBookingData = (booking['booking'] as Map?)?.cast<String, dynamic>() ?? {};
        } else if (booking['cooling'] == true) {
          _bookingStatus    = 'cooling';
          _facilityName     = (booking['booking'] as Map?)?['facilityName'] as String? ?? '';
          _activeBookingData = (booking['booking'] as Map?)?.cast<String, dynamic>() ?? {};
        } else {
          _bookingStatus    = '';
          _activeBookingData = {};
        }

        _myRequests = requests.length;
        _banks      = banks.take(2).toList();
        _activeRequests = activeRequests;
        _pendingInboxCount = inboxRequests.where((request) =>
            (request['status']?.toString() ?? 'pending') == 'pending').length;
        _donor          = donor;
      });
    } catch (_) {}
  }

  Future<void> _openProfile() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
    await _loadAll();
  }

  void _openActiveBooking() {
    if (_activeBookingData.isEmpty) return;
    final b          = _activeBookingData;
    final component  = (b['component']  as String?) ?? 'Whole Blood';
    final bookingId  = (b['_id']        as String?) ?? '';
    int coolingDays; String coolingNote;
    if (component.toLowerCase().contains('platelet')) {
      coolingDays = 7;  coolingNote = '7 days';
    } else if (component.toLowerCase().contains('plasma')) {
      coolingDays = 28; coolingNote = '28 days';
    } else {
      coolingDays = 90; coolingNote = '3 months (90 days)';
    }
    if (_bookingStatus == 'cooling') {
      final donatedAt = DateTime.tryParse(b['donatedAt'] as String? ?? '') ??
          DateTime.tryParse(b['slotDate'] as String? ?? '') ??
          DateTime.now();
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => DonationProcessingPage(
          bookingId: bookingId,
          donorName: _displayName,
          bloodGroup: _bloodGroup,
          component: component,
          donatedAt: donatedAt,
          coolingDays: (b['coolingDays'] as num?)?.toInt() ?? 90,
          facilityName: (b['facilityName'] as String?) ?? 'Blood Bank',
        ),
      ));
      return;
    }

    DateTime slotDate;
    try { slotDate = DateTime.parse(b['slotDate'] as String); }
    catch (_) { slotDate = DateTime.now(); }

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => VerifiedBookingPage(
        bookingId:       bookingId,
        donorName:       _displayName,
        bloodGroup:      _bloodGroup,
        component:       component,
        slotDate:        slotDate,
        slotTime:        (b['slotTime']        as String?) ?? '',
        coolingDays:     coolingDays,
        coolingNote:     coolingNote,
        facilityName:    (b['facilityName']    as String?) ?? 'Blood Bank',
        facilityAddress: (b['facilityAddress'] as String?) ?? '',
        facilityPhone:   (b['facilityPhone']   as String?) ?? '',
      ),
    ));
  }

  String get _firstName => _displayName.trim().split(' ').first;
  String get _timeGreeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Good night';
  }

  String get _initials {
    final p = _displayName.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (p.isEmpty) return 'D';
    if (p.length == 1) return p.first[0].toUpperCase();
    return '${p.first[0]}${p.last[0]}'.toUpperCase();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadAll,
            color: primaryRed,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Gradient header sliver ─────────────────────────────
                SliverToBoxAdapter(child: _buildGradientHeader()),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 16),

                      // Booking banner
                      if (_bookingStatus.isNotEmpty) ...[
                        _buildBookingBanner(),
                        const SizedBox(height: 12),
                      ],

                      // 4-button quick grid
                      _buildQuickGrid(),
                      const SizedBox(height: 16),

                      // Impact card
                      _buildImpactCard(),
                      const SizedBox(height: 20),

                      // Urgent Requests header
                      _sectionHeader('Urgent Requests', 'See all', () {}),
                      const SizedBox(height: 10),
                      _buildUrgentSection(),
                      const SizedBox(height: 20),

                      // Nearby Blood Banks
                      _sectionHeader('Nearby Blood Banks & Stock', 'View Map', () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchPage()));
                      }),
                      const SizedBox(height: 10),
                      _buildNearbyBanks(),
                      const SizedBox(height: 20),

                      // Plasma / info card
                      _buildPlasmaCard(),
                      const SizedBox(height: 20),

                      // Upcoming drives
                      _sectionHeader('Upcoming Campus & Mobile Drives', 'View Calendar', () {}),
                      const SizedBox(height: 10),
                      _buildDriveItem(
                        month: 'OCT', day: '24',
                        title: 'Pondicherry University Health Centre Drive',
                        subtitle: 'Open to all students & faculty',
                        time: '9:00 AM – 4:00 PM',
                        address: 'Student Health Centre, PU Campus',
                        spots: '38 spots left',
                        urgent: false,
                      ),
                      _buildDriveItem(
                        month: 'OCT', day: '27',
                        title: 'South Block Promenade Walk Donation Run',
                        subtitle: 'All blood groups needed',
                        time: '8:00 AM – 1:00 PM',
                        address: 'White Town Promenade, Puducherry',
                        spots: '12 spots left',
                        urgent: true,
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),

          // Floating nav
          Positioned(
            left: 20, right: 20, bottom: 16,
            child: FloatingNav(selectedIndex: _selectedIndex),
          ),
        ],
      ),
    );
  }

  // ── Gradient header ────────────────────────────────────────────────────────
  Widget _buildGradientHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF8B0000), Color(0xFFC0152A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: logo + icons
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.water_drop, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text('One Blood Connect',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  // Notification
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationsPage()),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                        ),
                        if (_myRequests > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 14, height: 14,
                              decoration: BoxDecoration(
                                color: Colors.orangeAccent,
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF8B0000), width: 1.5),
                              ),
                              child: Center(
                                child: Text(
                                  _myRequests > 9 ? '9+' : '$_myRequests',
                                  style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Profile avatar
                  GestureDetector(
                    onTap: _openProfile,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      child: Text(_initials,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Greeting
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$_timeGreeting, $_firstName 👋',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          _isDonor
                              ? 'Blood Type $_bloodGroup · Active Donor'
                              : 'Blood Type $_bloodGroup · Welcome',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        // Location row
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.white70, size: 13),
                            const SizedBox(width: 3),
                            Text('Pondicherry University, Puducherry',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_dataLoading)
                    const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Stats row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _headerStat(_dataLoading ? '–' : '$_donations', 'Total\nDonations'),
                    _headerDivider(),
                    _headerStat(_dataLoading ? '–' : '$_livesSaved', 'Lives\nSaved'),
                    _headerDivider(),
                    _headerStat(_dataLoading ? '–' : '$_myRequests', 'Blood\nRequests'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 10, height: 1.3)),
      ],
    );
  }

  Widget _headerDivider() => Container(
      width: 1, height: 36,
      color: Colors.white.withValues(alpha: 0.25));

  // ── Booking banner ─────────────────────────────────────────────────────────
  Widget _buildBookingBanner() {
    final isActive = _bookingStatus == 'active';
    final color    = isActive ? const Color(0xFF1D4ED8) : const Color(0xFFD97706);
    final bg       = isActive ? const Color(0xFFEFF6FF) : const Color(0xFFFFFBEB);
    final border   = isActive ? const Color(0xFFBFDBFE) : const Color(0xFFFDE68A);
    final icon     = isActive ? Icons.calendar_month : Icons.hourglass_top_rounded;
    final title    = isActive ? '🗓 Active Booking' : '⏳ Cooling Period Active';
    final sub      = isActive
        ? 'Tap to view your booked slot at $_facilityName'
        : 'Cooling period running · $_facilityName';

    return GestureDetector(
      onTap: _openActiveBooking,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 1.5),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
              child: const Text('View', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ── 4-button quick grid ────────────────────────────────────────────────────
  Widget _buildQuickGrid() {
    final actions = [
      _QuickAction(icon: Icons.bloodtype_outlined,        label: 'Donate\nBlood',        color: primaryRed,             bg: const Color(0xFFFFEAEA)),
      _QuickAction(icon: Icons.emergency_outlined,        label: 'Request\nBlood',        color: const Color(0xFFDC2626), bg: const Color(0xFFFEE2E2)),
      _QuickAction(icon: Icons.local_hospital_outlined,   label: 'Blood Banks',           color: const Color(0xFF2563EB), bg: const Color(0xFFEFF6FF)),
      _QuickAction(icon: Icons.local_phone_outlined,      label: 'Donor\nInbox',          color: const Color(0xFFD97706), bg: const Color(0xFFFFFBEB)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (_, i) {
        final a = actions[i];
        return GestureDetector(
          onTap: () {
            if (i == 0) { Navigator.push(context, MaterialPageRoute(builder: (_) => const DonateBloodPage())); }
            if (i == 1) { Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestBloodPage())); }
            if (i == 2) { Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchPage())); }
            if (i == 3) { Navigator.push(context, MaterialPageRoute(builder: (_) => const DonorRequestInboxPage())); }
          },
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: a.bg, shape: BoxShape.circle),
                  child: Icon(a.icon, color: a.color, size: 22),
                ),
                const SizedBox(height: 6),
                Text(a.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: darkText, height: 1.3)),
              ],
            ),
                if (i == 3 && _pendingInboxCount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: primaryRed,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          _pendingInboxCount > 9 ? '9+' : '$_pendingInboxCount',
                          style: const TextStyle(color: Colors.white, fontSize: 9,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Impact card ────────────────────────────────────────────────────────────
  Widget _buildImpactCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B0000), Color(0xFFC0152A)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: primaryRed.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.favorite, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text('Your Impact', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                _isDonor ? 'Active Donor' : 'Not Registered',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Big lives saved
          Text(
            _dataLoading
                ? '– Lives Saved'
                : _livesSaved > 0
                    ? '$_livesSaved Lives Saved'
                    : _isDonor ? 'First Donation Pending' : 'Register & Start Saving',
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, height: 1.1),
          ),
          const SizedBox(height: 6),
          Text(
            'Every donation directly protects up to 3 lives.\nYour contribution powers regional emergency reserves.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 16),

          // Bottom stats row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(_dataLoading ? '–' : '$_donations',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const Text('Total\nDonations',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 10, height: 1.3)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(_dataLoading ? '–' : '1,600',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const Text('Yearly\nCapacity (ml)',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 10, height: 1.3)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // CTA button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DonateBloodPage())),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('You might save 3 more lives →',
                  style: TextStyle(color: primaryRed, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Urgent requests ────────────────────────────────────────────────────────
  Widget _buildUrgentSection() {
    if (_activeRequests.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.check_circle_outline, color: Color(0xFF15803D), size: 32),
              SizedBox(height: 8),
              Text('No urgent requests right now',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600)),
              SizedBox(height: 4),
              Text('You\'ll see live requests here as they come in.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _activeRequests.take(3).map((r) {
        final bloodGroup      = r['bloodGroup']    as String? ?? '?';
        final hospital        = r['hospital']      as String? ?? 'Hospital';
        final urgency         = r['urgency']       as String? ?? 'Urgent';
        final totalUnits      = (r['units'] as num?)?.toInt() ?? 1;
        final remaining       = (r['unitsRemaining'] as num?)?.toInt() ?? totalUnits;
        final hasResponded    = r['hasResponded']  == true;
        final isCritical      = urgency == 'Critical Red';

        // Build tag list — always show remaining units, then responded/urgency state
        final List<String> tags;
        final List<Color>  tagColors;
        if (hasResponded) {
          tags      = ['Responded ✓'];
          tagColors = [const Color(0xFF15803D)];
        } else if (isCritical) {
          tags      = ['Respond Now'];
          tagColors = [primaryRed];
        } else {
          tags      = ['Help Needed'];
          tagColors = [const Color(0xFF2563EB)];
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EmergencyResponsePage(request: r, donor: _donor),
                ),
              );
              // Refresh after returning so fulfilled requests disappear
              // and responded state updates
              _loadDonorData();
            },
            child: _urgentCard(
              bloodGroup:   bloodGroup,
              label:        '$bloodGroup · $remaining of $totalUnits unit${totalUnits != 1 ? 's' : ''} needed',
              hospital:     hospital,
              tags:         tags,
              tagColors:    tagColors,
              isCritical:   isCritical && !hasResponded,
              hasResponded: hasResponded,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _urgentCard({
    required String bloodGroup,
    required String label,
    required String hospital,
    required List<String> tags,
    required List<Color> tagColors,
    required bool isCritical,
    bool hasResponded = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
        border: hasResponded
            ? Border.all(color: const Color(0xFF15803D).withValues(alpha: 0.5))
            : (isCritical ? Border.all(color: const Color(0xFFFCA5A5)) : null),
      ),
      child: Row(
        children: [
          // Blood group badge
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: hasResponded
                  ? const Color(0xFFDCFCE7)
                  : (isCritical ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(bloodGroup,
                    style: TextStyle(
                        color: hasResponded
                            ? const Color(0xFF15803D)
                            : (isCritical ? primaryRed : const Color(0xFF2563EB)),
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: darkText)),
                const SizedBox(height: 2),
                Text(hospital.replaceAll('\n', ' • '),
                    style: const TextStyle(fontSize: 11, color: subText)),
              ],
            ),
          ),
          // Tags
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(tags.length, (i) => Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tagColors[i % tagColors.length],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(tags[i],
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            )),
          ),
        ],
      ),
    );
  }

  // ── Nearby blood banks ─────────────────────────────────────────────────────
  Widget _buildNearbyBanks() {
    if (_banks.isEmpty) {
      return _emptyBanksState();
    }

    return Column(
      children: _banks.map((b) => _bankCard(b)).toList(),
    );
  }

  Widget _emptyBanksState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'No blood banks are available right now. Pull to refresh and try again.',
        textAlign: TextAlign.center,
        style: TextStyle(color: subText),
      ),
    );
  }

  Widget _bankCard(Map<String, dynamic> b) {
    final stock    = (b['stock'] as Map?)?.cast<String, dynamic>() ?? {};
    final verified = b['isVerified'] == true;
    final phone    = b['phone']  as String? ?? '';
    final hours    = b['hours']  as String? ?? '8:00 AM – 6:00 PM';
    final city     = b['city']   as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B0000), Color(0xFFC0152A)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_hospital, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(b['name'] as String? ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: darkText),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (verified)
                          const Icon(Icons.verified, color: Color(0xFF0284C7), size: 15),
                      ]),
                      const SizedBox(height: 2),
                      Text(city.isNotEmpty ? city : (b['address'] as String? ?? ''),
                          style: const TextStyle(fontSize: 11, color: subText),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Info chips row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                _infoChip(Icons.access_time_outlined, hours, const Color(0xFF15803D)),
                const SizedBox(width: 8),
                if (phone.isNotEmpty)
                  _infoChip(Icons.phone_outlined, phone, const Color(0xFF2563EB)),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Stock pills
          if (stock.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(Icons.water_drop, color: primaryRed, size: 12),
                  const SizedBox(width: 4),
                  const Text('Stock: ', style: TextStyle(fontSize: 11, color: subText, fontWeight: FontWeight.w600)),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: stock.entries
                            .where((e) => (e.value as num? ?? 0) > 0)
                            .map((e) => Container(
                                  margin: const EdgeInsets.only(right: 5),
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFEAEA),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFFCA5A5)),
                                  ),
                                  child: Text('${e.key}: ${e.value}',
                                      style: const TextStyle(fontSize: 10, color: primaryRed, fontWeight: FontWeight.bold)),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Divider + action buttons
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BloodBankDetailsPage(bank: b),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                    icon: const Icon(Icons.bloodtype, size: 13, color: Colors.white),
                    label: const Text('Request Blood', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openBankSlot(b),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                    icon: const Icon(Icons.calendar_month_outlined, size: 13, color: subText),
                    label: const Text('Book Slot', style: TextStyle(color: subText, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                    minimumSize: Size.zero,
                  ),
                  child: const Icon(Icons.phone_outlined, size: 15, color: subText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openBankSlot(Map<String, dynamic> bank) {
    if (_bookingStatus == 'active' || _bookingStatus == 'cooling') {
      _openActiveBooking();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookHospitalSlotPage(initialVenue: bank),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Plasma/info card ───────────────────────────────────────────────────────
  Widget _buildPlasmaCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PLASMA · BURN TRAUMA',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF), letterSpacing: 0.5)),
                const SizedBox(height: 4),
                const Text('48 Units',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                const SizedBox(height: 4),
                const Text('Regional reserve at regional trauma centre.\nDonors urgently required.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF), height: 1.4)),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DonateBloodPage())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Donate Plasma', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Drive item ─────────────────────────────────────────────────────────────
  Widget _buildDriveItem({
    required String month,
    required String day,
    required String title,
    required String subtitle,
    String time    = '',
    String spots   = '',
    String address = '',
    bool   urgent  = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3))],
        border: urgent ? Border.all(color: const Color(0xFFFCA5A5)) : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B0000), Color(0xFFC0152A)],
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(month, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 9)),
                      const SizedBox(height: 2),
                      Text(day,   style: const TextStyle(color: Colors.white,   fontWeight: FontWeight.bold, fontSize: 22)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (urgent)
                        Container(
                          margin: const EdgeInsets.only(bottom: 5),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('URGENT', style: TextStyle(color: primaryRed, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      Text(title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: darkText, height: 1.3),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 5),
                      if (time.isNotEmpty)
                        Row(children: [
                          const Icon(Icons.access_time, size: 11, color: subText),
                          const SizedBox(width: 4),
                          Text(time, style: const TextStyle(fontSize: 11, color: subText)),
                        ]),
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(children: [
                          const Icon(Icons.location_on_outlined, size: 11, color: subText),
                          const SizedBox(width: 4),
                          Expanded(child: Text(address,
                              style: const TextStyle(fontSize: 11, color: subText),
                              overflow: TextOverflow.ellipsis)),
                        ]),
                      ],
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(children: [
                          const Icon(Icons.info_outline, size: 11, color: subText),
                          const SizedBox(width: 4),
                          Text(subtitle, style: const TextStyle(fontSize: 11, color: subText)),
                        ]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(
              children: [
                if (spots.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.people_outline, size: 11, color: Color(0xFF15803D)),
                      const SizedBox(width: 3),
                      Text(spots, style: const TextStyle(fontSize: 10, color: Color(0xFF15803D), fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryRed,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Register', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                  child: const Icon(Icons.share_outlined, size: 14, color: subText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section header ─────────────────────────────────────────────────────────
  Widget _sectionHeader(String title, String action, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: darkText)),
        GestureDetector(
          onTap: onTap,
          child: Text(action, style: const TextStyle(fontSize: 12, color: primaryRed, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ── Quick action data ──────────────────────────────────────────────────────────
class _QuickAction {
  final IconData icon;
  final String   label;
  final Color    color;
  final Color    bg;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.bg});
}
