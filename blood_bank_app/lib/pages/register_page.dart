import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/bb_api.dart';

class RegisterPage extends StatefulWidget {
  final VoidCallback onHaveAccount;
  const RegisterPage({super.key, required this.onHaveAccount});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  static const Color _red = Color(0xFFC0152A);

  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameCtrl    = TextEditingController();
  final _regNoCtrl   = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _passwordCtrl= TextEditingController();
  final _confirm     = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl    = TextEditingController();
  final _stateCtrl   = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _hoursCtrl   = TextEditingController(text: '8:00 AM – 6:00 PM');
  final _websiteCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    for (final c in [_nameCtrl, _regNoCtrl, _emailCtrl, _passwordCtrl,
        _confirm, _phoneCtrl, _addressCtrl, _cityCtrl, _stateCtrl,
        _pincodeCtrl, _hoursCtrl, _websiteCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordCtrl.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      // 1. Create Firebase Auth account
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email:    _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      await cred.user?.updateDisplayName(_nameCtrl.text.trim());

      // 2. Save profile to backend
      await BbApi().register(
        name:           _nameCtrl.text.trim(),
        email:          _emailCtrl.text.trim(),
        phone:          _phoneCtrl.text.trim(),
        address:        _addressCtrl.text.trim(),
        city:           _cityCtrl.text.trim(),
        state:          _stateCtrl.text.trim(),
        pincode:        _pincodeCtrl.text.trim(),
        registrationNo: _regNoCtrl.text.trim(),
        hours:          _hoursCtrl.text.trim(),
        website:        _websiteCtrl.text.trim(),
      );
      // Auth stream triggers navigation automatically
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: _red,
        title: const Text('Register Blood Bank',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: const SizedBox.shrink(),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Center(
                child: Column(children: [
                  Container(
                    width: 72, height: 72,
                    decoration: const BoxDecoration(color: _red, shape: BoxShape.circle),
                    child: const Icon(Icons.local_hospital, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 12),
                  const Text('One Blood Connect',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A))),
                  const Text('Blood Bank Portal',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                ]),
              ),
              const SizedBox(height: 24),

              // ── Basic Info ───────────────────────────────────────────────
              _section('Basic Information'),
              _field(_nameCtrl,    'Blood Bank / Hospital Name *', Icons.add_business_outlined, required: true),
              const SizedBox(height: 10),
              _field(_regNoCtrl,   'Registration / Licence No.',   Icons.badge_outlined),
              const SizedBox(height: 10),
              _field(_phoneCtrl,   'Phone Number *', Icons.phone_outlined,
                  required: true, type: TextInputType.phone),
              const SizedBox(height: 10),
              _field(_hoursCtrl,   'Operating Hours *', Icons.access_time_outlined, required: true),
              const SizedBox(height: 10),
              _field(_websiteCtrl, 'Website (optional)', Icons.language_outlined),

              const SizedBox(height: 20),

              // ── Location ─────────────────────────────────────────────────
              _section('Location'),
              _field(_addressCtrl, 'Full Address *', Icons.location_on_outlined, required: true),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _field(_cityCtrl,  'City *',    Icons.location_city_outlined, required: true)),
                const SizedBox(width: 10),
                Expanded(child: _field(_stateCtrl, 'State *',   Icons.map_outlined,           required: true)),
              ]),
              const SizedBox(height: 10),
              _field(_pincodeCtrl, 'PIN Code *', Icons.pin_drop_outlined,
                  required: true, type: TextInputType.number),

              const SizedBox(height: 20),

              // ── Account credentials ──────────────────────────────────────
              _section('Login Credentials'),
              _field(_emailCtrl,    'Email Address *', Icons.email_outlined,
                  required: true, type: TextInputType.emailAddress),
              const SizedBox(height: 10),
              _passwordField(_passwordCtrl, 'Password * (min 6 chars)', required: true),
              const SizedBox(height: 10),
              _passwordField(_confirm, 'Confirm Password *', required: true),

              const SizedBox(height: 16),

              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: _red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!,
                        style: const TextStyle(color: _red, fontSize: 12))),
                  ]),
                ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Register Blood Bank',
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),

              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: widget.onHaveAccount,
                  child: const Text('Already registered? Sign In',
                      style: TextStyle(color: _red, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(t, style: const TextStyle(fontSize: 12,
        fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
  );

  Widget _field(TextEditingController c, String hint, IconData icon,
      {bool required = false, TextInputType type = TextInputType.text}) {
    return TextFormField(
      controller: c,
      keyboardType: type,
      inputFormatters: type == TextInputType.phone
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))]
          : type == TextInputType.number
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
      decoration: _dec(hint, icon),
    );
  }

  Widget _passwordField(TextEditingController c, String hint, {bool required = false}) {
    return TextFormField(
      controller: c,
      obscureText: _obscure,
      validator: required
          ? (v) => (v == null || v.trim().length < 6) ? 'Min 6 characters' : null
          : null,
      decoration: _dec(hint, Icons.lock_outline).copyWith(
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18, color: Colors.grey),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
    prefixIcon: Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFC0152A))),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent)),
  );
}
