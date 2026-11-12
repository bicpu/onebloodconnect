import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/admin_api.dart';

class DonationsPage extends StatefulWidget {
  const DonationsPage({super.key});

  @override
  State<DonationsPage> createState() => _DonationsPageState();
}

class _DonationsPageState extends State<DonationsPage> {
  final _api = AdminApi();
  bool _loading = true;
  List<Map<String, dynamic>> _donations = [];
  int _filter = 0; // all, pending, approved, rejected, appealed

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final donations = await _api.getPendingDonations();
      if (mounted) setState(() => _donations = donations);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load donation proofs: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify(Map<String, dynamic> donation, bool approved) async {
    final id = donation['_id'] as String?;
    if (id == null) return;
    try {
      await _api.verifyDonation(id, approved: approved);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update donation: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _visible {
    if (_filter == 0) return _donations;
    const statuses = ['pending', 'approved', 'rejected', 'appealed'];
    return _donations
        .where((d) => d['proofStatus'] == statuses[_filter - 1])
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _visible.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 180),
                          Center(child: Text('No donations in this category')),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: _visible.length,
                          itemBuilder: (_, index) =>
                              _donationCard(_visible[index]),
                        ),
                ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final pending = _donations.where((d) => d['proofStatus'] == 'pending').length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: const Color(0xFFF1F5F9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Donation verification',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('$pending proof${pending == 1 ? '' : 's'} awaiting review',
              style: const TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('All', 0),
                _filterChip('Pending', 1),
                _filterChip('Approved', 2),
                _filterChip('Rejected', 3),
                _filterChip('Appealed', 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _filter == value,
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: const Color(0xFFFFE4E6),
        labelStyle: TextStyle(
          color: _filter == value
              ? const Color(0xFFB91C1C)
              : const Color(0xFF475569),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _donationCard(Map<String, dynamic> d) {
    final status = d['proofStatus'] as String? ?? 'pending';
    final approved = status == 'approved';
    final rejected = status == 'rejected';
    final appealed = status == 'appealed';
    final color = approved
        ? const Color(0xFF15803D)
        : rejected
            ? const Color(0xFFB91C1C)
            : appealed
                ? const Color(0xFF2563EB)
            : const Color(0xFFD97706);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            approved
                ? Icons.verified
                : rejected
                    ? Icons.cancel_outlined
                    : Icons.hourglass_top,
            color: color,
          ),
        ),
        title: Text(d['donorName'] ?? 'Unknown donor',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${d['bloodGroup'] ?? '--'} • ${d['component'] ?? 'Whole Blood'} • '
          '${d['units'] ?? 1} unit${d['units'] == 1 ? '' : 's'}',
        ),
        trailing: _statusBadge(status, color),
        children: [
          _detailGrid(d),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _proofImage(d['donationPhotoUrl'], 'Donation photo')),
              const SizedBox(width: 10),
              Expanded(child: _proofImage(d['doctorSlipUrl'], 'Doctor slip')),
            ],
          ),
          const SizedBox(height: 14),
          if (approved)
            _approvedBanner(d)
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _verify(d, false),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _verify(d, true),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                  ),
                ),
              ],
            ),
          if (d['appealReason']?.toString().isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _appealBanner(d['appealReason'].toString()),
          ],
        ],
      ),
    );
  }

  Widget _detailGrid(Map<String, dynamic> d) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _detail('Hospital / Blood bank', d['facilityName']),
          _detail('Address', d['facilityAddress']),
          _detail('Phone', d['facilityPhone']),
          _detail('Booking reference', d['bookingRef']),
          _detail('Donation date', _formatDate(d['donatedAt'])),
          _detail('Cooling ends', _formatDate(d['coolingEndsAt'])),
          _detail('Submitted at', _formatDate(d['updatedAt'])),
          if (d['certificateNo'] != null &&
              (d['certificateNo'] as String).isNotEmpty)
            _detail('Certificate', d['certificateNo']),
        ],
      ),
    );
  }

  Widget _detail(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 135,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(
              value?.toString().isNotEmpty == true ? value.toString() : '--',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _proofImage(dynamic raw, String label) {
    final value = raw?.toString() ?? '';
    Uint8List? bytes;
    if (value.startsWith('data:') && value.contains(',')) {
      try {
        bytes = base64Decode(value.substring(value.indexOf(',') + 1));
      } catch (_) {}
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          height: 130,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: bytes != null
              ? Image.memory(bytes, fit: BoxFit.cover)
              : const Center(
                  child: Text('No proof attached',
                      style: TextStyle(fontSize: 11))),
        ),
      ],
    );
  }

  Widget _statusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.toUpperCase(),
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _approvedBanner(Map<String, dynamic> d) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'Approved • Certificate ${d['certificateNo'] ?? 'issued'}\n'
        'This donation remains visible in Approved records.',
        style: const TextStyle(
            color: Color(0xFF166534), fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _appealBanner(String reason) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'User appeal:\n$reason',
        style: const TextStyle(
          color: Color(0xFF1D4ED8),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '--';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
