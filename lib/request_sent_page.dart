import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'track_request_page.dart';
import 'dashboard.dart';

class RequestSentPage extends StatefulWidget {
  final String requestId;
  const RequestSentPage({super.key, required this.requestId});

  @override
  State<RequestSentPage> createState() => _RequestSentPageState();
}

class _RequestSentPageState extends State<RequestSentPage> {
  static const Color _red   = Color(0xFFC0152A);
  static const Color _dark  = Color(0xFF0F172A);

  Map<String, dynamic>? _request;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService().getBloodRequest(widget.requestId);
      if (mounted) setState(() { _request = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r           = _request;
    final bloodGroup  = r?['bloodGroup']  as String? ?? '–';
    final hospital    = r?['hospital']    as String? ?? '–';
    final urgency     = r?['urgency']     as String? ?? 'Urgent';
    final units       = r?['units']       ?? '–';
    final component   = r?['component']   as String? ?? 'Whole Blood';

    Color urgencyColor;
    IconData urgencyIcon;
    switch (urgency) {
      case 'Critical Red':
        urgencyColor = const Color(0xFFCC0000); urgencyIcon = Icons.emergency_rounded; break;
      case 'Urgent':
        urgencyColor = const Color(0xFFD97706); urgencyIcon = Icons.warning_amber_rounded; break;
      default:
        urgencyColor = const Color(0xFF2563EB); urgencyIcon = Icons.info_outline;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, unused) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const DashboardPage()),
          (r) => false,
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FB),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFC0152A)))
                : Column(
                    children: [
                      const Spacer(),

                      // ── Success animation ──────────────────────────────
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 150, height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _red.withValues(alpha: 0.08),
                            ),
                          ),
                          Container(
                            width: 110, height: 110,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: Colors.white,
                            ),
                          ),
                          Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B0000), Color(0xFFC0152A)],
                                begin: Alignment.topLeft, end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(color: _red.withValues(alpha: 0.35),
                                    blurRadius: 16, offset: const Offset(0, 6)),
                              ],
                            ),
                            child: const Icon(Icons.water_drop, color: Colors.white, size: 32),
                          ),
                          Positioned(
                            bottom: 14, right: 14,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle, color: Color(0xFF15803D),
                              ),
                              child: const Icon(Icons.check, color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ── Title ──────────────────────────────────────────
                      const Text(
                        '🩸 Request Broadcast!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Your request has been sent to all\neligible $bloodGroup donors near you.\nYou\'ll be notified when someone responds.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
                      ),

                      const SizedBox(height: 28),

                      // ── Request summary card ───────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 12, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Urgency row
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: urgencyColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: urgencyColor.withValues(alpha: 0.3)),
                                ),
                                child: Row(children: [
                                  Icon(urgencyIcon, size: 12, color: urgencyColor),
                                  const SizedBox(width: 4),
                                  Text(urgency.toUpperCase(),
                                      style: TextStyle(fontSize: 10,
                                          fontWeight: FontWeight.bold, color: urgencyColor,
                                          letterSpacing: 0.5)),
                                ]),
                              ),
                            ]),
                            const SizedBox(height: 14),

                            // Blood group + units
                            Row(children: [
                              Container(
                                width: 56, height: 56,
                                decoration: BoxDecoration(
                                  color: _red.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(bloodGroup,
                                      style: const TextStyle(
                                          color: Color(0xFFC0152A),
                                          fontWeight: FontWeight.w900, fontSize: 20)),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$units unit${units.toString() != '1' ? 's' : ''} of $component',
                                      style: const TextStyle(fontWeight: FontWeight.bold,
                                          fontSize: 15, color: Color(0xFF0F172A))),
                                  const SizedBox(height: 3),
                                  Text(hospital,
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      overflow: TextOverflow.ellipsis),
                                ],
                              )),
                            ]),

                            const SizedBox(height: 14),
                            Divider(color: Colors.grey.shade100),
                            const SizedBox(height: 10),

                            // Status row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Current Status',
                                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(children: const [
                                    SizedBox(
                                      width: 10, height: 10,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Text('Searching for donors…',
                                        style: TextStyle(fontSize: 11,
                                            color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                                  ]),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // ── Buttons ────────────────────────────────────────
                      SizedBox(
                        width: double.infinity, height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _red,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 4,
                            shadowColor: _red.withValues(alpha: 0.3),
                          ),
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TrackRequestPage(requestId: widget.requestId),
                            ),
                          ),
                          icon: const Icon(Icons.radar, color: Colors.white, size: 20),
                          label: const Text('Track My Request',
                              style: TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity, height: 50,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _red.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const DashboardPage()),
                            (r) => false,
                          ),
                          icon: Icon(Icons.home_outlined, color: _dark, size: 18),
                          label: Text('Back to Home',
                              style: TextStyle(color: _dark,
                                  fontWeight: FontWeight.w600, fontSize: 15)),
                        ),
                      ),

                      const SizedBox(height: 10),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
