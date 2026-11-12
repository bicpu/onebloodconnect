import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'services/api_service.dart';
import 'cooling_period_page.dart';

/// Full detail view for a DonorRequest.
///
/// [isDonor] = true  → shown to the donor (accept / decline / upload proof)
/// [isDonor] = false → shown to the requester (status + cancel)
class DonorRequestDetailPage extends StatefulWidget {
  final String requestId;
  final bool   isDonor;

  const DonorRequestDetailPage({
    super.key,
    required this.requestId,
    required this.isDonor,
  });

  @override
  State<DonorRequestDetailPage> createState() => _DonorRequestDetailPageState();
}

class _DonorRequestDetailPageState extends State<DonorRequestDetailPage> {
  static const Color _red    = Color(0xFFC0152A);
  static const Color _darkBg = Color(0xFF0F172A);

  Map<String, dynamic>? _request;
  bool   _loading  = true;
  bool   _acting   = false;
  String? _error;

  // Upload proof
  File? _photo;
  File? _slip;
  bool  _uploading = false;

  final _declineReasonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _declineReasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService().getDonorRequest(widget.requestId);
      if (mounted) setState(() { _request = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _accept() async {
    setState(() => _acting = true);
    try {
      await ApiService().acceptDonorRequest(widget.requestId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Request accepted! The requester has been notified.'),
              backgroundColor: Color(0xFF15803D), duration: Duration(seconds: 3)),
        );
      }
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: _red)); }
    } finally {
      if (mounted) { setState(() => _acting = false); }
    }
  }

  Future<void> _decline() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Decline Request', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _declineReasonCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Reason (optional)',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFC0152A))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _declineReasonCtrl.text.trim()),
            child: const Text('Decline', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (reason == null) return;

    setState(() => _acting = true);
    try {
      await ApiService().declineDonorRequest(widget.requestId, reason: reason);
      await _load();
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request declined.'), duration: Duration(seconds: 2))); }
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: _red)); }
    } finally {
      if (mounted) { setState(() => _acting = false); }
    }
  }

  Future<void> _cancelRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Cancel Request?', style: TextStyle(color: Colors.white)),
        content: const Text('The donor will be notified.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel Request', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _acting = true);
    try {
      await ApiService().cancelDonorRequest(widget.requestId);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: _red)); }
    } finally {
      if (mounted) { setState(() => _acting = false); }
    }
  }

  Future<void> _pickImage(bool isPhoto) async {
    final picker = ImagePicker();
    final file   = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
    if (file == null) return;
    setState(() {
      if (isPhoto) { _photo = File(file.path); }
      else { _slip  = File(file.path); }
    });
  }

  Future<String> _toBase64(File f) async {
    final bytes = await f.readAsBytes();
    final b64   = base64Encode(bytes);
    final ext   = f.path.split('.').last.toLowerCase();
    final mime  = ext == 'png' ? 'image/png' : 'image/jpeg';
    return 'data:$mime;base64,$b64';
  }

  Future<void> _submitProof() async {
    if (_photo == null || _slip == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add both your donation photo and doctor\'s slip.')),
      );
      return;
    }
    setState(() => _uploading = true);
    try {
      final photoUrl = await _toBase64(_photo!);
      final slipUrl  = await _toBase64(_slip!);

      final result = await ApiService().completeDonorRequest(
        widget.requestId,
        donationPhotoUrl: photoUrl,
        doctorSlipUrl:    slipUrl,
      );

      if (!mounted) return;

      final component = result['component']  as String? ?? 'Whole Blood';
      final name      = result['donorName']  as String? ?? 'Donor';
      final bg        = result['donorBloodGroup'] as String? ?? '';
      final int coolingDays = (result['coolingDays'] as num?)?.toInt() ?? 90;
      final String coolingNote = coolingDays == 7 ? '7 days'
          : coolingDays == 28 ? '28 days' : '3 months (90 days)';

      // Also update donor profile on client side
      try {
        await ApiService().updateDonorProfile({
          'showToOthers':  false,
          'readyAnyTime':  false,
          'bookingStatus': 'completed',
        });
      } catch (_) {}

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CoolingPeriodPage(
            bookingId:    (result['bookingId'] as String?) ?? '',
            donorName:    name,
            bloodGroup:   bg,
            component:    component,
            donatedAt:    DateTime.now(),
            coolingDays:  coolingDays,
            coolingNote:  coolingNote,
            facilityName: result['hospital'] as String? ?? 'Hospital',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $e'), backgroundColor: _red));
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: _darkBg,
        appBar: AppBar(backgroundColor: _darkBg, elevation: 0,
            leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context))),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFFC0152A))),
      );
    }
    if (_error != null || _request == null) {
      return Scaffold(
        backgroundColor: _darkBg,
        appBar: AppBar(backgroundColor: _darkBg, elevation: 0,
            leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context))),
        body: Center(child: Text(_error ?? 'Not found', style: const TextStyle(color: Colors.white54))),
      );
    }

    final r           = _request!;
    final status      = r['status']      as String? ?? 'pending';
    final bloodGroup  = r['bloodGroup']  as String? ?? '?';
    final hospital    = r['hospital']    as String? ?? '';
    final units       = r['units']       ?? 1;
    final component   = r['component']   as String? ?? 'Whole Blood';
    final urgency     = r['urgency']     as String? ?? 'Urgent';
    final patientName = r['patientName'] as String? ?? '';
    final ward        = r['ward']        as String? ?? '';
    final bed         = r['bedNumber']   as String? ?? '';
    final attender    = r['attender']    as String? ?? '';
    final phone       = r['contactPhone'] as String? ?? '';
    final reqPhone    = r['requesterPhone'] as String? ?? '';
    final reqName     = r['requesterName']  as String? ?? '';
    final donorNote   = r['donorNote']   as String? ?? '';
    final confirmedAt = r['confirmedAt'] as String?;

    final isPending   = status == 'pending';
    final isAccepted  = status == 'accepted';
    final isDone      = status == 'completed' || status == 'donated';
    final isDeclined  = status == 'declined';
    final isCancelled = status == 'cancelled';

    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        backgroundColor: _darkBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Request Details',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          children: [
            // ── Status banner ───────────────────────────────────────────
            _statusBanner(status, bloodGroup, units, urgency),
            const SizedBox(height: 16),

            // ── Patient + Hospital details ──────────────────────────────
            _glassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Patient Details'),
                  _row(Icons.person_outline,   'Patient',   patientName, Colors.lightBlueAccent),
                  _divider(),
                  _row(Icons.water_drop,       'Blood Group', '$bloodGroup · $units unit${units != 1 ? 's' : ''}', Colors.redAccent),
                  _divider(),
                  _row(Icons.science_outlined, 'Component', component, Colors.purpleAccent),
                  _divider(),
                  _row(Icons.warning_amber_rounded, 'Urgency', urgency, Colors.orangeAccent),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (hospital.isNotEmpty)
              _glassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Hospital Details'),
                    _row(Icons.local_hospital_outlined, 'Hospital', hospital, Colors.blueAccent),
                    if (ward.isNotEmpty) ...[_divider(), _row(Icons.meeting_room_outlined, 'Ward / Bed', '$ward${bed.isNotEmpty ? " · $bed" : ""}', Colors.cyanAccent)],
                    if (attender.isNotEmpty) ...[_divider(), _row(Icons.people_outline, 'Attender', attender, Colors.greenAccent)],
                    if (phone.isNotEmpty) ...[_divider(),
                      GestureDetector(
                        onTap: () { Clipboard.setData(ClipboardData(text: phone));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied: $phone'), duration: const Duration(seconds: 2))); },
                        child: _row(Icons.phone_outlined, 'Contact Phone', phone, Colors.orangeAccent,
                            trailing: const Icon(Icons.copy_outlined, color: Colors.white30, size: 14)),
                      ),
                    ],
                  ],
                ),
              ),

            // ── Contact info ────────────────────────────────────────────
            if ((reqName.isNotEmpty || reqPhone.isNotEmpty) && widget.isDonor) ...[
              const SizedBox(height: 12),
              _glassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Requester Contact'),
                    if (reqName.isNotEmpty)  _row(Icons.person_outline, 'Name',  reqName,  Colors.lightBlueAccent),
                    if (reqName.isNotEmpty && reqPhone.isNotEmpty) _divider(),
                    if (reqPhone.isNotEmpty)
                      GestureDetector(
                        onTap: () { Clipboard.setData(ClipboardData(text: reqPhone));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied: $reqPhone'), duration: const Duration(seconds: 2))); },
                        child: _row(Icons.phone_outlined, 'Phone', reqPhone, Colors.orangeAccent,
                            trailing: const Icon(Icons.copy_outlined, color: Colors.white30, size: 14)),
                      ),
                  ],
                ),
              ),
            ],

            // ── Confirmation details (after accept) ─────────────────────
            if (isAccepted && confirmedAt != null) ...[
              const SizedBox(height: 12),
              _glassCard(
                border: Colors.greenAccent.withValues(alpha: 0.4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: const [
                      Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
                      SizedBox(width: 6),
                      Text('Confirmed', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                    ]),
                    if (donorNote.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(donorNote, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
                    ],
                  ],
                ),
              ),
            ],

            // ── Upload proof section (donor, accepted) ──────────────────
            if (widget.isDonor && isAccepted) ...[
              const SizedBox(height: 20),
              _glassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Mark Donation Complete'),
                    const Text('Upload your selfie at the donation centre and the doctor\'s slip.',
                        style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
                    const SizedBox(height: 14),
                    _uploadTile('Donation Photo', _photo, () => _pickImage(true)),
                    const SizedBox(height: 10),
                    _uploadTile("Doctor's Slip / Receipt", _slip, () => _pickImage(false)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _uploading ? null : _submitProof,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF15803D),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _uploading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.upload_outlined, color: Colors.white, size: 18),
                        label: Text(_uploading ? 'Uploading...' : 'Submit & Enter Cooling Period',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Completion banner ───────────────────────────────────────
            if (isDone) ...[
              const SizedBox(height: 12),
              _glassCard(
                border: Colors.greenAccent.withValues(alpha: 0.4),
                child: Row(children: const [
                  Icon(Icons.favorite, color: Colors.greenAccent, size: 20),
                  SizedBox(width: 10),
                  Expanded(child: Text('Donation completed. Thank you for saving a life! 🩸',
                      style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4))),
                ]),
              ),
            ],

            if (isDeclined) ...[
              const SizedBox(height: 12),
              _glassCard(
                border: Colors.grey.withValues(alpha: 0.4),
                child: Row(children: const [
                  Icon(Icons.cancel_outlined, color: Colors.grey, size: 20),
                  SizedBox(width: 10),
                  Expanded(child: Text('The donor has declined this request.',
                      style: TextStyle(color: Colors.white54, fontSize: 13))),
                ]),
              ),
            ],

            if (isCancelled) ...[
              const SizedBox(height: 12),
              _glassCard(
                border: Colors.grey.withValues(alpha: 0.4),
                child: Row(children: const [
                  Icon(Icons.info_outline, color: Colors.grey, size: 20),
                  SizedBox(width: 10),
                  Expanded(child: Text('This request was cancelled.',
                      style: TextStyle(color: Colors.white54, fontSize: 13))),
                ]),
              ),
            ],

            const SizedBox(height: 24),

            // ── Action buttons ──────────────────────────────────────────
            if (widget.isDonor && isPending) ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _acting ? null : _accept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF15803D),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _acting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                  label: const Text('Accept & Agree to Donate',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: _acting ? null : _decline,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 18),
                  label: const Text('Decline Request',
                      style: TextStyle(color: Colors.white54, fontSize: 14)),
                ),
              ),
            ],

            if (!widget.isDonor && (isPending || isAccepted)) ...[
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: _acting ? null : _cancelRequest,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 18),
                  label: const Text('Cancel Request',
                      style: TextStyle(color: Colors.redAccent, fontSize: 14)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Status banner ──────────────────────────────────────────────────────────
  Widget _statusBanner(String status, String bloodGroup, dynamic units, String urgency) {
    Color color;
    String label;
    IconData icon;
    switch (status) {
      case 'pending':
        color = Colors.orangeAccent; label = 'Awaiting Response'; icon = Icons.hourglass_top_rounded; break;
      case 'accepted':
        color = Colors.greenAccent; label = 'Accepted — Donation Confirmed'; icon = Icons.check_circle_outline; break;
      case 'donated':
      case 'completed':
        color = const Color(0xFF4ADE80); label = 'Donation Complete ✓'; icon = Icons.favorite; break;
      case 'declined':
        color = Colors.grey; label = 'Declined'; icon = Icons.cancel_outlined; break;
      default:
        color = Colors.grey; label = status; icon = Icons.info_outline;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF8B0000), const Color(0xFFC0152A)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: _red.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
            ),
            child: Center(
              child: Text(bloodGroup, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$units unit${units != 1 ? 's' : ''} needed',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(urgency.toUpperCase(),
                      style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(icon, color: color, size: 14),
                  const SizedBox(width: 4),
                  Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Upload tile ────────────────────────────────────────────────────────────
  Widget _uploadTile(String label, File? file, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: file != null ? Colors.greenAccent.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(file != null ? Icons.check_circle : Icons.upload_file_outlined,
                color: file != null ? Colors.greenAccent : Colors.white38, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(file != null ? file.path.split('/').last : label,
                  style: TextStyle(
                      color: file != null ? Colors.white : Colors.white38,
                      fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ),
            Text(file != null ? 'Change' : 'Add',
                style: const TextStyle(color: Color(0xFFC0152A), fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────
  Widget _glassCard({required Widget child, Color? border}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: border ?? Colors.white.withValues(alpha: 0.1)),
    ),
    child: child,
  );

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(t, style: const TextStyle(color: Colors.white70, fontSize: 11,
        fontWeight: FontWeight.bold, letterSpacing: 0.5)),
  );

  Widget _divider() => Divider(color: Colors.white.withValues(alpha: 0.08), height: 18);

  Widget _row(IconData icon, String label, String value, Color color, {Widget? trailing}) =>
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 15),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
        const SizedBox(height: 1),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
      ])),
      ...?trailing != null ? [trailing] : null,
    ]);
}
