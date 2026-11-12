import 'package:flutter/material.dart';
import '../services/admin_api.dart';

class AddDonorPage extends StatefulWidget {
  const AddDonorPage({super.key});
  @override
  State<AddDonorPage> createState() => _AddDonorPageState();
}

class _AddDonorPageState extends State<AddDonorPage> {
  static const Color red      = Color(0xFF8B0000);
  static const Color darkText = Color(0xFF0F172A);
  static const Color subText  = Color(0xFF64748B);

  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _cityCtrl     = TextEditingController();

  String _selectedBloodGroup = 'O+';
  String _selectedStream     = 'Whole Blood';
  bool   _saving  = false;
  String? _error;

  static const List<String> _bloodGroups = ['A+','A-','B+','B-','O+','O-','AB+','AB-'];
  static const List<String> _streams     = ['Whole Blood','Platelets (Apheresis)','Plasma','Power Red'];

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      await AdminApi().addManualDonor(
        fullName:       _nameCtrl.text.trim(),
        bloodGroup:     _selectedBloodGroup,
        phone:          _phoneCtrl.text.trim(),
        city:           _cityCtrl.text.trim(),
        donationStream: _selectedStream,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Donor added successfully!'), backgroundColor: Color(0xFF15803D)),
        );
        Navigator.pop(context);
      }
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
        backgroundColor: red,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Add Manual Donor', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFD97706), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This donor will appear in the Search page as an available donor with showToOthers enabled.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Donor Info ─────────────────────────────────────────────
              const Text('Donor Information',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: darkText)),
              const SizedBox(height: 10),

              // Name
              TextFormField(
                controller: _nameCtrl,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                decoration: _inputDec('Full Name', Icons.person_outline),
              ),
              const SizedBox(height: 12),

              // Phone
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                decoration: _inputDec('Phone Number', Icons.phone_outlined),
              ),
              const SizedBox(height: 12),

              // City
              TextFormField(
                controller: _cityCtrl,
                decoration: _inputDec('City / Area', Icons.location_city_outlined),
              ),
              const SizedBox(height: 20),

              // ── Blood Group ────────────────────────────────────────────
              const Text('Blood Group',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: darkText)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _bloodGroups.map((g) {
                  final selected = _selectedBloodGroup == g;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedBloodGroup = g),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? red : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: selected ? red : const Color(0xFFE2E8F0)),
                      ),
                      child: Text(g,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: selected ? Colors.white : darkText,
                          )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // ── Donation Stream ────────────────────────────────────────
              const Text('Donation Stream',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: darkText)),
              const SizedBox(height: 10),
              ...(_streams.map((s) {
                final selected = _selectedStream == s;
                return GestureDetector(
                  onTap: () => setState(() => _selectedStream = s),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFFFEAEA) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: selected ? red : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: selected ? red : subText, size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(s, style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          color: selected ? red : darkText,
                        )),
                      ],
                    ),
                  ),
                );
              }).toList()),

              const SizedBox(height: 20),

              // ── Error ──────────────────────────────────────────────────
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(color: red, fontSize: 12))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── Save ───────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.person_add, color: Colors.white),
                  label: Text(_saving ? 'Saving…' : 'Add Donor',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: red, size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    );
  }
}
