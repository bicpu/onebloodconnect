import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/api_service.dart';

/// Shown when a user taps "Respond Now" on an urgent request card.
///
/// Parameters:
///   [request]   — full BloodRequest document from the API (includes hasResponded, unitsRemaining)
///   [donor]     — current user's donor profile from GET /donors/me
class EmergencyResponsePage extends StatefulWidget {
  final Map<String, dynamic> request;
  final Map<String, dynamic> donor;

  const EmergencyResponsePage({
    super.key,
    required this.request,
    required this.donor,
  });

  @override
  State<EmergencyResponsePage> createState() => _EmergencyResponsePageState();
}

class _EmergencyResponsePageState extends State<EmergencyResponsePage> {
  static const Color _red    = Color(0xFFC0152A);
  static const Color _darkBg = Color(0xFF0F172A);

  // ── Referral form controllers ──────────────────────────────────────────────
  final _friendNameCtrl  = TextEditingController();
  final _friendPhoneCtrl = TextEditingController();
  bool _referralSent = false;

  // ── Response state (server-backed) ────────────────────────────────────────
  bool _responseSent  = false;
  bool _submitting    = false;
  bool _withdrawing   = false;   // true while cancel-response API call is in flight
  int  _unitsToCommit = 1;
  int  _committedUnits = 0;

  // ── Derived from request ───────────────────────────────────────────────────
  String get _bloodGroup    => widget.request['bloodGroup']    as String? ?? '?';
  String get _area          => widget.request['hubZone']       as String? ?? 'Nearby area';
  String get _urgency       => widget.request['urgency']       as String? ?? 'Urgent';
  String get _component     => widget.request['component']     as String? ?? 'Whole Blood';
  String get _units         => '${widget.request['units'] ?? 1}';
  String get _status        => widget.request['status']        as String? ?? 'received';
  String get _requestId     => widget.request['_id']           as String? ?? '';

  // canDonate: server says this donor's blood group matches (or unregistered)
  bool get _canDonate           => widget.request['canDonate']           != false;
  // hasActiveCommitment: donor is already committed to a DIFFERENT request
  bool get _hasActiveCommitment => widget.request['hasActiveCommitment'] == true;
  // isMyActiveCommitment: donor is committed to THIS request (= responded + not withdrawn)
  bool get _isMyActiveCommitment => widget.request['isMyActiveCommitment'] == true;

  // Expiry
  String get _expiresLabel {
    final raw = widget.request['expiresAt'];
    if (raw == null) return '';
    try {
      final exp  = DateTime.parse(raw.toString()).toLocal();
      final diff = exp.difference(DateTime.now());
      if (diff.isNegative) return 'Expired';
      if (diff.inMinutes < 60) return 'Expires in ${diff.inMinutes}m';
      return 'Expires in ${diff.inHours}h';
    } catch (_) { return ''; }
  }

  int get _unitsRemaining {
    final raw = widget.request['unitsRemaining'];
    if (raw is int)  return raw;
    if (raw is num)  return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? (int.tryParse(_units) ?? 1);
  }

  int get _totalUnits {
    final raw = widget.request['units'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 1;
  }

  @override
  void initState() {
    super.initState();
    // Pre-set responded state from server flags
    final alreadyResponded = widget.request['hasResponded'] == true
        || widget.request['isMyActiveCommitment'] == true;
    if (alreadyResponded) {
      _responseSent = true;
      final committed = widget.request['myUnitsCommitted'];
      _committedUnits = committed is num ? committed.toInt() : 0;
    }
    _unitsToCommit = _unitsRemaining.clamp(1, _totalUnits.clamp(1, 99));
  }

  // ── Derived from donor profile ─────────────────────────────────────────────
  bool get _isRegistered => widget.donor['registered'] == true;

  /// True if the user is currently in a cooling period.
  bool get _isCooling {
    if (!_isRegistered) return false;
    final lastDonation = widget.donor['lastDonationDate'];
    if (lastDonation == null) return false;
    DateTime lastDate;
    try {
      lastDate = DateTime.parse(lastDonation.toString());
    } catch (_) {
      return false;
    }
    final stream = (widget.donor['donationStream'] as String? ?? '').toLowerCase();
    int coolingDays;
    if (stream.contains('platelet')) {
      coolingDays = 7;
    } else if (stream.contains('plasma')) {
      coolingDays = 28;
    } else {
      coolingDays = 90;
    }
    final coolingEnds = lastDate.add(Duration(days: coolingDays));
    return DateTime.now().isBefore(coolingEnds);
  }

  /// Days remaining in cooling period (0 if not cooling).
  int get _coolingDaysLeft {
    if (!_isCooling) return 0;
    final lastDonation = widget.donor['lastDonationDate'];
    if (lastDonation == null) return 0;
    DateTime lastDate;
    try {
      lastDate = DateTime.parse(lastDonation.toString());
    } catch (_) {
      return 0;
    }
    final stream = (widget.donor['donationStream'] as String? ?? '').toLowerCase();
    int coolingDays = stream.contains('platelet') ? 7 : stream.contains('plasma') ? 28 : 90;
    final coolingEnds = lastDate.add(Duration(days: coolingDays));
    return coolingEnds.difference(DateTime.now()).inDays.clamp(0, coolingDays);
  }

  String get _donorBloodGroup => widget.donor['bloodGroup'] as String? ?? '';

  // ── Urgency colour ─────────────────────────────────────────────────────────
  Color get _urgencyColor {
    switch (_urgency) {
      case 'Critical Red': return const Color(0xFFCC0000);
      case 'Urgent':       return const Color(0xFFD97706);
      default:             return const Color(0xFF2563EB);
    }
  }

  @override
  void dispose() {
    _friendNameCtrl.dispose();
    _friendPhoneCtrl.dispose();
    super.dispose();
  }

  // ── API call ───────────────────────────────────────────────────────────────
  Future<void> _respond() async {
    if (_submitting || _responseSent) return;
    setState(() => _submitting = true);

    final user = FirebaseAuth.instance.currentUser;
    try {
      await ApiService().respondToBloodRequest(
        _requestId,
        unitsCommitted: _unitsToCommit,
        responderName:  user?.displayName ?? '',
      );
      if (!mounted) return;
      setState(() {
        _responseSent    = true;
        _committedUnits  = _unitsToCommit;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('already_responded')) {
        // Server says already responded — treat as success
        setState(() { _responseSent = true; _committedUnits = _unitsToCommit; });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $msg'), backgroundColor: _red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Withdraw (cancel response) ─────────────────────────────────────────────
  Future<void> _withdraw() async {
    if (_withdrawing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Your Response?'),
        content: const Text(
          'This will remove your commitment and reopen the request for other donors. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _withdrawing = true);
    try {
      await ApiService().withdrawFromBloodRequest(_requestId);
      if (!mounted) return;
      setState(() {
        _responseSent    = false;
        _committedUnits  = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Response cancelled. The request is open again for other donors.'),
          duration: Duration(seconds: 3),
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: _red),
      );
    } finally {
      if (mounted) setState(() => _withdrawing = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroCard(),
                    const SizedBox(height: 16),
                    _buildRequestDetails(),
                    const SizedBox(height: 16),
                    if (_isCooling)
                      _buildCoolingSection()
                    else if (!_isRegistered)
                      _buildNotRegisteredSection()
                    else if (!_canDonate)
                      _buildIncompatibleSection()
                    else if (_responseSent || _isMyActiveCommitment)
                      _buildRespondedSection()
                    else if (_hasActiveCommitment)
                      _buildActiveCommitmentSection()
                    else
                      _buildCanDonateSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Emergency Response',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          _PulsingDot(),
          const SizedBox(width: 6),
          const Text('LIVE', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
          if (_expiresLabel.isNotEmpty) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_expiresLabel,
                  style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }

  // ── Hero card ──────────────────────────────────────────────────────────────
  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B0000), Color(0xFFC0152A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _red.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          // Blood group circle
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
            ),
            child: Center(
              child: Text(
                _bloodGroup,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _urgencyColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _urgencyColor.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    _urgency.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$_units unit${int.tryParse(_units) != 1 ? 's' : ''} of $_component',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                // Units remaining bar
                Row(
                  children: [
                    Text(
                      '$_unitsRemaining of $_units units still needed',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _totalUnits > 0 ? (_totalUnits - _unitsRemaining) / _totalUnits : 1.0,
                    minHeight: 5,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4ADE80)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Blood donation request',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  _area,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Request details ────────────────────────────────────────────────────────
  Widget _buildRequestDetails() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Request Details',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          _detailRow(Icons.location_on_outlined, 'Area', _area, Colors.blueAccent),
          const Divider(color: Colors.white12, height: 20),
          _detailRow(Icons.bloodtype_outlined, 'Blood group', _bloodGroup, Colors.redAccent),
          const Divider(color: Colors.white12, height: 20),
          _detailRow(Icons.info_outline, 'Status',
              _status[0].toUpperCase() + _status.substring(1), Colors.purpleAccent),
        ],
      ),
    );
  }

  // ── State: incompatible blood group ───────────────────────────────────────
  Widget _buildIncompatibleSection() {
    return Column(
      children: [
        _glassCard(
          border: Colors.redAccent.withValues(alpha: 0.4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.block, color: Colors.redAccent, size: 18),
                const SizedBox(width: 8),
                const Text('Blood group mismatch',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
              ]),
              const SizedBox(height: 8),
              Text(
                'This request needs $_bloodGroup blood. Your blood group is $_donorBloodGroup. '
                'You cannot donate directly, but you can still help by referring a friend who has $_bloodGroup blood.',
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildReferralForm(),
      ],
    );
  }

  // ── State: responded — show committed units + cancel button ───────────────
  Widget _buildRespondedSection() {
    return Column(
      children: [
        // Responded banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF15803D).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: 0.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: const [
                Icon(Icons.check_circle, color: Color(0xFF4ADE80), size: 24),
                SizedBox(width: 10),
                Text('Responded ✓',
                    style: TextStyle(color: Color(0xFF4ADE80), fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
              const SizedBox(height: 8),
              Text(
                _committedUnits > 0
                    ? 'You committed $_committedUnits unit${_committedUnits != 1 ? 's' : ''}. Check the request tracker for updates.'
                    : 'Your response is registered. Check the request tracker for updates.',
                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        const SizedBox(height: 10),

        // Cancel response button
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            onPressed: _withdrawing ? null : _withdraw,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: _withdrawing
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2))
                : const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 18),
            label: Text(
              _withdrawing ? 'Cancelling...' : 'Cancel My Response',
              style: const TextStyle(color: Colors.redAccent, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  // ── State: donor has active commitment on another request ──────────────────
  Widget _buildActiveCommitmentSection() {
    return Column(
      children: [
        _glassCard(
          border: Colors.amberAccent.withValues(alpha: 0.4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: const [
                Icon(Icons.lock_clock, color: Colors.amberAccent, size: 18),
                SizedBox(width: 8),
                Text('You have an active commitment',
                    style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 14)),
              ]),
              const SizedBox(height: 8),
              const Text(
                'You are already committed to donating for another request. '
                'A donor can only support one request at a time. '
                'Please complete or cancel your existing commitment first.',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Still let them refer a friend
        _buildReferralForm(),
      ],
    );
  }

  // ── Shared referral form (used in multiple sections) ───────────────────────
  Widget _buildReferralForm() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.people_outline, color: Colors.lightBlueAccent, size: 18),
            SizedBox(width: 8),
            Text('Refer a Friend',
                style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const SizedBox(height: 4),
          const Text('Share this request with someone who can donate.',
              style: TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 14),
          _inputField(_friendNameCtrl, 'Friend\'s Name', Icons.person_outline),
          const SizedBox(height: 10),
          _inputField(_friendPhoneCtrl, 'Friend\'s Phone', Icons.phone_outlined,
              type: TextInputType.phone),
          const SizedBox(height: 14),
          if (!_referralSent)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_friendNameCtrl.text.trim().isEmpty ||
                      _friendPhoneCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill in your friend\'s details.')),
                    );
                    return;
                  }
                  setState(() => _referralSent = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Referral sent for ${_friendNameCtrl.text.trim()}!'),
                      backgroundColor: const Color(0xFF0369A1),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0369A1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.send_outlined, color: Colors.white, size: 18),
                label: const Text('Send Referral',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          else
            Row(children: const [
              Icon(Icons.check_circle, color: Colors.lightBlueAccent, size: 20),
              SizedBox(width: 8),
              Text('Referral sent!',
                  style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold)),
            ]),
        ],
      ),
    );
  }

  // ── State: can donate ──────────────────────────────────────────────────────
  Widget _buildCanDonateSection() {
    return Column(
      children: [
        // Eligibility reminder
        _glassCard(
          border: Colors.greenAccent.withValues(alpha: 0.3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 18),
                  SizedBox(width: 8),
                  Text('You can donate!',
                      style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 10),
              _checkItem('Age 18 – 65 years'),
              _checkItem('Weight ≥ 50 kg'),
              _checkItem('Haemoglobin ≥ 12.5 g/dL'),
              _checkItem('No fever or active illness'),
              _checkItem('Last donation ≥ 3 months ago'),
              if (_donorBloodGroup.isNotEmpty) ...[
                const SizedBox(height: 6),
                _checkItem('Your blood group: $_donorBloodGroup'),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Respond button — swaps to a permanent banner once tapped
        if (!_responseSent) ...[
          // Unit picker
          _glassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('How many units can you donate?',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text('$_unitsRemaining unit${_unitsRemaining != 1 ? 's' : ''} still needed',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Decrement
                    GestureDetector(
                      onTap: () { if (_unitsToCommit > 1) setState(() => _unitsToCommit--); },
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: const Icon(Icons.remove, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Column(
                      children: [
                        Text(
                          '$_unitsToCommit',
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                        ),
                        const Text('unit(s)', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(width: 24),
                    // Increment
                    GestureDetector(
                      onTap: () {
                        if (_unitsToCommit < _unitsRemaining) setState(() => _unitsToCommit++);
                      },
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _respond,
              style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                disabledBackgroundColor: _red.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
                shadowColor: _red.withValues(alpha: 0.4),
              ),
              icon: _submitting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.favorite, color: Colors.white, size: 20),
              label: Text(
                _submitting ? 'Confirming...' : "Confirm — I'll Donate $_unitsToCommit Unit${_unitsToCommit != 1 ? 's' : ''}",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ] else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF15803D).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: 0.6)),
            ),
            child: Column(
              children: [
                Row(
                  children: const [
                    Icon(Icons.check_circle, color: Color(0xFF4ADE80), size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Responded ✓',
                      style: TextStyle(
                        color: Color(0xFF4ADE80),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _committedUnits > 0
                      ? 'You committed $_committedUnits unit${_committedUnits != 1 ? 's' : ''}. Check the request tracker for updates.'
                      : 'Your response has been registered. Check the request tracker for updates.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  // ── State: cooling period ──────────────────────────────────────────────────
  Widget _buildCoolingSection() {
    return Column(
      children: [
        // Cooling warning
        _glassCard(
          border: Colors.orangeAccent.withValues(alpha: 0.4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.hourglass_top_rounded, color: Colors.orangeAccent, size: 18),
                  SizedBox(width: 8),
                  Text("You're in a cooling period",
                      style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$_coolingDaysLeft days remaining before you can donate again.',
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 1 - (_coolingDaysLeft / 90).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'You cannot donate right now, but you can still help by referring a friend!',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildReferralForm(),
      ],
    );
  }

  // ── State: not a registered donor ─────────────────────────────────────────
  Widget _buildNotRegisteredSection() {
    return Column(
      children: [
        _glassCard(
          border: Colors.amberAccent.withValues(alpha: 0.4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.info_outline, color: Colors.amberAccent, size: 18),
                  SizedBox(width: 8),
                  Text('Register as a donor first',
                      style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                "You haven't registered as a donor yet. Register once with your blood group and donation history — it only takes a minute.",
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildReferralForm(),
      ],
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────
  Widget _glassCard({required Widget child, Color? border}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border ?? Colors.white.withValues(alpha: 0.1)),
      ),
      child: child,
    );
  }

  Widget _detailRow(IconData icon, String label, String value, Color color,
      {Widget? trailing}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 10)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
        ...?trailing != null ? [trailing] : null,
      ],
    );
  }

  Widget _checkItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Container(
            width: 16, height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFF15803D).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Color(0xFF4ADE80), size: 10),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _inputField(TextEditingController ctrl, String hint, IconData icon,
      {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white38, size: 16),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.lightBlueAccent),
        ),
      ),
    );
  }
}

// ── Pulsing dot ────────────────────────────────────────────────────────────────
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8, height: 8,
        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
      ),
    );
  }
}
