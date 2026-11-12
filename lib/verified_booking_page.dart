import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'donation_complete_page.dart';
import 'widgets/floating_nav.dart';
import 'services/api_service.dart';
import 'donation_decision_page.dart';

class VerifiedBookingPage extends StatefulWidget {
  final String bookingId;      // MongoDB _id — needed to call /complete
  final String proofStatus;
  final String donorName;
  final String bloodGroup;
  final String component;
  final DateTime slotDate;
  final String slotTime;
  final int coolingDays;
  final String coolingNote;
  final String facilityName;
  final String facilityAddress;
  final String facilityPhone;

  const VerifiedBookingPage({
    super.key,
    this.bookingId = '',       // empty when navigated from dashboard fallback
    this.proofStatus = 'not_submitted',
    required this.donorName,
    required this.bloodGroup,
    required this.component,
    required this.slotDate,
    required this.slotTime,
    required this.coolingDays,
    required this.coolingNote,
    required this.facilityName,
    required this.facilityAddress,
    required this.facilityPhone,
  });

  @override
  State<VerifiedBookingPage> createState() => _VerifiedBookingPageState();
}

class _VerifiedBookingPageState extends State<VerifiedBookingPage> {
  // ── Brand palette ──────────────────────────────────────────────────────────
  static const Color primaryRed  = Color(0xFF8B0000);
  static const Color activeRed   = Color(0xFFC8102E);
  static const Color darkText    = Color(0xFF0F172A);
  static const Color subText     = Color(0xFF64748B);
  static const Color lightBg     = Color(0xFFF8FAFC);
  static const Color softRedBg   = Color(0xFFFFEAEA);
  static const Color softBlueBg  = Color(0xFFEFF6FF);
  static const Color primaryBlue = Color(0xFF2563EB);

  // ── UI state ───────────────────────────────────────────────────────────────
  bool isCopied          = false;
  bool isDownloading     = false;
  bool isDownloaded      = false;
  bool isCalendarAdded   = false;
  bool isCalling         = false;
  bool isNotDonatedSubmitting = false;
  late String _proofStatus;

  // ── Derived values ─────────────────────────────────────────────────────────
  late final DateTime donationDay;
  late final DateTime today;
  late final DateTime nextEligibleDate;
  late final bool donationOccurred;
  late final bool isDonationTime;    // true when slot datetime has passed
  late final int daysRemainingInCooling;
  late final int daysUntilDonation;
  late final String appointmentRef;

  bool get proofPending => _proofStatus == 'pending';

  @override
  void initState() {
    super.initState();
    _proofStatus = widget.proofStatus;
    final now = DateTime.now();
    today       = DateTime(now.year, now.month, now.day);
    donationDay = DateTime(widget.slotDate.year, widget.slotDate.month, widget.slotDate.day);

    donationOccurred  = !today.isBefore(donationDay);
    nextEligibleDate  = donationDay.add(Duration(days: widget.coolingDays));

    // "Donation Complete" button unlocks once the slot date+time has passed
    // Parse slotTime (e.g. "10:30 AM") to build a full DateTime
    DateTime slotDateTime = donationDay;
    try {
      final parts  = widget.slotTime.replaceAll(' AM', '').replaceAll(' PM', '').split(':');
      var hour     = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      if (widget.slotTime.contains('PM') && hour != 12) hour += 12;
      if (widget.slotTime.contains('AM') && hour == 12) hour = 0;
      slotDateTime = DateTime(donationDay.year, donationDay.month, donationDay.day, hour, minute);
    } catch (_) {}
    isDonationTime = now.isAfter(slotDateTime);

    if (donationOccurred) {
      daysRemainingInCooling = nextEligibleDate.difference(today).inDays.clamp(0, widget.coolingDays);
    } else {
      daysRemainingInCooling = widget.coolingDays;
    }

    daysUntilDonation = donationDay.difference(today).inDays.clamp(0, 9999);

    final hash = (widget.slotDate.millisecondsSinceEpoch ~/ 1000) % 9000 + 1000;
    appointmentRef = 'OBC-APP-${widget.slotDate.year}-$hash';

    if (isDonationTime && !proofPending && widget.bookingId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DonationDecisionPage(
              bookingId: widget.bookingId,
              donorName: widget.donorName,
              bloodGroup: widget.bloodGroup,
              component: widget.component,
              slotDate: widget.slotDate,
              slotTime: widget.slotTime,
              coolingDays: widget.coolingDays,
              coolingNote: widget.coolingNote,
              facilityName: widget.facilityName,
            ),
          ),
        );
      });
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _formatDate(DateTime d) {
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month]} ${d.year}';
  }

  String _formatShortDate(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  String _sessionLabel(String time) {
    final hour = int.tryParse(time.split(':')[0]) ?? 12;
    if (time.contains('AM') && hour < 12) return 'Morning Session';
    if (time.contains('PM') && hour < 5) return 'Afternoon Session';
    return 'Evening Session';
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: appointmentRef));
    setState(() => isCopied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Appointment Reference copied to clipboard!'),
        backgroundColor: activeRed,
        duration: Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => isCopied = false);
    });
  }

  void _downloadPass() {
    setState(() => isDownloading = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          isDownloading = false;
          isDownloaded  = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment Pass (PDF) saved to Downloads!'),
            backgroundColor: Color(0xFF15803D),
          ),
        );
      }
    });
  }

  void _addToCalendar() {
    setState(() => isCalendarAdded = !isCalendarAdded);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isCalendarAdded
              ? 'Event added to Google / Apple Calendar!'
              : 'Event removed from Calendar.',
        ),
        backgroundColor: isCalendarAdded ? primaryBlue : subText,
      ),
    );
  }

  void _makeCall() {
    setState(() => isCalling = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Dialing ${widget.facilityName} (${widget.facilityPhone})…'),
        backgroundColor: primaryRed,
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => isCalling = false);
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBg,
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
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 110.0),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Page header ────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: softBlueBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.check_circle, color: activeRed, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'VERIFIED BOOKING',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: darkText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.share_outlined,
                        color: primaryBlue, size: 20),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sharing appointment details…'),
                          backgroundColor: primaryBlue,
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Confirmation card ──────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: softRedBg,
                      child: const Icon(Icons.favorite,
                          color: activeRed, size: 28),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: softRedBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'APPOINTMENT CONFIRMED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: activeRed,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Thank You, ${widget.donorName.split(' ').first}!',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: darkText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Your donation slot is reserved. Your single contribution can directly protect and preserve up to 3 human lives.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11, color: subText, height: 1.4),
                    ),
                    const SizedBox(height: 16),

                    // Ref code row
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: softBlueBg.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'APPOINTMENT REF',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: subText,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                appointmentRef,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: darkText,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _copyToClipboard,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isCopied
                                    ? const Color(0xFFDCFCE7)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isCopied
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isCopied ? Icons.check : Icons.copy,
                                    size: 12,
                                    color: isCopied
                                        ? const Color(0xFF16A34A)
                                        : darkText,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isCopied ? 'Copied' : 'Copy',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isCopied
                                          ? const Color(0xFF16A34A)
                                          : darkText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: primaryRed,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Digital pass / QR ──────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    // Red banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        color: primaryRed,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.qr_code_scanner,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'FAST-TRACK DONOR PASS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'Priority Check-in Entry',
                                    style: TextStyle(
                                        fontSize: 9, color: Colors.white70),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: const [
                              Text(
                                'PRIORITY SLOT',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '#JIP-08',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'SHOW AT GATE OR SCAN BELOW',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: subText),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Icon(Icons.qr_code_2,
                                size: 140, color: darkText),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'OBC • PASS • SECURE TOKEN',
                            style: TextStyle(
                                fontSize: 9,
                                color: subText,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Scan at Hospital Donor Reception for instant contactless check-in.',
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(fontSize: 11, color: subText),
                          ),
                          const SizedBox(height: 16),

                          // Download button
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDownloaded
                                    ? const Color(0xFF15803D)
                                    : primaryRed,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed:
                                  isDownloading ? null : _downloadPass,
                              icon: isDownloading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      isDownloaded
                                          ? Icons.check_circle
                                          : Icons.file_download_outlined,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                              label: Text(
                                isDownloading
                                    ? 'Generating PDF Pass…'
                                    : (isDownloaded
                                        ? 'Pass Saved (PDF)'
                                        : 'Download Appointment Pass (PDF)'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Calendar button
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: isCalendarAdded
                                    ? softBlueBg
                                    : Colors.white,
                                side: BorderSide(
                                  color: isCalendarAdded
                                      ? primaryBlue
                                      : const Color(0xFFCBD5E1),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _addToCalendar,
                              icon: Icon(
                                isCalendarAdded
                                    ? Icons.event_available
                                    : Icons.calendar_today,
                                color: isCalendarAdded
                                    ? primaryBlue
                                    : darkText,
                                size: 16,
                              ),
                              label: Text(
                                isCalendarAdded
                                    ? 'Added to Calendar'
                                    : 'Add to Google / Apple Calendar',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isCalendarAdded
                                      ? primaryBlue
                                      : darkText,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Schedule & donor overview ──────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SCHEDULE & DONOR OVERVIEW',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: darkText,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: softRedBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      widget.component,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: activeRed,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Date & time
              _infoTile(
                icon: Icons.calendar_month,
                iconColor: primaryBlue,
                label: 'Date & Time',
                primary: _formatDate(widget.slotDate),
                secondary:
                    '${widget.slotTime} • ${_sessionLabel(widget.slotTime)}',
              ),
              const SizedBox(height: 8),

              // Donor identity
              _infoTile(
                icon: Icons.person_outline,
                iconColor: primaryBlue,
                label: 'Donor Identity',
                primary: widget.donorName,
                secondary:
                    '${widget.bloodGroup} • ${widget.component}',
              ),
              const SizedBox(height: 8),

              // Hospital
              _infoTile(
                icon: Icons.apartment,
                iconColor: primaryBlue,
                label: 'Hospital',
                primary: widget.facilityName,
                secondary: widget.facilityAddress,
              ),

              const SizedBox(height: 20),

              // ── Cooling period countdown ───────────────────────────────
              _buildCoolingPeriodSection(),

              const SizedBox(height: 20),

              // ── Hospital venue map ─────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: activeRed, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'HOSPITAL VENUE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: darkText,
                        ),
                      ),
                    ],
                  ),
                  Text('1.4 km away',
                      style: TextStyle(fontSize: 11, color: subText)),
                ],
              ),
              const SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Map placeholder
                    Container(
                      height: 100,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.bottomLeft,
                        children: [
                          Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.navigation,
                                    size: 12, color: activeRed),
                                SizedBox(width: 4),
                                Text(
                                  'Gate 2 • Main Dedicated Free Parking',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: darkText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.facilityName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: darkText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.facilityAddress,
                            style: const TextStyle(
                                fontSize: 11, color: subText),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 38,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: softBlueBg,
                                side: const BorderSide(
                                    color: Color(0xFFBFDBFE)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Opening Maps to ${widget.facilityName}…'),
                                    backgroundColor: primaryBlue,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.near_me,
                                  color: primaryBlue, size: 14),
                              label: const Text(
                                'Get Directions via Maps',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: primaryBlue,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Important guidelines ──────────────────────────────────
              const Text(
                'IMPORTANT GUIDELINES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: darkText,
                ),
              ),
              const SizedBox(height: 10),

              _buildGuidelineItem(
                Icons.badge_outlined,
                'Bring Government Photo ID:',
                'Aadhaar, Voter ID, Passport, or Driver\'s License required for intake.',
              ),
              _buildGuidelineItem(
                Icons.water_drop_outlined,
                'Hydration & Nutrition:',
                'Have a nutritious light meal and drink at least 500 ml water 30 mins prior.',
              ),
              _buildGuidelineItem(
                Icons.local_parking,
                'Free Priority Donor Parking:',
                'Available at Gate 2 by showing this digital pass.',
              ),

              const SizedBox(height: 20),

              // ── Donor support desk ────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: softBlueBg.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Donor Support Desk',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: subText),
                    ),
                    Text(
                      '${widget.facilityName} • Direct Desk',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: darkText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Helpline',
                                style: TextStyle(
                                    fontSize: 9, color: subText)),
                            Text(
                              widget.facilityPhone,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: darkText,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isCalling
                                ? const Color(0xFF15803D)
                                : const Color(0xFF0F4C81),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          onPressed: _makeCall,
                          icon: Icon(
                            isCalling
                                ? Icons.phone_in_talk
                                : Icons.call,
                            color: Colors.white,
                            size: 14,
                          ),
                          label: Text(
                            isCalling ? 'Calling…' : 'Call Now',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              color: activeRed, size: 14),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Pass & live token updates sent via WhatsApp & SMS to your registered number.',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: darkText,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Donation Complete button ───────────────────────────────
              _buildDonationCompleteSection(),

              const SizedBox(height: 20),

              // ── Bottom actions ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: softBlueBg,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'View All Appointments',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: primaryBlue,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text(
                    'Back to Home Dashboard',
                    style: TextStyle(
                        fontSize: 11,
                        color: subText,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),

            // ── Bottom Navigation ──────────────────────────────────────
            Positioned(
              left: 20,
              right: 20,
              bottom: 16,
              child: FloatingNav(selectedIndex: 2),
            ),
          ],
        ),
      ),
    );
  }

  // ── Donation Complete section ──────────────────────────────────────────────
  Widget _buildDonationCompleteSection() {
    const Color green       = Color(0xFF15803D);
    const Color softGreenBg = Color(0xFFDCFCE7);
    const Color orange      = Color(0xFFEA580C);

    if (proofPending) return _buildPendingProofSection();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDonationTime
              ? const Color(0xFF86EFAC)
              : const Color(0xFFE2E8F0),
          width: isDonationTime ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDonationTime ? softGreenBg : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDonationTime
                      ? Icons.volunteer_activism
                      : Icons.lock_clock,
                  color: isDonationTime ? green : subText,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDonationTime
                          ? 'Mark Donation Complete'
                          : 'Donation Complete',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDonationTime ? darkText : subText,
                      ),
                    ),
                    Text(
                      isDonationTime
                          ? 'Upload your photo & doctor\'s slip to confirm'
                          : 'Available after ${_formatDate(widget.slotDate)} ${widget.slotTime}',
                      style: const TextStyle(fontSize: 10, color: subText),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDonationTime ? softGreenBg : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isDonationTime ? 'READY' : 'LOCKED',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isDonationTime ? green : subText,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (!isDonationTime) ...[
            // Locked state
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      daysUntilDonation == 0
                          ? 'Your slot is today at ${widget.slotTime}. This button unlocks after your appointment time.'
                          : 'This button unlocks on ${_formatDate(donationDay)} after ${widget.slotTime}.',
                      style: const TextStyle(
                          fontSize: 11, color: subText, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade300,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: null, // locked
                icon: const Icon(Icons.lock_outlined,
                    color: Colors.white, size: 18),
                label: const Text(
                  'Donation Complete',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ] else ...[
            // Unlocked state
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: softGreenBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: const [
                  Icon(Icons.check_circle_outline, color: green, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your appointment time has passed. Tap below to upload your donation photo and doctor\'s slip to start your cooling period.',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF166534),
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: green,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  final submitted = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DonationCompletePage(
                        bookingId:    widget.bookingId,
                        donorName:    widget.donorName,
                        bloodGroup:   widget.bloodGroup,
                        component:    widget.component,
                        slotDate:     widget.slotDate,
                        slotTime:     widget.slotTime,
                        coolingDays:  widget.coolingDays,
                        coolingNote:  widget.coolingNote,
                        facilityName: widget.facilityName,
                      ),
                    ),
                  );
                  if (submitted == true && mounted) {
                    setState(() => _proofStatus = 'pending');
                  }
                },
                icon: const Icon(Icons.volunteer_activism,
                    color: Colors.white, size: 20),
                label: const Text(
                  'I Donated — Mark Complete',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: isNotDonatedSubmitting ? null : _markNotDonated,
                icon: const Icon(Icons.event_busy, size: 18),
                label: const Text('I did not donate — tell us why'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingProofSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hourglass_top, color: Color(0xFFD97706)),
              SizedBox(width: 10),
              Expanded(
                child: Text('Donation proof under review',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Your proof was uploaded successfully. The blood bank will verify it before your certificate and cooling period are activated.',
            style: TextStyle(fontSize: 12, color: subText, height: 1.4),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('Status: Pending verification',
                style: TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _markNotDonated() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Did not donate?'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Tell us why you could not donate',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isNotEmpty) Navigator.pop(context, reason);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || reason.isEmpty || !mounted) return;
    setState(() => isNotDonatedSubmitting = true);
    try {
      await ApiService().markBookingNotDonated(
        bookingId: widget.bookingId,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks. You can book another donation slot when ready.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => isNotDonatedSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit: $e')),
        );
      }
    }
  }

  // ── Cooling period section ─────────────────────────────────────────────────
  Widget _buildCoolingPeriodSection() {
    final coolingComplete = donationOccurred && daysRemainingInCooling <= 0;
    final elapsed = donationOccurred
        ? (widget.coolingDays - daysRemainingInCooling).clamp(0, widget.coolingDays)
        : 0;
    final progress = widget.coolingDays > 0 ? elapsed / widget.coolingDays : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: donationOccurred
                      ? const Color(0xFFFFF7ED)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  donationOccurred
                      ? Icons.hourglass_top_rounded
                      : Icons.event_outlined,
                  color: donationOccurred
                      ? const Color(0xFFEA580C)
                      : primaryBlue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      donationOccurred ? 'COOLING PERIOD' : 'UPCOMING DONATION',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: darkText,
                      ),
                    ),
                    Text(
                      donationOccurred
                          ? 'Mandatory rest window — cooling period active'
                          : 'Cooling period begins after your donation',
                      style: const TextStyle(fontSize: 10, color: subText),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: coolingComplete
                      ? const Color(0xFFDCFCE7)
                      : donationOccurred
                          ? const Color(0xFFFFF7ED)
                          : softBlueBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  coolingComplete
                      ? 'Eligible'
                      : '${widget.coolingDays} days',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: coolingComplete
                        ? const Color(0xFF15803D)
                        : donationOccurred
                            ? const Color(0xFFEA580C)
                            : primaryBlue,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Guideline chip
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: softRedBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.water_drop, color: activeRed, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF7C2D12), height: 1.4),
                      children: [
                        TextSpan(
                          text: '${widget.component}: ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                              'Cooling period is ${widget.coolingNote} as per Indian Blood Transfusion Council (IBTC) guidelines.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Before donation: show countdown to donation day ────────────
          if (!donationOccurred) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: softBlueBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.lock_clock, color: primaryBlue, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    daysUntilDonation == 0
                        ? 'Your donation is today!'
                        : '$daysUntilDonation day${daysUntilDonation == 1 ? '' : 's'} until your donation',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: darkText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'The cooling period will start automatically\nafter you complete your donation.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: subText, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_today,
                          color: primaryBlue, size: 13),
                      const SizedBox(width: 6),
                      Text(
                        'Donation date: ${_formatDate(donationDay)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // ── After donation: show cooling progress ─────────────────────
          if (donationOccurred) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Donated: ${_formatShortDate(donationDay)}',
                  style: const TextStyle(fontSize: 10, color: subText),
                ),
                Text(
                  'Eligible: ${_formatShortDate(nextEligibleDate)}',
                  style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF15803D),
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  coolingComplete
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFEA580C),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Days remaining badge
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: coolingComplete
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: coolingComplete
                        ? const Color(0xFF86EFAC)
                        : const Color(0xFFFED7AA),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      coolingComplete
                          ? Icons.check_circle_outline
                          : Icons.timer_outlined,
                      size: 14,
                      color: coolingComplete
                          ? const Color(0xFF15803D)
                          : const Color(0xFFEA580C),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      coolingComplete
                          ? 'You are now eligible to donate again!'
                          : '$daysRemainingInCooling day${daysRemainingInCooling == 1 ? '' : 's'} remaining in cooling period',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: coolingComplete
                            ? const Color(0xFF15803D)
                            : const Color(0xFFEA580C),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Next eligible date
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: softBlueBg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.event_available,
                        color: primaryBlue, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Next Eligible Donation Date',
                        style: TextStyle(fontSize: 10, color: subText),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(nextEligibleDate),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: darkText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Info tile ──────────────────────────────────────────────────────────────
  Widget _infoTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String primary,
    required String secondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: softBlueBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        const TextStyle(fontSize: 10, color: subText)),
                const SizedBox(height: 2),
                Text(primary,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: darkText)),
                Text(secondary,
                    style: const TextStyle(
                        fontSize: 11, color: subText)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Guideline item ─────────────────────────────────────────────────────────
  Widget _buildGuidelineItem(
      IconData icon, String boldTitle, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: activeRed),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 11, color: darkText, height: 1.3),
                children: [
                  TextSpan(
                    text: '$boldTitle ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: description,
                    style: const TextStyle(color: subText),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
