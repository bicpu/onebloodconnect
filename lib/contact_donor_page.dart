import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/api_service.dart';

/// Requester fills in patient + hospital details and sends a direct request
/// to the chosen donor from the Search page.
class ContactDonorPage extends StatefulWidget {
  /// The donor document from the search result.
  final Map<String, dynamic> donor;

  const ContactDonorPage({super.key, required this.donor});

  @override
  State<ContactDonorPage> createState() => _ContactDonorPageState();
}

class _ContactDonorPageState extends State<ContactDonorPage> {
  static const Color _red    = Color(0xFFC0152A);
  static const Color _sub    = Color(0xFF64748B);

  // ── Donor info (read-only) ─────────────────────────────────────────────────
  String get _donorRef      => widget.donor['publicRef']    as String? ?? '';
  String get _donorName      => widget.donor['fullName']     as String? ?? 'Donor';
  String get _donorBloodGroup => widget.donor['bloodGroup']  as String? ?? '?';
  String get _donorCity      => widget.donor['city']         as String? ?? '';
  String get _donorStream    => widget.donor['donationStream'] as String? ?? 'Whole Blood';

  // ── Form state ─────────────────────────────────────────────────────────────
  final _formKey        = GlobalKey<FormState>();
  final _patientName    = TextEditingController();
  final _patientAge     = TextEditingController();
  final _hospital       = TextEditingController();
  final _ward           = TextEditingController();
  final _bed            = TextEditingController();
  final _attender       = TextEditingController();
  final _contactPhone   = TextEditingController();
  final _requesterPhone = TextEditingController();

  String _gender    = 'Male';
  String _bloodGroup = 'O+';
  int    _units     = 1;
  String _component = 'Whole Blood';
  String _urgency   = 'Urgent';

  bool   _sending   = false;

  static const _genders    = ['Male', 'Female', 'Other'];
  static const _groups     = ['A+','A-','B+','B-','O+','O-','AB+','AB-'];
  static const _components = ['Whole Blood','PRBC (Packed Red)','Platelets','Fresh Frozen Plasma'];
  static const _urgencies  = ['Critical Red','Urgent','Standard'];

  @override
  void initState() {
    super.initState();
    // Pre-fill blood group with the donor's group
    if (_groups.contains(_donorBloodGroup)) _bloodGroup = _donorBloodGroup;
    // Pre-fill requester phone from Firebase
    final user = FirebaseAuth.instance.currentUser;
    if (user?.phoneNumber != null) _requesterPhone.text = user!.phoneNumber!;
  }

  @override
  void dispose() {
    for (final c in [_patientName, _patientAge, _hospital, _ward, _bed,
                     _attender, _contactPhone, _requesterPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Send ───────────────────────────────────────────────────────────────────
  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);

    final user = FirebaseAuth.instance.currentUser;

    try {
      await ApiService().sendDonorRequest(
        donorRef:      _donorRef,
        patientName:   _patientName.text.trim(),
        patientAge:    int.tryParse(_patientAge.text.trim()),
        patientGender: _gender,
        bloodGroup:    _bloodGroup,
        units:         _units,
        component:     _component,
        urgency:       _urgency,
        hospital:      _hospital.text.trim(),
        ward:          _ward.text.trim(),
        bedNumber:     _bed.text.trim(),
        attender:      _attender.text.trim(),
        contactPhone:  _contactPhone.text.trim(),
        requesterName:  user?.displayName ?? '',
        requesterPhone: _requesterPhone.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Request sent! You\'ll be notified when the donor responds.'),
          backgroundColor: Color(0xFF15803D),
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${e.toString()}'), backgroundColor: _red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Contact Donor',
            style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Donor info banner ───────────────────────────────────────
              _donorBanner(),
              const SizedBox(height: 20),

              // ── Patient details ─────────────────────────────────────────
              _section('Patient Details'),
              _field(_patientName, 'Patient Full Name *', Icons.person_outline, required: true),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _field(_patientAge, 'Age', Icons.cake_outlined,
                    type: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: _dropdown('Gender', _genders, _gender,
                    (v) => setState(() => _gender = v!))),
              ]),
              const SizedBox(height: 10),

              // Blood group + units row
              Row(children: [
                Expanded(child: _dropdown('Blood Group *', _groups, _bloodGroup,
                    (v) => setState(() => _bloodGroup = v!))),
                const SizedBox(width: 10),
                Expanded(child: _unitCounter()),
              ]),
              const SizedBox(height: 10),
              _dropdown('Component *', _components, _component,
                  (v) => setState(() => _component = v!)),
              const SizedBox(height: 10),
              _dropdown('Urgency *', _urgencies, _urgency,
                  (v) => setState(() => _urgency = v!)),

              const SizedBox(height: 20),

              // ── Hospital details ────────────────────────────────────────
              _section('Hospital Details'),
              _field(_hospital, 'Hospital / Facility Name *', Icons.local_hospital_outlined,
                  required: true),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _field(_ward, 'Ward', Icons.meeting_room_outlined)),
                const SizedBox(width: 10),
                Expanded(child: _field(_bed, 'Bed No.', Icons.bed_outlined)),
              ]),
              const SizedBox(height: 10),
              _field(_attender, 'Attender Name & Relation', Icons.people_outline),
              const SizedBox(height: 10),
              _field(_contactPhone, 'Contact Phone at Hospital *',
                  Icons.phone_outlined, required: true,
                  type: TextInputType.phone),

              const SizedBox(height: 20),

              // ── Your contact ────────────────────────────────────────────
              _section('Your Contact'),
              _field(_requesterPhone, 'Your Phone Number *',
                  Icons.phone_android_outlined, required: true,
                  type: TextInputType.phone),

              const SizedBox(height: 28),

              // ── Send button ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _sending ? null : _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _red,
                    disabledBackgroundColor: _red.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                    shadowColor: _red.withValues(alpha: 0.3),
                  ),
                  icon: _sending
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  label: Text(
                    _sending ? 'Sending...' : 'Send Request to Donor',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Center(
                child: Text(
                  'The donor will be notified and can accept or decline.',
                  style: TextStyle(color: _sub, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Donor banner ───────────────────────────────────────────────────────────
  Widget _donorBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B0000), Color(0xFFC0152A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: _red.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              _donorBloodGroup,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_donorName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 3),
                Text('$_donorStream · $_donorCity',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('DONOR', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Unit counter ───────────────────────────────────────────────────────────
  Widget _unitCounter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Units *', style: TextStyle(fontSize: 11, color: _sub, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () { if (_units > 1) setState(() => _units--); },
                icon: const Icon(Icons.remove, size: 18),
                color: _red,
                padding: EdgeInsets.zero,
              ),
              Expanded(
                child: Center(
                  child: Text('$_units',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                ),
              ),
              IconButton(
                onPressed: () { if (_units < 10) setState(() => _units++); },
                icon: const Icon(Icons.add, size: 18),
                color: _red,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
              color: _sub, letterSpacing: 0.5)),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, IconData icon,
      {bool required = false, TextInputType type = TextInputType.text}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      inputFormatters: type == TextInputType.phone
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))]
          : null,
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
      style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: Icon(icon, size: 16, color: Colors.grey.shade500),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _red)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.redAccent)),
      ),
    );
  }

  Widget _dropdown(String label, List<String> items, String value,
      ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: _sub, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: value,
          onChanged: onChanged,
          items: items.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _red)),
          ),
          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
          dropdownColor: Colors.white,
        ),
      ],
    );
  }
}
