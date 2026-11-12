import 'package:flutter/material.dart';
import 'donation_complete_page.dart';
import 'services/api_service.dart';

class DonationDecisionPage extends StatefulWidget {
  final String bookingId;
  final String donorName;
  final String bloodGroup;
  final String component;
  final DateTime slotDate;
  final String slotTime;
  final int coolingDays;
  final String coolingNote;
  final String facilityName;

  const DonationDecisionPage({
    super.key,
    required this.bookingId,
    required this.donorName,
    required this.bloodGroup,
    required this.component,
    required this.slotDate,
    required this.slotTime,
    required this.coolingDays,
    required this.coolingNote,
    required this.facilityName,
  });

  @override
  State<DonationDecisionPage> createState() => _DonationDecisionPageState();
}

class _DonationDecisionPageState extends State<DonationDecisionPage> {
  bool _submitting = false;

  Future<void> _didNotDonate() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Why could you not donate?'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter the reason',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty || !mounted) return;

    setState(() => _submitting = true);
    try {
      await ApiService().markBookingNotDonated(
        bookingId: widget.bookingId,
        reason: reason,
      );
      if (!mounted) return;
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit: $e')),
        );
      }
    }
  }

  void _didDonate() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DonationCompletePage(
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Donation Confirmation'),
        backgroundColor: const Color(0xFF8B0000),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.volunteer_activism,
                      color: Color(0xFFC8102E), size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'We hope you donated successfully!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your appointment at ${widget.facilityName} has ended. '
                    'Please tell us what happened.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _didDonate,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('I Donated Successfully'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF15803D),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _submitting ? null : _didNotDonate,
                      icon: const Icon(Icons.event_busy),
                      label: const Text('I Did Not Donate'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'If you donated, you will upload proof next. '
                    'The certificate and cooling period begin only after verification.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
