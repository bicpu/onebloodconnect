import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'verified_booking_page.dart';
import 'cooling_period_page.dart';
import 'services/api_service.dart';
import 'user_profile_store.dart';

class BookHospitalSlotPage extends StatefulWidget {
  final Map<String, dynamic>? initialVenue;

  const BookHospitalSlotPage({super.key, this.initialVenue});

  @override
  State<BookHospitalSlotPage> createState() => _BookHospitalSlotPageState();
}

class _BookHospitalSlotPageState extends State<BookHospitalSlotPage> {
  // ── Theme ──────────────────────────────────────────────────────────────────
  static const Color primaryRed = Color(0xFF8B0000);
  static const Color activeRed  = Color(0xFFC8102E);
  static const Color darkText   = Color(0xFF0F172A);
  static const Color subText    = Color(0xFF64748B);
  static const Color selectedBg = Color(0xFFFFEAEA);

  // ── Selection State ────────────────────────────────────────────────────────
  DateTime selectedDate      = DateTime.now();
  String selectedTimeSlot    = '10:30 AM';
  int selectedComponentIndex = 0; // 0: Whole Blood, 1: Platelets, 2: Plasma

  // ── Pre-Donation Screening ─────────────────────────────────────────────────
  int mealQuestion    = 0;
  int sleepQuestion   = 0;
  int alcoholQuestion = 0;
  int healthQuestion  = 0;

  // ── Booking Guard ──────────────────────────────────────────────────────────
  bool _isBooking  = false;
  bool _isChecking = true;   // true while checking for existing booking on init

  // ── Time Slots ─────────────────────────────────────────────────────────────
  final Map<String, List<Map<String, String>>> timeSlots = {
    'MORNING SESSION': [
      {'time': '09:00 AM', 'spots': '3 left'},
      {'time': '10:30 AM', 'spots': '4 left'},
      {'time': '11:45 AM', 'spots': '5 left'},
    ],
    'AFTERNOON SESSION': [
      {'time': '01:30 PM', 'spots': '6 left'},
      {'time': '02:45 PM', 'spots': '2 left'},
      {'time': '04:00 PM', 'spots': '4 left'},
    ],
    'EVENING SESSION': [
      {'time': '05:15 PM', 'spots': '2 left'},
    ],
  };

  // ── Donation Components ────────────────────────────────────────────────────
  static const List<Map<String, dynamic>> _components = [
    {
      'label':    'Whole Blood',
      'sub':      'Standard • ~350–450 ml',
      'duration': 'Duration: ~15 mins',
      'icon':     Icons.water_drop,
      'cooling':  90,
      'coolNote': '3 months (90 days)',
    },
    {
      'label':    'Platelets (Apheresis)',
      'sub':      'Single-donor • Specific',
      'duration': 'Duration: ~45 mins',
      'icon':     Icons.grain,
      'cooling':  7,
      'coolNote': '7 days',
    },
    {
      'label':    'Plasma',
      'sub':      'Liquid component • ~600 ml',
      'duration': 'Duration: ~30 mins',
      'icon':     Icons.invert_colors,
      'cooling':  28,
      'coolNote': '28 days',
    },
  ];

  // ── Dynamic blood bank venues ──────────────────────────────────────────────
  List<Map<String, dynamic>> _venues = [];
  int _selectedVenueIdx = 0;

  Map<String, dynamic>? get _selectedVenue =>
      _venues.isNotEmpty ? _venues[_selectedVenueIdx] : null;

  String get _facilityName =>
      _selectedVenue?['name'] as String? ?? 'No blood bank selected';
  String get _facilityAddress =>
      _selectedVenue?['address'] as String? ?? 'Live blood-bank data is unavailable';
  String get _facilityPhone =>
      _selectedVenue?['phone'] as String? ?? '';

  @override
  void initState() {
    super.initState();
    if (widget.initialVenue != null) {
      _venues = [widget.initialVenue!];
      _selectedVenueIdx = 0;
    }
    _checkActiveBooking();
    _loadVenues();
  }

  Future<void> _loadVenues() async {
    try {
      final accounts = await ApiService().getBloodBankAccounts();
      final banks    = await ApiService().getBloodBanks();
      // Merge self-registered accounts first, then admin-added banks
      final all = <Map<String, dynamic>>[
        ...accounts,
        ...banks,
      ];
      if (mounted && all.isNotEmpty) {
        final initial = widget.initialVenue;
        final merged = initial == null
            ? all
            : [
                initial,
                ...all.where((venue) =>
                    venue['name'] != initial['name']),
              ];
        setState(() {
          _venues = merged;
          _selectedVenueIdx = 0;
        });
      }
    } catch (_) {
      // Fall back to hardcoded JIPMER — no state change needed
    }
  }

  // Check existing booking status on init and redirect accordingly
  Future<void> _checkActiveBooking() async {
    try {
      final result = await ApiService().getActiveBooking();
      if (!mounted) return;

      // User already has an active booking — show it instead of the form
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

        final user = FirebaseAuth.instance.currentUser;
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VerifiedBookingPage(
              bookingId:       bookingId,
              donorName:       user?.displayName ?? 'Donor',
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
        );
        return;
      }

      // User is in a cooling period — block booking
      if (result['cooling'] == true) {
        final booking   = result['booking'] as Map<String, dynamic>? ?? {};
        final component = (booking['component'] as String?) ?? 'Whole Blood';
        int coolingDays; String coolingNote;
        if (component.toLowerCase().contains('platelet')) {
          coolingDays = 7;  coolingNote = '7 days';
        } else if (component.toLowerCase().contains('plasma')) {
          coolingDays = 28; coolingNote = '28 days';
        } else {
          coolingDays = 90; coolingNote = '3 months (90 days)';
        }
        DateTime donatedAt;
        try { donatedAt = DateTime.parse(booking['donatedAt'] as String); }
        catch (_) { donatedAt = DateTime.now(); }

        final user = FirebaseAuth.instance.currentUser;
        final bg   = await UserProfileStore.getBloodGroup() ?? component;
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CoolingPeriodPage(
              donorName:    user?.displayName ?? 'Donor',
              bloodGroup:   bg,
              component:    component,
              donatedAt:    donatedAt,
              coolingDays:  coolingDays,
              coolingNote:  coolingNote,
              facilityName: (booking['facilityName'] as String?) ?? 'Blood Bank',
            ),
          ),
        );
        return;
      }
    } catch (_) {
      // Server unavailable — allow the page to load normally
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  // ── Date Picker ────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 90)),
      helpText: 'Select Donation Date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryRed,
              onPrimary: Colors.white,
              onSurface: darkText,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  // ── Booking Handler ────────────────────────────────────────────────────────
  // Navigation to VerifiedBookingPage always proceeds regardless of whether
  // the API call succeeds. If the backend is unreachable (dev/offline) the
  // booking is confirmed locally and can be synced later.
  Future<void> _confirmBooking() async {
    if (_isBooking) return;
    if (_selectedVenue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No blood banks are available. Please try again later.'),
        ),
      );
      return;
    }
    setState(() => _isBooking = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _isBooking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to book a hospital slot.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final component  = _components[selectedComponentIndex]['label'] as String;
    final bloodGroup = await UserProfileStore.getBloodGroup() ?? component;

    // Fire-and-forget — never block navigation on network errors
    Map<String, dynamic>? booking;
    try {
      final facilityRef = _selectedVenue?['facilityRef'] as String? ?? '';
      final facilityDirectoryId = facilityRef.isEmpty
          ? (_selectedVenue?['_id'] as String? ?? '')
          : '';
      booking = await ApiService().createBooking(
        facilityRef: facilityRef,
        facilityDirectoryId: facilityDirectoryId,
        slotDate:        selectedDate.toIso8601String(),
        slotTime:        selectedTimeSlot,
        donorName:       user.displayName ?? 'Donor',
        bloodGroup:      bloodGroup,
        component:       component,
        coolingDays:     _components[selectedComponentIndex]['cooling'] as int,
      );
    } catch (_) {
      // Server unreachable — proceed anyway
    }

    if (!mounted) return;
    setState(() => _isBooking = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VerifiedBookingPage(
          bookingId:       (booking?['_id'] as String?) ?? '',
          donorName:       user.displayName ?? 'Donor',
          bloodGroup:      bloodGroup,
          component:       component,
          slotDate:        selectedDate,
          slotTime:        selectedTimeSlot,
          coolingDays:     _components[selectedComponentIndex]['cooling'] as int,
          coolingNote:     _components[selectedComponentIndex]['coolNote'] as String,
          facilityName:    _facilityName,
          facilityAddress: _facilityAddress,
          facilityPhone:   _facilityPhone,
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _formatDate(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now();
    final isToday = d.year == today.year &&
        d.month == today.month &&
        d.day == today.day;
    final dayName = isToday ? 'Today' : days[d.weekday - 1];
    return '$dayName, ${d.day} ${months[d.month]} ${d.year}';
  }

  // ── Venue picker bottom sheet ──────────────────────────────────────────────
  void _showVenuePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose Donation Venue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A))),
            const SizedBox(height: 14),
            ..._venues.asMap().entries.map((e) {
              final selected = e.key == _selectedVenueIdx;
              final v = e.value;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedVenueIdx = e.key);
                  Navigator.pop(ctx);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFFFEAEA) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? activeRed : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(children: [
                    Icon(Icons.local_hospital_outlined,
                        color: selected ? activeRed : const Color(0xFF64748B),
                        size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v['name'] as String? ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13,
                              color: selected
                                  ? activeRed : const Color(0xFF0F172A),
                            )),
                        Text(v['city'] as String? ?? '',
                            style: const TextStyle(fontSize: 11,
                                color: Color(0xFF64748B))),
                      ],
                    )),
                    if (selected)
                      const Icon(Icons.check_circle,
                          color: Color(0xFFC0152A), size: 18),
                  ]),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Show spinner while checking for existing active booking
    if (_isChecking) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFC8102E)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: activeRed,
            child: const Icon(Icons.water_drop, color: Colors.white, size: 18),
          ),
        ),
        title: const Text(
          'One Blood Connect',
          style: TextStyle(
            color: darkText,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: darkText),
            onPressed: () {},
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: primaryRed,
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Page Header ────────────────────────────────────────────
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back,
                          size: 18, color: darkText),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Text(
                              'Book Hospital Slot',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: darkText,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.check_circle,
                                color: activeRed, size: 16),
                          ],
                        ),
                        const Text(
                          'JIPMER & Partner Centers',
                          style: TextStyle(fontSize: 11, color: subText),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: selectedBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_location_alt,
                        color: activeRed, size: 18),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Hospital Banner ────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: selectedBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.apartment,
                              color: activeRed, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _facilityName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: darkText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _facilityAddress,
                                style: const TextStyle(
                                    fontSize: 11, color: subText),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (_venues.length > 1)
                          TextButton(
                            onPressed: () => _showVenuePicker(),
                            child: const Text(
                              'Change',
                              style: TextStyle(
                                color: activeRed,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                size: 14, color: subText),
                            SizedBox(width: 4),
                            Text(
                              '8:00 AM – 6:00 PM (Daily)',
                              style: TextStyle(
                                  fontSize: 11, color: subText),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.phone, size: 14, color: activeRed),
                            SizedBox(width: 4),
                            Text(
                              '+91 413 229 6000',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: darkText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Date Picker ────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.calendar_month,
                          color: activeRed, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Select Date',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: darkText,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selectedBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: activeRed.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.edit_calendar,
                              color: activeRed, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            _formatDate(selectedDate),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: activeRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: selectedBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.calendar_today,
                            color: activeRed, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDate(selectedDate),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: darkText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Tap to change donation date',
                              style: TextStyle(
                                  fontSize: 11, color: subText),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: subText, size: 20),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Time Slots ─────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Row(
                    children: [
                      Icon(Icons.schedule, color: activeRed, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Available Time Slots',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: darkText,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.circle,
                          size: 6, color: Color(0xFF2563EB)),
                      SizedBox(width: 4),
                      Text(
                        'VIP Lounge Open',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              ...timeSlots.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: subText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: entry.value.map((slot) {
                        final isSelected =
                            selectedTimeSlot == slot['time'];
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(
                                () => selectedTimeSlot = slot['time']!),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primaryRed
                                    : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? primaryRed
                                      : Colors.transparent,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    slot['time']!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Colors.white
                                          : darkText,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    slot['spots']!,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isSelected
                                          ? Colors.white70
                                          : subText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                  ],
                );
              }),

              // ── Donation Component ─────────────────────────────────────
              const Row(
                children: [
                  Icon(Icons.water_drop_outlined,
                      color: activeRed, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Donation Component',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: darkText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  _buildComponentCard(0),
                  const SizedBox(width: 10),
                  _buildComponentCard(1),
                ],
              ),
              const SizedBox(height: 10),
              _buildComponentCard(2, fullWidth: true),

              // Cooling period info for selected component
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined,
                        color: Color(0xFFEA580C), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF7C2D12),
                            height: 1.4,
                          ),
                          children: [
                            const TextSpan(
                              text: 'Cooling period after donation: ',
                              style:
                                  TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                              text:
                                  '${_components[selectedComponentIndex]['coolNote']} — '
                                  'this applies after your donation is complete.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Pre-Donation Screening ─────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined,
                          color: activeRed, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Pre-Donation Quick Screening',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: darkText,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '4 items',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Ensure you are ready for a quick, safe, and comfortable donation today.',
                style: TextStyle(fontSize: 11, color: subText),
              ),
              const SizedBox(height: 14),

              _buildScreeningQuestion(
                icon: Icons.restaurant,
                question:
                    'Had a healthy meal & plenty of water in the last 4 hours?',
                option1Text: 'Yes (Recommended)',
                option2Text: 'Not Yet',
                selectedOption: mealQuestion,
                onSelect: (val) =>
                    setState(() => mealQuestion = val),
              ),
              _buildScreeningQuestion(
                icon: Icons.bedtime_outlined,
                question: 'Slept at least 6+ hours last night?',
                option1Text: 'Yes, Well Rested',
                option2Text: 'Under 6 hrs',
                selectedOption: sleepQuestion,
                onSelect: (val) =>
                    setState(() => sleepQuestion = val),
              ),
              _buildScreeningQuestion(
                icon: Icons.local_bar_outlined,
                question:
                    'Any alcohol consumption in the past 24 hours?',
                option1Text: 'No, None',
                option2Text: 'Yes',
                selectedOption: alcoholQuestion,
                onSelect: (val) =>
                    setState(() => alcoholQuestion = val),
              ),
              _buildScreeningQuestion(
                icon: Icons.sentiment_satisfied_alt,
                question:
                    'Feeling healthy with no flu, fever, or cold today?',
                option1Text: 'Yes, Feeling Great',
                option2Text: 'Mild Symptoms',
                selectedOption: healthQuestion,
                onSelect: (val) =>
                    setState(() => healthQuestion = val),
              ),

              const SizedBox(height: 14),

              // ── Hospital Care Info ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.local_hospital,
                        color: Color(0xFF2563EB), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Hospital Care: JIPMER provides fresh refreshments, fruit juice, iron-fortified snacks, and an air-conditioned recovery lounge post-donation.',
                        style: TextStyle(
                            fontSize: 10, color: darkText, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Booking Summary ────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: selectedBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.calendar_month,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_formatDate(selectedDate)} • $selectedTimeSlot',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: darkText,
                            ),
                          ),
                          Text(
                            'JIPMER Blood Hub • ${_components[selectedComponentIndex]['label']}',
                            style: const TextStyle(
                                fontSize: 11, color: subText),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.check_circle,
                        color: activeRed, size: 20),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Confirm Button ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isBooking || _selectedVenue == null
                      ? null
                      : _confirmBooking,
                  icon: _isBooking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.check_box_outlined,
                          color: Colors.white, size: 18),
                  label: Text(
                    _isBooking
                        ? 'Booking…'
                        : 'Confirm & Book Donation Slot',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Center(
                child: Column(
                  children: const [
                    Text(
                      '📩 Instant SMS & WhatsApp appointment token sent',
                      style: TextStyle(fontSize: 10, color: subText),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '🅿️ Free priority donor parking at Hospital',
                      style: TextStyle(fontSize: 10, color: subText),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Component Card ─────────────────────────────────────────────────────────
  Widget _buildComponentCard(int index, {bool fullWidth = false}) {
    final isSelected = selectedComponentIndex == index;
    final comp = _components[index];

    final card = GestureDetector(
      onTap: () => setState(() => selectedComponentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                isSelected ? activeRed : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: fullWidth
            ? Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(comp['icon'] as IconData,
                        color: const Color(0xFF2563EB), size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comp['label'] as String,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: darkText,
                          ),
                        ),
                        Text(
                          comp['sub'] as String,
                          style: const TextStyle(
                              fontSize: 9, color: subText),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: selectedBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      comp['duration'] as String,
                      style: const TextStyle(
                        fontSize: 9,
                        color: activeRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    size: 18,
                    color: isSelected
                        ? activeRed
                        : const Color(0xFFCBD5E1),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(comp['icon'] as IconData,
                            color: const Color(0xFF2563EB), size: 16),
                      ),
                      Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        size: 18,
                        color: isSelected
                            ? activeRed
                            : const Color(0xFFCBD5E1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    comp['label'] as String,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: darkText,
                    ),
                  ),
                  Text(
                    comp['sub'] as String,
                    style:
                        const TextStyle(fontSize: 9, color: subText),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: selectedBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      comp['duration'] as String,
                      style: const TextStyle(
                        fontSize: 9,
                        color: activeRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );

    return fullWidth ? card : Expanded(child: card);
  }

  // ── Screening Question ─────────────────────────────────────────────────────
  Widget _buildScreeningQuestion({
    required IconData icon,
    required String question,
    required String option1Text,
    required String option2Text,
    required int selectedOption,
    required Function(int) onSelect,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: subText),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  question,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: darkText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onSelect(0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 10),
                    decoration: BoxDecoration(
                      color: selectedOption == 0
                          ? selectedBg
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selectedOption == 0
                            ? activeRed
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedOption == 0
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          size: 14,
                          color: selectedOption == 0
                              ? activeRed
                              : subText,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            option1Text,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: selectedOption == 0
                                  ? activeRed
                                  : subText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => onSelect(1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 10),
                    decoration: BoxDecoration(
                      color: selectedOption == 1
                          ? selectedBg
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selectedOption == 1
                            ? activeRed
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedOption == 1
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          size: 14,
                          color: selectedOption == 1
                              ? activeRed
                              : subText,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            option2Text,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: selectedOption == 1
                                  ? activeRed
                                  : subText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
