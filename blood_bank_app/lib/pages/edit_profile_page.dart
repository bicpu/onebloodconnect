import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/bb_api.dart';

/// Edit blood bank profile: stock, hours, slots, doctors, nurses.
class EditProfilePage extends StatefulWidget {
  final bool basicOnly;
  const EditProfilePage({super.key, this.basicOnly = false});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  static const Color _red = Color(0xFFC0152A);
  static const List<String> _groups = ['A+','A-','B+','B-','O+','O-','AB+','AB-'];

  bool _loading = true;
  bool _saving  = false;
  String? _error;

  // Profile fields
  final _nameCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl    = TextEditingController();
  final _stateCtrl   = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _hoursCtrl   = TextEditingController();
  final _websiteCtrl = TextEditingController();

  // Stock — map group → controller
  final Map<String, TextEditingController> _stockCtrl = {
    for (final g in ['A+','A-','B+','B-','O+','O-','AB+','AB-'])
      g: TextEditingController(text: '0'),
  };

  // Slots
  final List<TextEditingController> _slotCtrls = [];

  // Doctors
  final List<Map<String, TextEditingController>> _doctorRows = [];

  // Nurses
  final List<Map<String, TextEditingController>> _nurseRows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _phoneCtrl, _addressCtrl, _cityCtrl,
        _stateCtrl, _pincodeCtrl, _hoursCtrl, _websiteCtrl]) {
      c.dispose();
    }
    for (final c in _stockCtrl.values) { c.dispose(); }
    for (final c in _slotCtrls) { c.dispose(); }
    for (final row in _doctorRows) { for (final c in row.values) { c.dispose(); } }
    for (final row in _nurseRows)  { for (final c in row.values) { c.dispose(); } }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await BbApi().getMe();
      if (!mounted) return;

      _nameCtrl.text    = p['name']    as String? ?? '';
      _phoneCtrl.text   = p['phone']   as String? ?? '';
      _addressCtrl.text = p['address'] as String? ?? '';
      _cityCtrl.text    = p['city']    as String? ?? '';
      _stateCtrl.text   = p['state']   as String? ?? '';
      _pincodeCtrl.text = p['pincode'] as String? ?? '';
      _hoursCtrl.text   = p['hours']   as String? ?? '8:00 AM – 6:00 PM';
      _websiteCtrl.text = p['website'] as String? ?? '';

      // Stock
      final rawStock = p['stock'];
      if (rawStock is Map) {
        rawStock.forEach((k, v) {
          if (_stockCtrl.containsKey(k)) {
            _stockCtrl[k]!.text = '${(v as num?)?.toInt() ?? 0}';
          }
        });
      }

      // Slots
      final slots = (p['slots'] as List?) ?? [];
      for (final s in slots) {
        _slotCtrls.add(TextEditingController(text: s.toString()));
      }

      // Doctors
      final doctors = (p['doctors'] as List?) ?? [];
      for (final d in doctors) {
        _doctorRows.add({
          'name':       TextEditingController(text: d['name']       ?? ''),
          'speciality': TextEditingController(text: d['speciality'] ?? ''),
          'phone':      TextEditingController(text: d['phone']      ?? ''),
          'available':  TextEditingController(text: d['available']  ?? ''),
        });
      }

      // Nurses
      final nurses = (p['nurses'] as List?) ?? [];
      for (final n in nurses) {
        _nurseRows.add({
          'name':  TextEditingController(text: n['name']  ?? ''),
          'phone': TextEditingController(text: n['phone'] ?? ''),
          'shift': TextEditingController(text: n['shift'] ?? ''),
        });
      }

      setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      // Build stock map (only groups with value > 0)
      final stock = <String, int>{};
      _stockCtrl.forEach((g, c) {
        final v = int.tryParse(c.text.trim()) ?? 0;
        if (v > 0) stock[g] = v;
      });

      final slots   = _slotCtrls.map((c) => c.text.trim())
          .where((s) => s.isNotEmpty).toList();

      final doctors = _doctorRows.map((row) => {
        'name':       row['name']!.text.trim(),
        'speciality': row['speciality']!.text.trim(),
        'phone':      row['phone']!.text.trim(),
        'available':  row['available']!.text.trim(),
      }).where((d) => (d['name'] as String).isNotEmpty).toList();

      final nurses = _nurseRows.map((row) => {
        'name':  row['name']!.text.trim(),
        'phone': row['phone']!.text.trim(),
        'shift': row['shift']!.text.trim(),
      }).where((n) => (n['name'] as String).isNotEmpty).toList();

      await BbApi().updateMe({
        'name':    _nameCtrl.text.trim(),
        'phone':   _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city':    _cityCtrl.text.trim(),
        'state':   _stateCtrl.text.trim(),
        'pincode': _pincodeCtrl.text.trim(),
        'website': _websiteCtrl.text.trim(),
        if (!widget.basicOnly) ...{
          'hours': _hoursCtrl.text.trim(),
          'stock': stock,
          'slots': slots,
          'doctors': doctors,
          'nurses': nurses,
        },
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved!'),
            backgroundColor: Color(0xFF15803D)));
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: _red,
        title: Text(widget.basicOnly ? 'Correct Bank Profile' : 'Edit Profile & Stock',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('SAVE',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFC0152A)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null) _errorBanner(),

                  // ── Basic Info ──────────────────────────────────────────
                  _section('Basic Information'),
                  _field(_nameCtrl,    'Blood Bank / Hospital Name', Icons.add_business_outlined),
                  const SizedBox(height: 10),
                  _field(_phoneCtrl,   'Phone Number', Icons.phone_outlined, type: TextInputType.phone),
                  const SizedBox(height: 10),
                  _field(_websiteCtrl, 'Website', Icons.language_outlined),
                  const SizedBox(height: 10),
                  _field(_addressCtrl, 'Address', Icons.location_on_outlined),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _field(_cityCtrl,    'City',    Icons.location_city_outlined)),
                    const SizedBox(width: 10),
                    Expanded(child: _field(_stateCtrl,   'State',   Icons.map_outlined)),
                  ]),
                  const SizedBox(height: 10),
                  _field(_pincodeCtrl, 'PIN Code', Icons.pin_drop_outlined, type: TextInputType.number),

                  if (!widget.basicOnly) ...[
                  _field(_hoursCtrl, 'Operating Hours', Icons.access_time_outlined),
                  const SizedBox(height: 20),

                  // ── Blood Stock ─────────────────────────────────────────
                  _section('Blood Stock (units)'),
                  const Text('Enter 0 for unavailable groups.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _groups.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4, crossAxisSpacing: 8,
                        mainAxisSpacing: 8, childAspectRatio: 1.1),
                    itemBuilder: (_, i) {
                      final g = _groups[i];
                      return Column(children: [
                        Text(g, style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13,
                            color: Color(0xFFC0152A))),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _stockCtrl[g],
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            filled: true, fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFC0152A))),
                          ),
                        ),
                      ]);
                    },
                  ),

                  const SizedBox(height: 20),

                  // ── Donation Slots ──────────────────────────────────────
                  _sectionRow('Donation Slots', () {
                    setState(() => _slotCtrls.add(TextEditingController()));
                  }),
                  const SizedBox(height: 8),
                  ..._slotCtrls.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Expanded(child: _timeSlotField(e.value)),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.red, size: 22),
                        onPressed: () => setState(() {
                          e.value.dispose();
                          _slotCtrls.removeAt(e.key);
                        }),
                      ),
                    ]),
                  )),

                  const SizedBox(height: 20),

                  // ── Doctors ─────────────────────────────────────────────
                  _sectionRow('Doctors', () {
                    setState(() => _doctorRows.add({
                      'name':       TextEditingController(),
                      'speciality': TextEditingController(),
                      'phone':      TextEditingController(),
                      'available':  TextEditingController(),
                    }));
                  }),
                  const SizedBox(height: 8),
                  ..._doctorRows.asMap().entries.map((e) {
                    final row = e.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(children: [
                        _field(row['name']!,       'Doctor Name *',    Icons.person_outline),
                        const SizedBox(height: 8),
                        _field(row['speciality']!, 'Speciality',       Icons.medical_services_outlined),
                        const SizedBox(height: 8),
                        _field(row['phone']!,      'Phone',            Icons.phone_outlined, type: TextInputType.phone),
                        const SizedBox(height: 8),
                        _field(row['available']!,  'Available (e.g. Mon–Fri 9AM–5PM)', Icons.event_available_outlined),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => setState(() {
                              for (final c in row.values) { c.dispose(); }
                              _doctorRows.removeAt(e.key);
                            }),
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red, size: 16),
                            label: const Text('Remove',
                                style: TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                        ),
                      ]),
                    );
                  }),

                  const SizedBox(height: 20),

                  // ── Nurses ──────────────────────────────────────────────
                  _sectionRow('Nurses', () {
                    setState(() => _nurseRows.add({
                      'name':  TextEditingController(),
                      'phone': TextEditingController(),
                      'shift': TextEditingController(),
                    }));
                  }),
                  const SizedBox(height: 8),
                  ..._nurseRows.asMap().entries.map((e) {
                    final row = e.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(children: [
                        _field(row['name']!,  'Nurse Name *', Icons.person_outline),
                        const SizedBox(height: 8),
                        _field(row['phone']!, 'Phone',        Icons.phone_outlined, type: TextInputType.phone),
                        const SizedBox(height: 8),
                        _field(row['shift']!, 'Shift (e.g. Morning / Evening)', Icons.schedule_outlined),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => setState(() {
                              for (final c in row.values) { c.dispose(); }
                              _nurseRows.removeAt(e.key);
                            }),
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red, size: 16),
                            label: const Text('Remove',
                                style: TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                        ),
                      ]),
                    );
                  }),

                  ],

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Save All Changes',
                              style: TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _errorBanner() => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(8)),
    child: Row(children: [
      const Icon(Icons.error_outline, color: _red, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(_error!,
          style: const TextStyle(color: _red, fontSize: 12))),
    ]),
  );

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(t, style: const TextStyle(fontSize: 12,
        fontWeight: FontWeight.bold, color: Color(0xFF64748B),
        letterSpacing: 0.5)),
  );

  Widget _sectionRow(String t, VoidCallback onAdd) => Row(children: [
    Expanded(child: Text(t,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
            color: Color(0xFF64748B), letterSpacing: 0.5))),
    TextButton.icon(
      onPressed: onAdd,
      icon: const Icon(Icons.add_circle_outline, size: 16, color: Color(0xFFC0152A)),
      label: const Text('Add', style: TextStyle(color: Color(0xFFC0152A),
          fontSize: 12, fontWeight: FontWeight.bold)),
    ),
  ]);

  Widget _field(TextEditingController c, String hint, IconData icon,
      {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: c,
      keyboardType: type,
      inputFormatters: type == TextInputType.phone
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))]
          : type == TextInputType.number
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
        prefixIcon: Icon(icon, size: 15, color: const Color(0xFF94A3B8)),
        filled: true, fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFC0152A))),
      ),
    );
  }

  Widget _timeSlotField(TextEditingController controller) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: _parseTime(controller.text) ??
              const TimeOfDay(hour: 9, minute: 0),
          helpText: 'Select donation slot time',
          cancelText: 'Cancel',
          confirmText: 'Set time',
        );
        if (!mounted || picked == null) return;
        controller.text = picked.format(context);
      },
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: 'Select time, e.g. 9:00 AM',
        hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
        prefixIcon: const Icon(Icons.schedule_rounded,
            size: 17, color: Color(0xFF94A3B8)),
        suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF94A3B8)),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFC0152A)),
        ),
      ),
    );
  }

  TimeOfDay? _parseTime(String value) {
    final match = RegExp(
      r'^\s*(\d{1,2}):(\d{2})\s*(AM|PM)\s*$',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null) return null;
    var hour = int.tryParse(match.group(1)!) ?? 0;
    final minute = int.tryParse(match.group(2)!) ?? 0;
    if (hour < 1 || hour > 12 || minute > 59) return null;
    final isPm = match.group(3)!.toUpperCase() == 'PM';
    if (hour == 12) hour = 0;
    if (isPm) hour += 12;
    return TimeOfDay(hour: hour, minute: minute);
  }
}
