import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'verified_booking_page.dart';
import 'donation_processing_page.dart';
import 'donor_venue_preference_page.dart';
import 'widgets/floating_nav.dart';
import 'services/api_service.dart';
import 'user_profile_store.dart';

class DonateBloodPage extends StatefulWidget {
  const DonateBloodPage({super.key});

  @override
  State<DonateBloodPage> createState() => _DonateBloodPageState();
}

class _DonateBloodPageState extends State<DonateBloodPage> {
  // Primary Theme Colors
  static const primaryRed = Color(0xFF8B0000);
  static const darkRed = Color(0xFF6B0000);
  static const lightBg = Color(0xFFF8FAFC);

  // Interactive States
  String selectedBloodGroup = 'O+';
  String selectedStream = 'Whole Blood';

  // Pre-Screening Responses (Key: Question Index, Value: true for Yes, false for No)
  final Map<int, bool> preScreeningAnswers = {
    0: true, // Age & Weight
    1: false, // Recent Donation
    2: false, // Active Medications
    3: false, // Tattoo or Surgery
    4: true, // Current Wellness
  };

  // Venue Selection State ('hospital' or 'mobile')
  String selectedVenueType = 'hospital';
  String selectedTimeSlot = 'Today • 2:30 PM';

  // Ready-to-donate states
  bool readyAnyTime = false; // user willing to donate any upcoming days
  bool showToOthers = false; // show donor availability to others

  // Recent donation details (when user marks recent donation)
  DateTime? lastDonationDateDetailed;
  int? lastDonationUnits;

  // Confirmation Checkboxes
  bool confirmHydrated = true;
  bool confirmConsent = true;

  // Bottom Navigation Index
  int selectedBottomNavIndex = 2; // Donate tab

  // Temporary on-screen debug message
  String _debugMessage = '';

  // Loading state while checking booking status on init
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkDonorStatus();
  }

  /// Redirects to VerifiedBookingPage if there's an active booking,
  /// CoolingPeriodPage if in a cooling period, otherwise stays here.
  Future<void> _checkDonorStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isChecking = false);
      return;
    }

    try {
      final result = await ApiService().getActiveBooking();
      if (!mounted) return;

      if (result['active'] == true) {
        final booking    = result['booking'] as Map<String, dynamic>? ?? {};
        final component  = (booking['component'] as String?) ?? 'Whole Blood';
        final bookingId  = (booking['_id'] as String?) ?? '';
        final bloodGroup = await UserProfileStore.getBloodGroup() ?? component;

        int coolingDays; String coolingNote;
        if (component.toLowerCase().contains('platelet')) {
          coolingDays = 7;  coolingNote = '7 days';
        } else if (component.toLowerCase().contains('plasma')) {
          coolingDays = 28; coolingNote = '28 days';
        } else {
          coolingDays = 90; coolingNote = '3 months (90 days)';
        }

        DateTime slotDate;
        try { slotDate = DateTime.parse(booking['slotDate'] as String); }
        catch (_) { slotDate = DateTime.now(); }

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => VerifiedBookingPage(
              bookingId:       bookingId,
              donorName:       user.displayName ?? 'Donor',
              bloodGroup:      bloodGroup,
              component:       component,
              slotDate:        slotDate,
              slotTime:        (booking['slotTime'] as String?) ?? '',
              coolingDays:     coolingDays,
              coolingNote:     coolingNote,
              facilityName:    (booking['facilityName'] as String?) ?? 'Blood Bank',
              facilityAddress: (booking['facilityAddress'] as String?) ?? '',
              facilityPhone:   (booking['facilityPhone'] as String?) ?? '',
            ),
          ),
          (route) => route.isFirst,
        );
        return;
      }

      if (result['cooling'] == true) {
        final booking    = result['booking'] as Map<String, dynamic>? ?? {};
        final bookingId  = (booking['_id'] as String?) ?? '';
        final component  = (booking['component'] as String?) ?? 'Whole Blood';
        final bloodGroup = await UserProfileStore.getBloodGroup() ?? component;

        int coolingDays;
        if (component.toLowerCase().contains('platelet')) {
          coolingDays = 7;
        } else if (component.toLowerCase().contains('plasma')) {
          coolingDays = 28;
        } else {
          coolingDays = 90;
        }

        DateTime donatedAt;
        try { donatedAt = DateTime.parse(booking['donatedAt'] as String); }
        catch (_) { donatedAt = DateTime.now(); }

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => DonationProcessingPage(
              bookingId:    bookingId,
              donorName:    user.displayName ?? 'Donor',
              bloodGroup:   bloodGroup,
              component:    component,
              donatedAt:    donatedAt,
              coolingDays:  coolingDays,
              facilityName: (booking['facilityName'] as String?) ?? 'Blood Bank',
            ),
          ),
          (route) => route.isFirst,
        );
        return;
      }

      if (result['pending'] == true) {
        final booking = result['booking'] as Map<String, dynamic>? ?? {};
        final component = (booking['component'] as String?) ?? 'Whole Blood';
        final bookingId = (booking['_id'] as String?) ?? '';
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DonationProcessingPage(
              bookingId: bookingId,
              donorName: user.displayName ?? 'Donor',
              bloodGroup: (booking['bloodGroup'] as String?) ?? '',
              component: component,
              donatedAt: DateTime.tryParse(
                    booking['donatedAt'] as String? ?? '') ??
                  DateTime.now(),
              coolingDays: (booking['coolingDays'] as num?)?.toInt() ?? 90,
              facilityName: (booking['facilityName'] as String?) ?? 'Blood Bank',
            ),
          ),
        );
        return;
      }

      if (result['needsAction'] == true || result['appealed'] == true) {
        final booking = result['booking'] as Map<String, dynamic>? ?? {};
        final bookingId = (booking['_id'] as String?) ?? '';
        final component = (booking['component'] as String?) ?? 'Whole Blood';
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DonationProcessingPage(
              bookingId: bookingId,
              donorName: user.displayName ?? 'Donor',
              bloodGroup: (booking['bloodGroup'] as String?) ?? '',
              component: component,
              donatedAt: DateTime.tryParse(
                    booking['donatedAt'] as String? ?? '') ??
                  DateTime.now(),
              coolingDays: (booking['coolingDays'] as num?)?.toInt() ?? 90,
              facilityName: (booking['facilityName'] as String?) ?? 'Blood Bank',
            ),
          ),
        );
        return;
      }

      // ── Already a registered donor ──────────────────────────────────────
      // Skip the registration form entirely and go straight to the venue/slot
      // booking flow. The user only needs to fill the form once.
      final donor = await ApiService().getMyDonorProfile();
      if (!mounted) return;
      if (donor['registered'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DonorVenuePreferencePage()),
        );
        return;
      }
    } catch (_) {
      // Server unavailable or network error — show DonateBloodPage normally
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  // Helper: save donor availability and recent donation details via API
  Future<void> _saveDonorAvailabilityToApi() async {
    try {
      final fields = <String, dynamic>{
        'readyAnyTime':  readyAnyTime,
        'preferredVenue': selectedVenueType,
        'showToOthers':  showToOthers,
        'bloodGroup':    selectedBloodGroup,
      };
      if (lastDonationDateDetailed != null) {
        fields['lastDonationDate'] = lastDonationDateDetailed!.toIso8601String();
      }
      if (lastDonationUnits != null) {
        fields['lastDonationUnits'] = lastDonationUnits;
      }
      await ApiService().updateDonorProfile(fields);
    } catch (e) {
      // ignore errors silently — same behaviour as before
    }
  }

  // When user marks Recent Donation = Yes, prompt for date and units
  Future<void> _promptLastDonationDetails() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 90)),
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    if (!mounted) return;

    final unitsStr = await showDialog<String?>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: '1');
        return AlertDialog(
          title: const Text('Units donated'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Enter number of units donated',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    if (unitsStr == null) return;
    final units = int.tryParse(unitsStr) ?? 0;
    setState(() {
      lastDonationDateDetailed = picked;
      lastDonationUnits = units > 0 ? units : null;
      preScreeningAnswers[1] = true;
    });

    // persist via API
    await _saveDonorAvailabilityToApi();
  }

  @override
  Widget build(BuildContext context) {
    // Show spinner while checking booking/cooling status —
    // prevents the registration form from flashing before redirect
    if (_isChecking) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF8B0000)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFFFEAEA),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.water_drop, color: primaryRed, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'One Blood Connect',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'LIFESAVER PORTAL',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: Color(0xFF475569),
                  size: 24,
                ),
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: primaryRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {},
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0, left: 4.0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey.shade200,
              child: const Icon(
                Icons.person,
                color: Color(0xFF64748B),
                size: 20,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _debugMessage.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => setState(() => _debugMessage = ''),
              backgroundColor: Colors.black87,
              icon: const Icon(Icons.bug_report, color: Colors.white),
              label: Text(
                _debugMessage.length > 40 ? '${_debugMessage.substring(0, 40)}...' : _debugMessage,
                style: const TextStyle(color: Colors.white),
              ),
            )
          : null,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(
                bottom: 110,
                left: 16.0,
                right: 16.0,
                top: 12.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Badge & Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.circle, size: 8, color: primaryRed),
                          SizedBox(width: 6),
                          Text(
                            'LIVE CAMPUS REGISTRY',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: primaryRed,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.shield, size: 12, color: primaryRed),
                            SizedBox(width: 4),
                            Text(
                              'Tier 1 Donor',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),
                  const Text(
                    'Donate Blood',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const Text(
                    'Pondicherry University Lifesaver Network',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),

                  const SizedBox(height: 14),

                  // Active Donor Mission Banner
                  _buildMissionBanner(),

                  const SizedBox(height: 20),

                  // 1. Select Blood Group Section
                  _buildBloodGroupSelection(),

                  const SizedBox(height: 20),

                  // 2. Donation Stream Section
                  _buildDonationStreamSelection(),

                  const SizedBox(height: 20),

                  // 3. Health Pre-Screening Section
                  _buildPreScreeningSection(),

                  const SizedBox(height: 20),

                  // Ready Any Time Section
                  _buildReadyAnyTimeSection(),
                  const SizedBox(height: 12),

                  // 5. Ready to Donate Section & Confirmation
                  _buildReadyToDonateSection(),

                  const SizedBox(height: 20),
                ],
              ),
            ),

            Positioned(
              left: 20,
              right: 20,
              bottom: 16,
              child: FloatingNav(selectedIndex: selectedBottomNavIndex),
            ),
          ],
        ),
      ),
    );
  }

  // Active Donor Mission Banner
  Widget _buildMissionBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryRed, darkRed],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryRed.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Active Donor Mission',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Row(
                children: const [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.white,
                    size: 14,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Eligible Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'You can save up to 3 lives today',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pondicherry University Health Centre urgently requires O+ and B+ units for regional emergency reserves.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 60,
                height: 22,
                child: Stack(
                  children: const [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: Colors.white,
                      child: Text(
                        'O+',
                        style: TextStyle(
                          fontSize: 8,
                          color: primaryRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: Colors.amber,
                        child: Text(
                          'B+',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 28,
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: Colors.white,
                        child: Text(
                          'A+',
                          style: TextStyle(
                            fontSize: 8,
                            color: primaryRed,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '18 students donated in the last 3 hours',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 1. Select Blood Group Grid
  Widget _buildBloodGroupSelection() {
    final groups = [
      {'type': 'A+', 'sub': '4 Units req'},
      {'type': 'A-', 'sub': 'Rare', 'highlight': true},
      {'type': 'B+', 'sub': '8 Units req'},
      {'type': 'B-', 'sub': 'Critical', 'critical': true},
      {'type': 'O+', 'sub': 'Universal+'},
      {'type': 'O-', 'sub': 'Urgent', 'critical': true},
      {'type': 'AB+', 'sub': 'Plasma req'},
      {'type': 'AB-', 'sub': 'Specialized'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'Select Blood Group',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              'Verify Type',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: primaryRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        const Text(
          'Tap your certified ABO/Rh blood type.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: groups.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.15,
          ),
          itemBuilder: (context, index) {
            final group = groups[index];
            final typeStr = group['type'] as String;
            final isSelected = selectedBloodGroup == typeStr;
            final isCritical = group['critical'] == true;
            final isHighlight = group['highlight'] == true;

            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedBloodGroup = typeStr;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected ? primaryRed : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? primaryRed
                        : (isCritical
                              ? primaryRed.withValues(alpha: 0.5)
                              : const Color(0xFFE2E8F0)),
                    width: isSelected || isCritical ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      typeStr,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.2)
                            : (isHighlight
                                  ? Colors.amber.shade100
                                  : (isCritical
                                        ? const Color(0xFFFFEAEA)
                                        : Colors.transparent)),

                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        group['sub'] as String,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : (isCritical
                                    ? primaryRed
                                    : (isHighlight
                                          ? Colors.amber.shade900
                                          : const Color(0xFF64748B))),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // 2. Donation Stream Options
  Widget _buildDonationStreamSelection() {
    final streams = [
      {
        'title': 'Whole Blood',
        'sub': 'Standard 450ml',
        'time': 'Most Requested',
        'isTag': true,
      },
      {
        'title': 'Platelets',
        'sub': 'Apheresis separation',
        'time': 'Takes 70 mins',
      },
      {
        'title': 'Plasma',
        'sub': 'Burns & trauma care',
        'time': 'Takes 45 mins',
      },
      {
        'title': 'Power Red',
        'sub': 'Double RBC collection',
        'time': 'Surgery units',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DONATION STREAM',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF94A3B8),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: streams.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.6,
          ),
          itemBuilder: (context, index) {
            final stream = streams[index];
            final title = stream['title'] as String;
            final isSelected = selectedStream == title;

            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedStream = title;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? primaryRed : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          size: 16,
                          color: isSelected
                              ? primaryRed
                              : const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                    Text(
                      stream['sub'] as String,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    stream['isTag'] == true
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEAEA),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Most Requested',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: primaryRed,
                              ),
                            ),
                          )
                        : Text(
                            stream['time'] as String,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // 3. Health Pre-Screening Section
  Widget _buildPreScreeningSection() {
    final questions = [
      {
        'title': 'Age & Weight Threshold',
        'sub': 'Age 18-65 yrs, Weight > 50 kg',
      },
      {'title': 'Recent Donation', 'sub': 'Within 90 days cooldown period'},
      {
        'title': 'Active Medications',
        'sub': 'Antibiotics, blood thinners in 14 days',
      },
      {'title': 'Tattoo or Minor Surgery', 'sub': 'In past 6 months'},
      {'title': 'Current Wellness', 'sub': 'No fever, cold, or active illness'},
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.location_on, color: primaryRed, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Health Pre-Screening',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEAEA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '5 Vitals',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: primaryRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: questions.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 16, color: Color(0xFFF1F5F9)),
            itemBuilder: (context, index) {
              final q = questions[index];
              final isYes = preScreeningAnswers[index] == true;

              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          q['title']!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          q['sub']!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Yes / No Toggle Buttons
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            if (index == 1) {
                              // Recent Donation -> prompt for date and units
                              await _promptLastDonationDetails();
                            } else {
                              setState(() {
                                preScreeningAnswers[index] = true;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isYes
                                  ? (index == 1 || index == 2 || index == 3
                                        ? primaryRed
                                        : const Color(0xFF10B981))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Yes',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isYes
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              preScreeningAnswers[index] = false;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: !isYes
                                  ? (index == 1 || index == 2 || index == 3
                                        ? const Color(0xFF10B981)
                                        : primaryRed)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'No',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: !isYes
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.info_outline, size: 14, color: Color(0xFF94A3B8)),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Standard non-invasive vitals & hemoglobin check conducted on-site.',
                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _registerDonorAndContinue() async {
    try {
      if (mounted) setState(() => _debugMessage = 'Registering donor...');
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Cache registration locally so we skip the API check next time
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('donor_registered_${user.uid}', true);
        await prefs.setString('donor_name_${user.uid}', user.displayName ?? 'Donor');
        await prefs.setString('donor_bloodGroup_${user.uid}', selectedBloodGroup);

        // Register via REST API → persisted in MongoDB
        await ApiService().registerDonor(
          bloodGroup:          selectedBloodGroup,
          donationStream:      selectedStream,
          preScreeningAnswers: preScreeningAnswers,
          readyAnyTime:        readyAnyTime,    // use actual toggle value
          showToOthers:        showToOthers,    // use actual toggle value
          lastDonationDate:    lastDonationDateDetailed,
          lastDonationUnits:   lastDonationUnits,
        );

        if (mounted) setState(() => _debugMessage = 'Donor registered');
      }

      // Keep the toggle values the user actually chose — do not override them.

      if (mounted) setState(() => _debugMessage = 'Saving availability...');
      await _saveDonorAvailabilityToApi();
      if (mounted) setState(() => _debugMessage = 'Saved availability');
    } catch (e) {
      if (mounted) setState(() => _debugMessage = 'Registration failed: ${e.toString()}');
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const DonorVenuePreferencePage()),
    );
  }

  Widget _buildTimeSlotChip(String time) {
    final isSelected = selectedTimeSlot == time;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTimeSlot = time;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryRed : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? primaryRed : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          time,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  // 5. Ready to Donate & Confirmation Checkboxes
  Widget _buildReadyToDonateSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Row(
                children: [
                  Icon(Icons.check_circle_outline, color: primaryRed, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Ready to Donate?',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Text(
                'Final Step',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3 Prep Items
          Row(
            children: [
              _buildPrepItem(
                Icons.water_drop_outlined,
                '500ml Water',
                'Hydration',
              ),
              const SizedBox(width: 8),
              _buildPrepItem(Icons.restaurant, 'Meal in 4h', 'Nutrition'),
              const SizedBox(width: 8),
              _buildPrepItem(
                Icons.badge_outlined,
                'Photo / PU ID',
                'Verification',
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Checkbox 1
          GestureDetector(
            onTap: () {
              setState(() {
                confirmHydrated = !confirmHydrated;
              });
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: confirmHydrated,
                    activeColor: primaryRed,
                    onChanged: (val) {
                      setState(() {
                        confirmHydrated = val ?? false;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'I confirm I am well-hydrated, rested, and feel fit to donate blood.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF334155),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Checkbox 2
          GestureDetector(
            onTap: () {
              setState(() {
                confirmConsent = !confirmConsent;
              });
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: confirmConsent,
                    activeColor: primaryRed,
                    onChanged: (val) {
                      setState(() {
                        confirmConsent = val ?? false;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'I agree to the Pondicherry University Lifesaver Network safety protocol and HIPAA-compliant data consent.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF334155),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Confirm & Ready Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmHydrated && confirmConsent
                    ? primaryRed
                    : Colors.grey.shade400,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: confirmHydrated && confirmConsent ? 2 : 0,
              ),
              onPressed: confirmHydrated && confirmConsent
                  ? _registerDonorAndContinue
                  : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.favorite, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Confirm & I am Ready to Donate',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.lock_outline, size: 12, color: Color(0xFF94A3B8)),
                SizedBox(width: 4),
                Text(
                  'Sanitised & Encrypted Medical Data • HIPAA Compliant',
                  style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrepItem(IconData icon, String title, String sub) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: primaryRed),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              sub,
              style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadyAnyTimeSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ready to donate (Optional)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'If you are available to donate in the upcoming days, mark yourself available so other users can find you. Venue is optional — keep it off if you are flexible.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Switch(
                value: readyAnyTime,
                activeThumbColor: primaryRed,
                onChanged: (v) async {
                  setState(() => readyAnyTime = v);
                  await _saveDonorAvailabilityToApi();
                },
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('I am ready to donate in the upcoming days'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: showToOthers,
                activeColor: primaryRed,
                onChanged: (v) async {
                  setState(() => showToOthers = v ?? false);
                  await _saveDonorAvailabilityToApi();
                },
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Show my availability to other users (Nearby donors & banks)',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
        ),
      ],
    );
  }
}
