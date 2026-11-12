import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'donor_request_detail_page.dart';

/// Shown when a registered donor taps the inbox icon.
/// Lists all incoming contact requests from other users.
class DonorRequestInboxPage extends StatefulWidget {
  const DonorRequestInboxPage({super.key});

  @override
  State<DonorRequestInboxPage> createState() => _DonorRequestInboxPageState();
}

class _DonorRequestInboxPageState extends State<DonorRequestInboxPage> {
  static const Color _red    = Color(0xFFC0152A);
  static const Color _darkBg = Color(0xFF0F172A);
  static const Color _cardBg = Color(0xFF1E293B);

  List<Map<String, dynamic>> _requests = [];
  bool   _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService().getDonorRequestInbox();
      if (mounted) setState(() { _requests = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Color _statusColor(String s) {
    switch (s) {
      case 'pending':   return Colors.orangeAccent;
      case 'accepted':  return Colors.greenAccent;
      case 'donated':
      case 'completed': return const Color(0xFF4ADE80);
      case 'declined':  return Colors.grey;
      default:          return Colors.white38;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'pending':   return Icons.hourglass_top_rounded;
      case 'accepted':  return Icons.check_circle_outline;
      case 'donated':
      case 'completed': return Icons.favorite;
      case 'declined':  return Icons.cancel_outlined;
      default:          return Icons.info_outline;
    }
  }

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
        title: const Text('Donation Requests',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _load,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFC0152A)))
          : _error != null
              ? _buildError()
              : _requests.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: _red,
                      backgroundColor: _cardBg,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        itemCount: _requests.length,
                        separatorBuilder: (_, idx) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _buildCard(_requests[i]),
                      ),
                    ),
    );
  }

  Widget _buildCard(Map<String, dynamic> r) {
    final status        = r['status']        as String? ?? 'pending';
    final bloodGroup    = r['bloodGroup']    as String? ?? '?';
    final hospital      = r['hospital']      as String? ?? 'Hospital';
    final requesterName = r['requesterName'] as String? ?? 'Someone';
    final units         = r['units']         ?? 1;
    final urgency       = r['urgency']       as String? ?? 'Urgent';
    final id            = r['_id']           as String? ?? '';
    final timeAgo       = _timeAgo(r['createdAt'] as String?);
    final color         = _statusColor(status);
    final isPending     = status == 'pending';

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DonorRequestDetailPage(requestId: id, isDonor: true)),
        );
        _load(); // refresh after returning
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPending ? Colors.orangeAccent.withValues(alpha: 0.5) : color.withValues(alpha: 0.25),
            width: isPending ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Blood group badge
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(bloodGroup,
                      style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
                  Text('$units u', style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 9)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(requesterName.isNotEmpty ? 'From $requesterName' : 'Anonymous request',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    Text(timeAgo, style: const TextStyle(color: Colors.white30, fontSize: 10)),
                  ]),
                  const SizedBox(height: 3),
                  Text('$hospital · $urgency',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(_statusIcon(status), color: color, size: 13),
                    const SizedBox(width: 4),
                    Text(_statusLabel(status),
                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                    if (isPending) ...[
                      const SizedBox(width: 8),
                      const Text('· Tap to respond',
                          style: TextStyle(color: Colors.white24, fontSize: 10)),
                    ],
                  ]),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':   return 'Awaiting your response';
      case 'accepted':  return 'Accepted';
      case 'donated':
      case 'completed': return 'Donation complete ✓';
      case 'declined':  return 'Declined';
      default:          return s;
    }
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.inbox_outlined, color: Colors.white.withValues(alpha: 0.15), size: 64),
        const SizedBox(height: 16),
        const Text('No requests yet',
            style: TextStyle(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('When someone contacts you for blood, it appears here.',
            style: TextStyle(color: Colors.white24, fontSize: 12), textAlign: TextAlign.center),
      ],
    ),
  );

  Widget _buildError() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: Colors.white54, fontSize: 13), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh, color: Color(0xFFC0152A)),
          label: const Text('Retry', style: TextStyle(color: Color(0xFFC0152A))),
        ),
      ],
    ),
  );
}
