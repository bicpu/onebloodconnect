import 'dart:async';
import 'package:flutter/material.dart';
import 'certificate_page.dart';
import 'services/api_service.dart';
import 'widgets/floating_nav.dart';

class DonationProcessingPage extends StatefulWidget {
  final String bookingId;
  final String donorName;
  final String bloodGroup;
  final String component;
  final DateTime donatedAt;
  final int coolingDays;
  final String facilityName;

  const DonationProcessingPage({
    super.key,
    required this.bookingId,
    required this.donorName,
    required this.bloodGroup,
    required this.component,
    required this.donatedAt,
    required this.coolingDays,
    required this.facilityName,
  });

  @override
  State<DonationProcessingPage> createState() => _DonationProcessingPageState();
}

class _DonationProcessingPageState extends State<DonationProcessingPage> {
  Timer? _poller;
  String _proofStatus = 'pending';
  String _verificationNote = '';
  String _appealReason = '';
  final TextEditingController _appealController = TextEditingController();
  bool _showAppealForm = false;
  bool _submittingAppeal = false;
  Map<String, dynamic>? _certificate;

  DateTime get _coolingEndsAt =>
      widget.donatedAt.add(Duration(days: widget.coolingDays));

  int get _daysRemaining {
    final today = DateTime.now();
    final end = DateTime(
      _coolingEndsAt.year,
      _coolingEndsAt.month,
      _coolingEndsAt.day,
    );
    final current = DateTime(today.year, today.month, today.day);
    return end.difference(current).inDays.clamp(0, widget.coolingDays);
  }

  bool get _coolingComplete => _daysRemaining == 0;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poller = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  @override
  void dispose() {
    _poller?.cancel();
    _appealController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final booking = await ApiService().getBooking(widget.bookingId);
      if (!mounted) return;
      final status = booking['proofStatus'] as String? ?? 'pending';
      Map<String, dynamic>? certificate;
      if (status == 'approved') {
        try {
          certificate = await ApiService().getCertificate(widget.bookingId);
        } catch (_) {}
      }
      setState(() {
        _proofStatus = status;
        _verificationNote = booking['verificationNote'] as String? ?? '';
        _appealReason = booking['appealReason'] as String? ?? '';
        _certificate = certificate;
      });
    } catch (_) {
      // Keep the last known status visible during temporary network failures.
    }
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')} '
      '${_months[value.month - 1]} ${value.year}';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final approved = _proofStatus == 'approved';
    final rejected = _proofStatus == 'rejected';
    final appealed = _proofStatus == 'appealed';
    final progress = widget.coolingDays == 0
        ? 1.0
        : ((widget.coolingDays - _daysRemaining) / widget.coolingDays)
            .clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text('Donation Status'),
        backgroundColor: const Color(0xFF8B0000),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 112),
              children: [
            _hero(approved, rejected),
            const SizedBox(height: 14),
            _detailsCard(),
            const SizedBox(height: 14),
            if (rejected || appealed) ...[
              _reviewCard(rejected, appealed),
              const SizedBox(height: 14),
            ],
            _coolingCard(progress),
            const SizedBox(height: 14),
            _certificateCard(approved),
            const SizedBox(height: 22),
            OutlinedButton(
              onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
              child: const Text('Back to Home Dashboard'),
            ),
              ],
            ),
          ),
          const Positioned(
            left: 20,
            right: 20,
            bottom: 16,
            child: FloatingNav(selectedIndex: 2),
          ),
        ],
      ),
    );
  }

  Widget _reviewCard(bool rejected, bool appealed) {
    return _card(
      title: appealed ? 'Appeal submitted' : 'Admin review',
      icon: appealed ? Icons.outgoing_mail : Icons.gavel_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_verificationNote.isNotEmpty) ...[
            const Text('Admin comment',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(_verificationNote,
                style: const TextStyle(color: Color(0xFF475569), height: 1.4)),
            const SizedBox(height: 12),
          ],
          if (_appealReason.isNotEmpty) ...[
            const Text('Your appeal',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(_appealReason,
                style: const TextStyle(color: Color(0xFF475569), height: 1.4)),
          ],
          if (rejected) ...[
            const SizedBox(height: 14),
            if (!_showAppealForm)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _showAppealForm = true),
                  icon: const Icon(Icons.reply),
                  label: const Text('Appeal this decision'),
                ),
              )
            else ...[
              TextField(
                controller: _appealController,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Appeal reason',
                  hintText: 'Explain why this proof should be reconsidered',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submittingAppeal ? null : _submitAppeal,
                  icon: _submittingAppeal
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(
                    _submittingAppeal ? 'Sending request...' : 'Send appeal request',
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _submitAppeal() async {
    final reason = _appealController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reason for your appeal.')),
      );
      return;
    }
    setState(() => _submittingAppeal = true);
    try {
      final updated = await ApiService().appealBooking(
        bookingId: widget.bookingId,
        reason: reason,
      );
      if (!mounted) return;
      setState(() {
        _proofStatus = updated['proofStatus'] as String? ?? 'appealed';
        _appealReason = updated['appealReason'] as String? ?? reason;
        _showAppealForm = false;
        _submittingAppeal = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appeal request sent successfully. Waiting for admin review.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _submittingAppeal = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Appeal could not be sent: $e')),
        );
      }
    }
  }

  Widget _hero(bool approved, bool rejected) {
    final appealed = _proofStatus == 'appealed';
    final color = rejected
        ? const Color(0xFFB91C1C)
        : approved
            ? const Color(0xFF15803D)
            : const Color(0xFFD97706);
    final title = rejected
        ? 'Proof was rejected'
        : appealed
            ? 'Appeal under review'
        : approved
            ? 'Donation verified'
            : 'Thank you for donating';
    final subtitle = rejected
        ? 'Review the admin note and submit an appeal if the decision needs to be reconsidered.'
        : appealed
            ? 'Your appeal has been sent to the admin team.'
        : approved
            ? 'Your donation has been verified by ${widget.facilityName}.'
            : 'Your proof is safely submitted and waiting for verification.';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.78)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(
            rejected
                ? Icons.info_outline
                : appealed
                    ? Icons.mark_email_read_outlined
                : approved
                    ? Icons.verified
                    : Icons.hourglass_top_rounded,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 7),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, height: 1.4)),
        ],
      ),
    );
  }

  Widget _detailsCard() {
    return _card(
      title: 'Donation details',
      icon: Icons.volunteer_activism_outlined,
      child: Column(
        children: [
          _row('Donor', widget.donorName),
          _row('Blood group', widget.bloodGroup),
          _row('Component', widget.component),
          _row('Donated on', _date(widget.donatedAt)),
          _row('Blood bank', widget.facilityName),
        ],
      ),
    );
  }

  Widget _coolingCard(double progress) {
    return _card(
      title: 'Cooling period',
      icon: Icons.shield_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _coolingComplete
                ? 'Cooling period complete. You are eligible to donate again.'
                : 'Your recovery period is in progress.',
            style: const TextStyle(color: Color(0xFF475569), height: 1.4),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: const Color(0xFFE2E8F0),
              color: _coolingComplete
                  ? const Color(0xFF15803D)
                  : const Color(0xFFD97706),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _coolingComplete
                ? 'Eligible now'
                : '$_daysRemaining day${_daysRemaining == 1 ? '' : 's'} remaining',
            style: TextStyle(
              color: _coolingComplete
                  ? const Color(0xFF15803D)
                  : const Color(0xFFD97706),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text('Eligible from ${_date(_coolingEndsAt)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _certificateCard(bool approved) {
    final ready = approved && _certificate != null;
    return _card(
      title: 'Donation certificate',
      icon: Icons.workspace_premium_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            approved
                ? ready
                    ? 'Your verified certificate is ready.'
                    : 'Your donation was verified. Your certificate is being prepared.'
                : 'Your certificate is under review.',
            style: const TextStyle(color: Color(0xFF475569), height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: ready
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CertificatePage(certificate: _certificate!),
                        ),
                      )
                  : null,
              icon: const Icon(Icons.download_outlined),
              label: Text(ready ? 'Download Certificate' : 'Certificate Not Available Yet'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFC8102E)),
              const SizedBox(width: 9),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
