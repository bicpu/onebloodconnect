import 'package:flutter/material.dart';
import 'request_sent_page.dart';
import 'services/api_service.dart';

class BloodBankRequestPage extends StatefulWidget {
  final Map<String, dynamic> bank;

  const BloodBankRequestPage({super.key, required this.bank});

  @override
  State<BloodBankRequestPage> createState() => _BloodBankRequestPageState();
}

class _BloodBankRequestPageState extends State<BloodBankRequestPage> {
  static const red = Color(0xFFC8102E);
  static const ink = Color(0xFF172033);
  static const muted = Color(0xFF718096);
  static const canvas = Color(0xFFF5F7FB);
  final _formKey = GlobalKey<FormState>();
  final _patient = TextEditingController();
  final _age = TextEditingController();
  final _hospital = TextEditingController();
  final _ward = TextEditingController();
  final _bed = TextEditingController();
  final _attender = TextEditingController();
  final _phone = TextEditingController();

  String _bloodGroup = 'O+';
  String _component = 'Whole Blood';
  String _urgency = 'Urgent';
  int _units = 1;
  bool _submitting = false;

  String get _name => widget.bank['name'] as String? ?? 'Blood Bank';
  String get _address => widget.bank['address'] as String? ?? '';
  String get _phoneNumber => widget.bank['phone'] as String? ?? '';
  String get _uid => widget.bank['uid'] as String? ?? '';

  @override
  void dispose() {
    for (final controller in [
      _patient, _age, _hospital, _ward, _bed, _attender, _phone
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() => _submitting = true);
    try {
      final request = await ApiService().createBloodRequest(
        patientName: _patient.text.trim(),
        patientAge: int.tryParse(_age.text.trim()) ?? 0,
        patientGender: 'Other',
        bloodGroup: _bloodGroup,
        units: _units,
        component: _component,
        urgency: _urgency,
        hospital: _hospital.text.trim(),
        ward: _ward.text.trim(),
        bedNumber: _bed.text.trim(),
        hubZone: _name,
        attender: _attender.text.trim(),
        contactPhone: _phone.text.trim(),
        targetFacilityName: _name,
        targetFacilityUid: _uid,
        targetFacilityAddress: _address,
        targetFacilityPhone: _phoneNumber,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RequestSentPage(requestId: request['_id'] as String),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send request: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: canvas,
      appBar: AppBar(
        titleSpacing: 4,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request blood', style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700)),
            Text('Send a secure request to your selected bank',
                style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: ink,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            _facilityCard(),
            const SizedBox(height: 22),
            const Text(
              'Provide the patient and requirement details below. The blood bank team will review your request and contact you.',
              style: TextStyle(fontSize: 13, color: muted, height: 1.45),
            ),
            const SizedBox(height: 14),
            _section('Patient details', [
              _field(_patient, 'Patient name', Icons.person_outline),
              _field(_age, 'Patient age', Icons.cake_outlined,
                  keyboard: TextInputType.number),
              _field(_hospital, 'Hospital / treatment location',
                  Icons.local_hospital_outlined),
              Row(
                children: [
                  Expanded(child: _field(_ward, 'Ward', Icons.meeting_room_outlined)),
                  const SizedBox(width: 10),
                  Expanded(child: _field(_bed, 'Bed number', Icons.bed_outlined)),
                ],
              ),
            ]),
            const SizedBox(height: 18),
            _section('Blood requirement', [
              _dropdown('Blood group', _bloodGroup,
                  ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'],
                  (value) => setState(() => _bloodGroup = value!)),
              _dropdown('Component', _component,
                  ['Whole Blood', 'PRBC (Packed Red)', 'Platelets', 'Plasma'],
                  (value) => setState(() => _component = value!)),
              _dropdown('Urgency', _urgency,
                  ['Critical Red', 'Urgent', 'Standard'],
                  (value) => setState(() => _urgency = value!)),
              Row(
                children: [
                  const Expanded(child: Text('Units required',
                      style: TextStyle(fontWeight: FontWeight.w600))),
                  IconButton(
                    onPressed: _units > 1
                        ? () => setState(() => _units--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('$_units', style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    onPressed: () => setState(() => _units++),
                    icon: const Icon(Icons.add_circle_outline, color: red),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 18),
            _section('Contact for this request', [
              _field(_attender, 'Attender name', Icons.contact_phone_outlined),
              _field(_phone, 'Contact phone', Icons.phone_outlined,
                  keyboard: TextInputType.phone),
            ]),
            const SizedBox(height: 22),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: red,
                  foregroundColor: Colors.white,
                  elevation: 3,
                  shadowColor: red.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _submitting
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_submitting
                    ? 'Sending request...'
                    : 'Send request to $_name'),
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 14, color: muted),
                SizedBox(width: 6),
                Text('Private request · Visible only to this blood bank',
                    style: TextStyle(fontSize: 11, color: muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _facilityCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE8EC), Color(0xFFFFF7F8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF7C5CD)),
        boxShadow: [
          BoxShadow(color: red.withValues(alpha: 0.08),
              blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: red,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: red.withValues(alpha: 0.24),
                    blurRadius: 12, offset: const Offset(0, 5)),
              ],
            ),
            child: const Icon(Icons.local_hospital_rounded,
                color: Colors.white, size: 27),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SELECTED BLOOD BANK',
                    style: TextStyle(fontSize: 10, letterSpacing: 1.1,
                        fontWeight: FontWeight.w700, color: muted)),
                const SizedBox(height: 4),
                Text(_name, style: const TextStyle(
                    fontSize: 17, color: ink, fontWeight: FontWeight.w700)),
                if (_address.isNotEmpty)
                  Text(_address, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12,
                          color: muted, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EAF0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A172033),
              blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 20,
                  decoration: BoxDecoration(color: red,
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(
                  fontSize: 16, color: ink, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          ...children.expand((child) => [child, const SizedBox(height: 12)]),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon,
      {TextInputType keyboard = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        validator: (value) {
          if (value == null || value.trim().isEmpty) return 'Required';
          if (controller == _age && int.tryParse(value.trim()) == null) {
            return 'Enter a valid age';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: const Color(0xFFF9FAFC),
          labelStyle: const TextStyle(color: muted),
          prefixIconColor: muted,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Color(0xFFE1E6EE)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Color(0xFFE1E6EE)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: red, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> values,
      ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF9FAFC),
        labelStyle: const TextStyle(color: muted),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFFE1E6EE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFFE1E6EE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: red, width: 1.5),
        ),
      ),
      items: values
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
