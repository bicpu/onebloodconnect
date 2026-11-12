import 'package:flutter/material.dart';
import 'book_hospital_slot_page.dart';
import 'widgets/floating_nav.dart';
import 'services/api_service.dart';
import 'certificate_page.dart';

/// Shown immediately after a donation is confirmed.
/// Displays the cooling period countdown and unlocks the booking page
/// only after coolingEndsAt has passed.
class CoolingPeriodPage extends StatelessWidget {
  final String   bookingId;
  final String   donorName;
  final String   bloodGroup;
  final String   component;
  final DateTime donatedAt;
  final int      coolingDays;
  final String   coolingNote;
  final String   facilityName;

  const CoolingPeriodPage({
    super.key,
    this.bookingId = '',
    required this.donorName,
    required this.bloodGroup,
    required this.component,
    required this.donatedAt,
    required this.coolingDays,
    required this.coolingNote,
    required this.facilityName,
  });

  // ── Palette ────────────────────────────────────────────────────────────────
  static const Color primaryRed  = Color(0xFF8B0000);
  static const Color activeRed   = Color(0xFFC8102E);
  static const Color darkText    = Color(0xFF0F172A);
  static const Color subText     = Color(0xFF64748B);
  static const Color softRedBg   = Color(0xFFFFEAEA);
  static const Color softBlueBg  = Color(0xFFEFF6FF);
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color green       = Color(0xFF15803D);
  static const Color softGreenBg = Color(0xFFDCFCE7);
  static const Color orange      = Color(0xFFEA580C);

  // ── Helpers ────────────────────────────────────────────────────────────────
  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime get _donationDay =>
      DateTime(donatedAt.year, donatedAt.month, donatedAt.day);

  DateTime get _coolingEndsAt =>
      _donationDay.add(Duration(days: coolingDays));

  int get _daysRemaining =>
      _coolingEndsAt.difference(_today).inDays.clamp(0, coolingDays);

  bool get _coolingComplete => _today.isAfter(_coolingEndsAt) ||
      _today.isAtSameMomentAs(_coolingEndsAt);

  double get _progress {
    final elapsed = _today.difference(_donationDay).inDays.clamp(0, coolingDays);
    return coolingDays > 0 ? elapsed / coolingDays : 1.0;
  }

  String _fmt(DateTime d) {
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

  String _fmtShort(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final complete = _coolingComplete;
    final remaining = _daysRemaining;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: CircleAvatar(
            backgroundColor: activeRed,
            child: const Icon(Icons.water_drop,
                color: Colors.white, size: 18),
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
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Thank you card ────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B0000), Color(0xFFC8102E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white24,
                      child: const Icon(Icons.volunteer_activism,
                          color: Colors.white, size: 30),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'DONATION CONFIRMED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Thank You, ${donorName.split(' ').first}!',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Your donation has been recorded. You may have just saved up to 3 lives.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          height: 1.4),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Donation summary tiles ────────────────────────────────
              _tile(Icons.water_drop, activeRed,
                  'Component', component),
              const SizedBox(height: 8),
              _tile(Icons.bloodtype, activeRed,
                  'Blood Group', bloodGroup),
              const SizedBox(height: 8),
              _tile(Icons.apartment, primaryBlue,
                  'Donated At', facilityName),
              const SizedBox(height: 8),
              _tile(Icons.calendar_today, primaryBlue,
                  'Donation Date', _fmt(donatedAt)),

              const SizedBox(height: 20),

              // ── Cooling period card ───────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
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
                            color: complete
                                ? softGreenBg
                                : const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            complete
                                ? Icons.check_circle_outline
                                : Icons.hourglass_top_rounded,
                            color: complete ? green : orange,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                complete
                                    ? 'COOLING PERIOD COMPLETE'
                                    : 'COOLING PERIOD ACTIVE',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: darkText,
                                ),
                              ),
                              Text(
                                complete
                                    ? 'You are eligible to donate again'
                                    : 'Rest required before next donation',
                                style: const TextStyle(
                                    fontSize: 10, color: subText),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: complete
                                ? softGreenBg
                                : const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            complete ? 'Done' : '$coolingDays days',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: complete ? green : orange,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Guideline
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: softRedBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF7C2D12),
                              height: 1.4),
                          children: [
                            TextSpan(
                              text: '$component: ',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                              text:
                                  '$coolingNote cooling period as per IBTC guidelines.',
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Date range labels
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Donated: ${_fmtShort(donatedAt)}',
                            style: const TextStyle(
                                fontSize: 10, color: subText)),
                        Text('Eligible: ${_fmtShort(_coolingEndsAt)}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: complete ? green : orange,
                            )),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 10,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          complete ? green : orange,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Days badge
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: complete
                              ? softGreenBg
                              : const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: complete
                                ? const Color(0xFF86EFAC)
                                : const Color(0xFFFED7AA),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              complete
                                  ? Icons.check_circle_outline
                                  : Icons.timer_outlined,
                              size: 14,
                              color: complete ? green : orange,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              complete
                                  ? 'You can donate again now!'
                                  : '$remaining day${remaining == 1 ? '' : 's'} remaining',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: complete ? green : orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Next eligible date
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: softBlueBg.withValues(alpha: 0.6),
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
                              const Text('Next Eligible Donation Date',
                                  style: TextStyle(
                                      fontSize: 10, color: subText)),
                              const SizedBox(height: 2),
                              Text(
                                _fmt(_coolingEndsAt),
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
                ),
              ),

              const SizedBox(height: 24),

              // ── Book Again button (only shown after cooling is done) ───
              if (complete) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: softGreenBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.celebration,
                          color: green, size: 32),
                      const SizedBox(height: 8),
                      const Text(
                        'Cooling period complete!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'You are now eligible to donate again. Book your next slot below.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, color: subText, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: green,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const BookHospitalSlotPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add_circle_outline,
                              color: Colors.white, size: 18),
                          label: const Text(
                            'Book Next Donation Slot',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Cooling still active — show locked state
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.lock_outlined,
                            color: Colors.grey.shade400, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Next booking locked for $remaining day${remaining == 1 ? '' : 's'}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: darkText,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Available after ${_fmtShort(_coolingEndsAt)}',
                              style: const TextStyle(
                                  fontSize: 11, color: subText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (bookingId.isNotEmpty) ...[
                const SizedBox(height: 16),
                FutureBuilder<Map<String, dynamic>>(
                  future: ApiService().getCertificate(bookingId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasData) {
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CertificatePage(
                                certificate: snapshot.data!,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.workspace_premium),
                          label: const Text('View Donation Certificate'),
                        ),
                      );
                    }
                    return const Text(
                      'Certificate will appear here after your proof is verified by the blood bank.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: subText),
                    );
                  },
                ),
              ],

              const SizedBox(height: 16),

              // Back to dashboard
              Center(
                child: TextButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text(
                    'Back to Home Dashboard',
                    style: TextStyle(fontSize: 12, color: subText),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),

            // ── Bottom Navigation ────────────────────────────────────
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

  // ── Info tile ──────────────────────────────────────────────────────────────
  Widget _tile(
      IconData icon, Color iconColor, String label, String value) {
    return Container(
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
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 10, color: subText)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: darkText,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}
