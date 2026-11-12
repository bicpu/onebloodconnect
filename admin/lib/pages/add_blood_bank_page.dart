import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/admin_api.dart';

class AddBloodBankPage extends StatefulWidget {
  const AddBloodBankPage({super.key});
  @override
  State<AddBloodBankPage> createState() => _AddBloodBankPageState();
}

class _AddBloodBankPageState extends State<AddBloodBankPage> {
  static const Color red     = Color(0xFF8B0000);
  static const Color darkText = Color(0xFF0F172A);
  static const Color subText  = Color(0xFF64748B);

  final _formKey     = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _cityCtrl    = TextEditingController();
  final _hoursCtrl   = TextEditingController(text: '8:00 AM – 6:00 PM');

  // Blood group stock fields
  final List<String> _groups = ['A+','A-','B+','B-','O+','O-','AB+','AB-'];
  final Map<String, TextEditingController> _stockCtrl = {};

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final g in _groups) {
      _stockCtrl[g] = TextEditingController(text: '0');
    }
  }

  @override
  void dispose() {
    for (final c in _stockCtrl.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });

    final stock = <String, int>{};
    for (final g in _groups) {
      final v = int.tryParse(_stockCtrl[g]!.text.trim()) ?? 0;
      if (v > 0) stock[g] = v;
    }

    try {
      await AdminApi().createBloodBank(
        name:    _nameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        phone:   _phoneCtrl.text.trim(),
        city:    _cityCtrl.text.trim(),
        hours:   _hoursCtrl.text.trim(),
        stock:   stock,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Blood bank added successfully!'), backgroundColor: Color(0xFF15803D)),
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
        title: const Text('Add Blood Bank', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Basic Info ─────────────────────────────────────────────
              _section('Basic Information'),
              _field(_nameCtrl,    'Blood Bank / Hospital Name', Icons.add_business,     required: true),
              _field(_addressCtrl, 'Address',                     Icons.location_on,      required: true),
              _field(_cityCtrl,    'City',                         Icons.location_city,    required: true),
              _field(_phoneCtrl,   'Phone Number',                 Icons.phone,
                required: true, type: TextInputType.phone),
              _field(_hoursCtrl,   'Operating Hours',              Icons.access_time),

              const SizedBox(height: 20),

              // ── Stock ──────────────────────────────────────────────────
              _section('Current Blood Stock (units)'),
              const Text('Enter 0 for unavailable blood groups.',
                  style: TextStyle(fontSize: 12, color: subText)),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _groups.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.1),
                itemBuilder: (_, i) {
                  final g = _groups[i];
                  return Column(
                    children: [
                      Text(g, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: red)),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _stockCtrl[g],
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

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
                      : const Icon(Icons.save_outlined, color: Colors.white),
                  label: Text(_saving ? 'Saving…' : 'Save Blood Bank',
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

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: darkText)),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool required = false, TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: type,
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: red, size: 20),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
      ),
    );
  }
}
