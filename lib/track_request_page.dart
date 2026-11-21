import 'dart:async';
import 'package:flutter/material.dart';
import 'services/api_service.dart';

/// Real-time tracking page for a blood request (requester's view).
/// Polls every 20 seconds. Shows live donor responses, referrals, and timeline.
class TrackRequestPage extends StatefulWidget {
  final String requestId;
  const TrackRequestPage({super.key, required this.requestId});

  @override
  State<TrackRequestPage> createState() => _TrackRequestPageState();
}

class _TrackRequestPageState extends State<TrackRequestPage> {
  static const Color _red   = Color(0xFFC0152A);
  static const Color _cardBg = Color(0xFFFFFFFF);

  Map<String, dynamic>? _request;
  bool   _loading  = true;
  bool   _cancelling = false;
  String? _error;
  Timer? _timer;

  // ── Derived ────────────────────────────────────────────────────────────────
  String get _status      => _request?['status']     as String? ?? 'received';
  String get _bloodGroup  => _request?['bloodGroup'] as String? ?? '–';
  String get _hospital    => _request?['hospital']   as String? ?? '–';
  String get _urgency     => _request?['urgency']    as String? ?? 'Urgent';
  String get _component   => _request?['component']  as String? ?? 'Whole Blood';
  String get _facilityReviewStatus =>
      _request?['facilityReviewStatus'] as String? ?? 'pending';
  String get _facilityReviewComment =>
      _request?['facilityReviewComment'] as String? ?? '';
  String get _phone       => _request?['contactPhone'] as String? ?? '';
  int    get _totalUnits  {
    final v = _request?['units']; return (v is num) ? v.toInt() : 1;
  }
  int    get _unitsRemaining {
    final v = _request?['unitsRemaining'];
    if (v is num) return v.toInt();
    return _totalUnits;
  }

  List<Map<String, dynamic>> get _responses {
    final raw = _request?['responses'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  List<Map<String, dynamic>> get _timeline {
    final raw = _request?['timeline'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  bool get _isClosed => _status == 'fulfilled' || _status == 'cancelled';

  @override
  void initState() {
    super.initState();
    _fetch();
    // Poll every 20 seconds
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (_loading && _request != null) return; // already showing data, silent refresh
    try {
      final data = await ApiService().getBloodRequest(widget.requestId);
      if (mounted) setState(() { _request = data; _loading = false; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Request?'),
        content: const Text('This will notify all donors who responded. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await ApiService().cancelBloodRequest(widget.requestId);
      await _fetch();
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: _red)); }
    } finally {
      if (mounted) { setState(() => _cancelling = false); }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Track Request',
            style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 17)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFFC0152A)),
            onPressed: () { setState(() => _loading = true); _fetch(); },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading && _request == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFC0152A)))
          : _error != null && _request == null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFFC0152A)),
        const SizedBox(height: 12),
        Text(_error!, textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B))),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: _red),
          onPressed: () { setState(() => _loading = true); _fetch(); },
          icon: const Icon(Icons.refresh, color: Colors.white),
          label: const Text('Retry', style: TextStyle(color: Colors.white)),
        ),
      ]),
    ),
  );

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _fetch,
      color: _red,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status + progress ─────────────────────────────────────────
            _buildStatusCard(),
            const SizedBox(height: 14),
            if (_request?['targetFacilityName'] != null &&
                (_request?['targetFacilityName'] as String).isNotEmpty)
              _buildFacilityReviewCard(),
            if (_request?['targetFacilityName'] != null &&
                (_request?['targetFacilityName'] as String).isNotEmpty)
              const SizedBox(height: 14),

            // ── Donor responses ───────────────────────────────────────────
            if (_responses.isNotEmpty) ...[
              _sectionHeader('Donors Who Responded', Icons.favorite),
              const SizedBox(height: 8),
              ..._responses.map(_buildResponseCard),
              const SizedBox(height: 14),
            ],

            // ── Waiting state ─────────────────────────────────────────────
            if (_responses.isEmpty && !_isClosed) ...[
              _buildSearchingCard(),
              const SizedBox(height: 14),
            ],

            // ── Timeline ──────────────────────────────────────────────────
            _sectionHeader('Activity Timeline', Icons.timeline),
            const SizedBox(height: 8),
            _buildTimeline(),
            const SizedBox(height: 14),

            // ── Request details ───────────────────────────────────────────
            _sectionHeader('Request Details', Icons.info_outline),
            const SizedBox(height: 8),
            _buildDetailsCard(),
            const SizedBox(height: 20),

            // ── Cancel button ─────────────────────────────────────────────
            if (!_isClosed)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _cancelling ? null : _cancel,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _red.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _cancelling
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC0152A)))
                      : const Icon(Icons.cancel_outlined, color: Color(0xFFC0152A), size: 18),
                  label: Text(_cancelling ? 'Cancelling…' : 'Cancel This Request',
                      style: const TextStyle(color: Color(0xFFC0152A), fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacilityReviewCard() {
    final accepted = _facilityReviewStatus == 'accepted';
    final rejected = _facilityReviewStatus == 'rejected';
    final color = accepted
        ? const Color(0xFF15803D)
        : rejected
            ? const Color(0xFFB91C1C)
            : const Color(0xFFD97706);
    final title = accepted
        ? 'Blood bank accepted your request'
        : rejected
            ? 'Blood bank declined your request'
            : 'Waiting for blood bank review';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(accepted
            ? Icons.check_circle_rounded
            : rejected
                ? Icons.cancel_rounded
                : Icons.pending_actions_rounded, color: color, size: 25),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: color,
                fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 4),
            Text(_request?['targetFacilityName'] as String? ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (_facilityReviewComment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_facilityReviewComment,
                  style: const TextStyle(color: Color(0xFF475569), height: 1.35)),
            ],
          ])),
      ]),
    );
  }

  // ── Status + units progress card ──────────────────────────────────────────
  Widget _buildStatusCard() {
    IconData statusIcon;
    String statusLabel;
    switch (_status) {
      case 'fulfilled':
        statusIcon = Icons.favorite;
        statusLabel = 'Fulfilled — All units committed ✓'; break;
      case 'cancelled':
        statusIcon = Icons.cancel_outlined;
        statusLabel = 'Cancelled'; break;
      default:
        statusIcon = Icons.radar;
        statusLabel = 'Searching for donors…';
    }

    final committed = _totalUnits - _unitsRemaining;
    final progress  = _totalUnits > 0 ? committed / _totalUnits : 0.0;

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Blood group + urgency row
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_bloodGroup,
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w900, fontSize: 20)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_hospital,
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis),
                Text('$_component · $_urgency',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
              ],
            )),
            Icon(statusIcon, color: Colors.white, size: 22),
          ]),

          const SizedBox(height: 14),

          // Units progress
          Row(children: [
            Text('$committed of $_totalUnits unit${_totalUnits != 1 ? 's' : ''} committed',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w600, fontSize: 13)),
            const Spacer(),
            Text(statusLabel,
                style: TextStyle(
                    color: _status == 'fulfilled'
                        ? const Color(0xFF4ADE80) : Colors.white.withValues(alpha: 0.8),
                    fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4ADE80)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Searching card (no responses yet) ─────────────────────────────────────
  Widget _buildSearchingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        const SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Color(0xFF2563EB)),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Searching for donors…',
                style: TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 13, color: Color(0xFF0F172A))),
            SizedBox(height: 3),
            Text('Your request has been broadcast to all eligible '
                'donors. This page updates every 20 seconds.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4)),
          ],
        )),
      ]),
    );
  }

  // ── Single donor response card ────────────────────────────────────────────
  Widget _buildResponseCard(Map<String, dynamic> r) {
    final name    = r['responderName'] as String? ?? 'Anonymous Donor';
    final group   = _bloodGroup;
    final units   = (r['unitsCommitted'] as num?)?.toInt() ?? 1;
    final initials = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    // Detect referral entries by their display label.
    final isReferral = name.toLowerCase().contains('refer') ||
        (r['referredName'] != null);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCFCE7)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        // Avatar
        CircleAvatar(
          radius: 22,
          backgroundColor: isReferral
              ? const Color(0xFFEFF6FF)
              : const Color(0xFFDCFCE7),
          child: Text(initials,
              style: TextStyle(
                  color: isReferral
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF15803D),
                  fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: const TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 14, color: Color(0xFF0F172A))),
            const SizedBox(height: 3),
            Row(children: [
              // Blood group badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(group,
                    style: const TextStyle(fontSize: 11,
                        color: Color(0xFFC0152A), fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 6),
              Text('$units unit${units != 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ]),
          ],
        )),
        // Confirmed badge
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF15803D).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Color(0xFF15803D), size: 14),
        ),
      ]),
    );
  }

  // ── Timeline ──────────────────────────────────────────────────────────────
  Widget _buildTimeline() {
    if (_timeline.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text('No activity yet.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
      );
    }

    // Reverse so newest is on top
    final events = _timeline.reversed.toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: events.asMap().entries.map((e) {
          final idx   = e.key;
          final event = e.value;
          final step  = event['step']  as String? ?? '';
          final note  = event['note']  as String? ?? '';
          final time  = event['time']  as String?;
          final isLast = idx == events.length - 1;

          Color dotColor;
          IconData dotIcon;
          if (step.toLowerCase().contains('fulfil')) {
            dotColor = const Color(0xFF15803D); dotIcon = Icons.favorite;
          } else if (step.toLowerCase().contains('cancel') ||
              step.toLowerCase().contains('expir') ||
              step.toLowerCase().contains('withdr')) {
            dotColor = const Color(0xFF64748B); dotIcon = Icons.cancel_outlined;
          } else if (step.toLowerCase().contains('respond')) {
            dotColor = const Color(0xFF2563EB); dotIcon = Icons.person_add_outlined;
          } else {
            dotColor = _red; dotIcon = Icons.water_drop;
          }

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                        color: dotColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: dotColor.withValues(alpha: 0.4), width: 1.5)),
                    child: Icon(dotIcon, color: dotColor, size: 14),
                  ),
                  if (!isLast)
                    Expanded(child: Container(
                        width: 1.5,
                        color: Colors.grey.shade200)),
                ]),
                const SizedBox(width: 12),
                Expanded(child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text(step,
                          style: const TextStyle(fontWeight: FontWeight.bold,
                              fontSize: 13, color: Color(0xFF0F172A))),
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(note,
                            style: const TextStyle(fontSize: 12,
                                color: Color(0xFF64748B), height: 1.3)),
                      ],
                      if (time != null) ...[
                        const SizedBox(height: 3),
                        Text(_formatTime(time),
                            style: const TextStyle(fontSize: 11,
                                color: Color(0xFF94A3B8))),
                      ],
                    ],
                  ),
                )),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Request details card ──────────────────────────────────────────────────
  Widget _buildDetailsCard() {
    final r = _request!;
    final rows = <Map<String, String>>[
      {'label': 'Patient',   'value': r['patientName']   as String? ?? '–'},
      {'label': 'Hospital',  'value': r['hospital']      as String? ?? '–'},
      if ((r['ward'] as String?)?.isNotEmpty == true)
        {'label': 'Ward / Bed', 'value': '${r['ward']} ${r['bedNumber'] ?? ''}'.trim()},
      {'label': 'Component', 'value': _component},
      {'label': 'Urgency',   'value': _urgency},
      if (_phone.isNotEmpty)
        {'label': 'Contact',   'value': _phone},
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: rows.asMap().entries.map((e) {
          final isLast = e.key == rows.length - 1;
          final row = e.value;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(row['label']!,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  Flexible(
                    child: Text(row['value']!,
                        style: const TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        textAlign: TextAlign.end),
                  ),
                ],
              ),
            ),
            if (!isLast) Divider(color: Colors.grey.shade100, height: 1),
          ]);
        }).toList(),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _sectionHeader(String title, IconData icon) {
    const sub = Color(0xFF64748B);
    return Row(children: [
      Icon(icon, size: 16, color: sub),
      const SizedBox(width: 6),
      Text(title, style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.bold,
          color: sub, letterSpacing: 0.4)),
    ]);
  }

  String _formatTime(String iso) {
    try {
      final dt   = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1)  return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)   return '${diff.inHours}h ago';
      return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }
}
