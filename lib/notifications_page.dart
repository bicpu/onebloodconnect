import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'track_request_page.dart';
import 'donor_request_detail_page.dart';

/// Two-tab notification centre:
///   Tab 1 — Blood Requests (requests the user raised via RequestBloodPage)
///   Tab 2 — Donor Requests (requests the user sent to individual donors)
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with SingleTickerProviderStateMixin {
  static const Color _red    = Color(0xFFC0152A);
  static const Color _darkBg = Color(0xFF0F172A);
  static const Color _cardBg = Color(0xFF1E293B);

  late final TabController _tabs;

  // Blood requests
  List<Map<String, dynamic>> _bloodRequests = [];
  bool   _bloodLoading = true;
  String? _bloodError;

  // Donor requests (sent by this user)
  List<Map<String, dynamic>> _donorRequests = [];
  bool   _donorLoading = true;
  String? _donorError;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    _loadBlood();
    _loadDonor();
  }

  Future<void> _loadBlood() async {
    setState(() { _bloodLoading = true; _bloodError = null; });
    try {
      final data = await ApiService().getMyBloodRequests();
      if (mounted) setState(() { _bloodRequests = data; _bloodLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _bloodError = e.toString(); _bloodLoading = false; });
    }
  }

  Future<void> _loadDonor() async {
    setState(() { _donorLoading = true; _donorError = null; });
    try {
      final data = await ApiService().getMySentDonorRequests();
      if (mounted) setState(() { _donorRequests = data; _donorLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _donorError = e.toString(); _donorLoading = false; });
    }
  }


  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        backgroundColor: _darkBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Notifications',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _loadAll,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: _red,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Blood Requests'),
            Tab(text: 'Donor Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildBloodTab(),
          _buildDonorTab(),
        ],
      ),
    );
  }

  // ── Blood requests tab ─────────────────────────────────────────────────────
  Widget _buildBloodTab() {
    if (_bloodLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFFC0152A)));
    if (_bloodError != null) return _errorView(_bloodError!, _loadBlood);
    if (_bloodRequests.isEmpty) return _emptyView('No blood requests yet', 'Blood requests you raise will appear here.');
    return RefreshIndicator(
      onRefresh: _loadBlood,
      color: _red, backgroundColor: _cardBg,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: _bloodRequests.length,
        separatorBuilder: (_, idx) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _buildBloodCard(_bloodRequests[i]),
      ),
    );
  }

  Widget _buildBloodCard(Map<String, dynamic> r) {
    final status      = r['status']     as String? ?? 'pending';
    final bloodGroup  = r['bloodGroup'] as String? ?? '?';
    final hospital    = r['hospital']   as String? ?? 'Hospital';
    final units       = r['units']      ?? 1;
    final component   = r['component']  as String? ?? 'Whole Blood';
    final urgency     = r['urgency']    as String? ?? 'Urgent';
    final id          = r['_id']        as String? ?? '';
    final timeAgo     = _timeAgo(r['createdAt'] as String?);
    final isCancelled = status == 'cancelled';
    final isFulfilled = status == 'fulfilled';
    final color       = _bStatusColor(status);

    return GestureDetector(
      onTap: isCancelled ? null : () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => TrackRequestPage(requestId: id))),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isCancelled
              ? Colors.white.withValues(alpha: 0.06) : color.withValues(alpha: 0.35)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: isCancelled ? Colors.white.withValues(alpha: 0.05) : color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(bloodGroup, style: TextStyle(
                  color: isCancelled ? Colors.white38 : color,
                  fontWeight: FontWeight.w900, fontSize: 16)),
              Text('$units u', style: TextStyle(
                  color: isCancelled ? Colors.white24 : color.withValues(alpha: 0.7),
                  fontSize: 9)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(hospital,
                  style: TextStyle(color: isCancelled ? Colors.white38 : Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis)),
              if (timeAgo.isNotEmpty)
                Text(timeAgo, style: const TextStyle(color: Colors.white30, fontSize: 10)),
            ]),
            const SizedBox(height: 3),
            Text('$component · $urgency', style: const TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 8),
            Row(children: [
              Icon(_bStatusIcon(status), color: color, size: 13),
              const SizedBox(width: 4),
              Text(_bStatusLabel(status), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
              if (!isCancelled && !isFulfilled) ...[
                const SizedBox(width: 6),
                const Text('· Tap to track', style: TextStyle(color: Colors.white24, fontSize: 10)),
              ],
            ]),
          ])),
          if (!isCancelled && !isFulfilled)
            const Padding(padding: EdgeInsets.only(left: 6, top: 4),
                child: Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 18)),
        ]),
      ),
    );
  }

  // ── Donor requests tab ─────────────────────────────────────────────────────
  Widget _buildDonorTab() {
    if (_donorLoading) { return const Center(child: CircularProgressIndicator(color: Color(0xFFC0152A))); }
    if (_donorError != null) { return _errorView(_donorError!, _loadDonor); }
    if (_donorRequests.isEmpty) {
      return _emptyView('No donor requests sent', 'Requests you send to individual donors will appear here.');
    }
    return RefreshIndicator(
      onRefresh: _loadDonor,
      color: _red, backgroundColor: _cardBg,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: _donorRequests.length,
        separatorBuilder: (_, idx) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _buildDonorCard(_donorRequests[i]),
      ),
    );
  }

  Widget _buildDonorCard(Map<String, dynamic> r) {
    final status     = r['status']        as String? ?? 'pending';
    final bloodGroup = r['bloodGroup']    as String? ?? '?';
    final donorName  = r['donorName']     as String? ?? 'Donor';
    final hospital   = r['hospital']      as String? ?? 'Hospital';
    final units      = r['units']         ?? 1;
    final urgency    = r['urgency']       as String? ?? 'Urgent';
    final id         = r['_id']           as String? ?? '';
    final timeAgo    = _timeAgo(r['createdAt'] as String?);
    final color      = _dStatusColor(status);
    final isDone     = status == 'completed' || status == 'donated';
    final isClosed   = status == 'declined' || status == 'cancelled';

    return GestureDetector(
      onTap: isClosed ? null : () async {
        await Navigator.push(context, MaterialPageRoute(
            builder: (_) => DonorRequestDetailPage(requestId: id, isDonor: false)));
        _loadDonor();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardBg, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isClosed
              ? Colors.white.withValues(alpha: 0.06) : color.withValues(alpha: 0.35)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: isClosed ? Colors.white.withValues(alpha: 0.05) : color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(bloodGroup, style: TextStyle(
                  color: isClosed ? Colors.white38 : color,
                  fontWeight: FontWeight.w900, fontSize: 15)),
              Text('$units u', style: TextStyle(
                  color: isClosed ? Colors.white24 : color.withValues(alpha: 0.7), fontSize: 9)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('To $donorName',
                  style: TextStyle(color: isClosed ? Colors.white38 : Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis)),
              if (timeAgo.isNotEmpty)
                Text(timeAgo, style: const TextStyle(color: Colors.white30, fontSize: 10)),
            ]),
            const SizedBox(height: 3),
            Text('$hospital · $urgency',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Row(children: [
              Icon(_dStatusIcon(status), color: color, size: 13),
              const SizedBox(width: 4),
              Text(_dStatusLabel(status),
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
              if (!isClosed && !isDone) ...[
                const SizedBox(width: 6),
                const Text('· Tap to view', style: TextStyle(color: Colors.white24, fontSize: 10)),
              ],
            ]),
          ])),
          if (!isClosed && !isDone)
            const Padding(padding: EdgeInsets.only(left: 6, top: 4),
                child: Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 18)),
        ]),
      ),
    );
  }

  // ── Blood request status helpers ───────────────────────────────────────────
  Color _bStatusColor(String s) {
    switch (s) {
      case 'received':   return const Color(0xFF2563EB);
      case 'verifying':  return const Color(0xFFD97706);
      case 'preparing':  return const Color(0xFF7C3AED);
      case 'ready':
      case 'fulfilled':  return const Color(0xFF15803D);
      case 'cancelled':  return const Color(0xFF64748B);
      default:           return const Color(0xFF475569);
    }
  }
  IconData _bStatusIcon(String s) {
    switch (s) {
      case 'received':   return Icons.check_circle_outline;
      case 'verifying':  return Icons.search_outlined;
      case 'preparing':  return Icons.inventory_2_outlined;
      case 'ready':      return Icons.local_shipping_outlined;
      case 'fulfilled':  return Icons.favorite;
      case 'cancelled':  return Icons.cancel_outlined;
      default:           return Icons.hourglass_empty_outlined;
    }
  }
  String _bStatusLabel(String s) {
    switch (s) {
      case 'received':   return 'Request Received';
      case 'verifying':  return 'Verifying Eligibility';
      case 'preparing':  return 'Preparing Blood';
      case 'ready':      return 'Ready for Collection';
      case 'fulfilled':  return 'Fulfilled ✓';
      case 'cancelled':  return 'Cancelled';
      default:           return s[0].toUpperCase() + s.substring(1);
    }
  }

  // ── Donor request status helpers ───────────────────────────────────────────
  Color _dStatusColor(String s) {
    switch (s) {
      case 'pending':    return Colors.orangeAccent;
      case 'accepted':   return Colors.greenAccent;
      case 'completed':
      case 'donated':    return const Color(0xFF4ADE80);
      case 'declined':
      case 'cancelled':  return Colors.grey;
      default:           return Colors.white38;
    }
  }
  IconData _dStatusIcon(String s) {
    switch (s) {
      case 'pending':    return Icons.hourglass_top_rounded;
      case 'accepted':   return Icons.check_circle_outline;
      case 'completed':
      case 'donated':    return Icons.favorite;
      case 'declined':
      case 'cancelled':  return Icons.cancel_outlined;
      default:           return Icons.info_outline;
    }
  }
  String _dStatusLabel(String s) {
    switch (s) {
      case 'pending':    return 'Waiting for donor response';
      case 'accepted':   return 'Donor accepted ✓';
      case 'completed':
      case 'donated':    return 'Donation complete 🩸';
      case 'declined':   return 'Donor declined';
      case 'cancelled':  return 'Cancelled';
      default:           return s;
    }
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────
  String _timeAgo(String? iso) {
    if (iso == null) return '';
    try {
      final diff = DateTime.now().difference(DateTime.parse(iso).toLocal());
      if (diff.inMinutes < 1)  return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)   return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) { return ''; }
  }

  Widget _emptyView(String title, String sub) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.notifications_none_rounded,
          color: Colors.white.withValues(alpha: 0.15), size: 64),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text(sub, style: const TextStyle(color: Colors.white24, fontSize: 12), textAlign: TextAlign.center),
    ]),
  );

  Widget _errorView(String err, VoidCallback retry) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
      const SizedBox(height: 12),
      Text(err, style: const TextStyle(color: Colors.white54, fontSize: 13), textAlign: TextAlign.center),
      const SizedBox(height: 16),
      TextButton.icon(
        onPressed: retry,
        icon: const Icon(Icons.refresh, color: Color(0xFFC0152A)),
        label: const Text('Retry', style: TextStyle(color: Color(0xFFC0152A))),
      ),
    ]),
  );
}

