import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard.dart';
import 'home.dart';
import 'user_profile_store.dart';
import 'services/api_service.dart';

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _locationController = TextEditingController();
  final _donationHospitalController = TextEditingController();

  String? _selectedBloodGroup;
  String? _selectedGender;
  String? _selectedDonationType;
  DateTime? _dateOfBirth;
  DateTime? _lastDonationDate;
  bool? _donatedBefore;
  bool _emergencyAvailable = false;
  bool _consentAccepted = false;
  bool _healthHealthy = true;
  bool _hasRecentMedication = false;
  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  final Color themeRed = const Color(0xFF8B0E0E);
  bool _isCreatingAccount = false;

  Future<void> _createAccount() async {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (fullName.isEmpty || email.isEmpty || _phoneController.text.trim().isEmpty ||
        _cityController.text.trim().isEmpty || _stateController.text.trim().isEmpty ||
        _pincodeController.text.trim().isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill all required fields.')),
      );
      return;
    }
    if (_selectedBloodGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select blood group.')),
      );
      return;
    }
    final age = _dateOfBirth == null
        ? 0
        : DateTime.now().difference(_dateOfBirth!).inDays ~/ 365;
    if (_dateOfBirth == null || age < 18 || _selectedGender == null ||
        _donatedBefore == null || !_consentAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be 18+, answer all eligibility questions, and accept consent.')),
      );
      return;
    }
    if (_donatedBefore == true &&
        (_lastDonationDate == null || _selectedDonationType == null ||
            _donationHospitalController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add your last donation date, type, and hospital.')),
      );
      return;
    }
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters.')),
      );
      return;
    }

    setState(() => _isCreatingAccount = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await cred.user?.updateDisplayName(fullName);
      await UserProfileStore.saveBloodGroup(_selectedBloodGroup!);
      await ApiService().registerDonor(
        bloodGroup: _selectedBloodGroup!,
        donationStream: _selectedDonationType ?? 'Whole Blood',
        preScreeningAnswers: {'healthy': _healthHealthy, 'recentMedication': _hasRecentMedication},
        readyAnyTime: _donatedBefore != true,
        showToOthers: _donatedBefore != true,
        lastDonationDate: _donatedBefore == true ? _lastDonationDate : null,
        phone: _phoneController.text.trim(),
        dateOfBirth: _dateOfBirth,
        gender: _selectedGender!,
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
        preferredVenue: _locationController.text.trim(),
        lastDonationType: _selectedDonationType ?? '',
        lastDonationHospital: _donationHospitalController.text.trim(),
        healthEligibility: {'healthy': _healthHealthy, 'recentMedication': _hasRecentMedication},
        emergencyAvailable: _emergencyAvailable,
        consentAccepted: _consentAccepted,
      );
      if (!mounted) {
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardPage()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Account creation failed.')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Firebase setup issue.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile could not be saved: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreatingAccount = false);
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    for (final c in [_cityController, _stateController, _pincodeController,
        _locationController, _donationHospitalController]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(), // Disables elastic overscroll
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFE9EDF2)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF172033).withValues(alpha: 0.08),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- TOP LOGO & HEADER ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C0715), Color(0xFFD52845)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(Icons.water_drop_rounded,
                              color: Colors.white, size: 27),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Create your donor profile',
                                  style: TextStyle(color: Colors.white,
                                      fontSize: 20, fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3)),
                              SizedBox(height: 4),
                              Text('A few details help us connect you to the right opportunity.',
                                  style: TextStyle(color: Color(0xFFFFDDE2),
                                      fontSize: 12, height: 1.35)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  _sectionTitle('Personal details'),
                  _field(_fullNameController, 'Full Name *', 'Enter your full name'),
                  _field(_emailController, 'Email Address *', 'name@example.com',
                      keyboard: TextInputType.emailAddress),
                  _field(_phoneController, 'Mobile Number *', '10-digit mobile number',
                      keyboard: TextInputType.phone),
                  _dropdown('Blood Group', _selectedBloodGroup, _bloodGroups,
                      (v) => setState(() => _selectedBloodGroup = v)),
                  _dateField('Date of Birth / age eligibility', _dateOfBirth,
                      (d) => setState(() => _dateOfBirth = d)),
                  _dropdown('Gender', _selectedGender,
                      ['Female', 'Male', 'Other', 'Prefer not to say'],
                      (v) => setState(() => _selectedGender = v)),
                  _sectionTitle('Donation history'),
                  _yesNo('Have you donated blood before?', _donatedBefore,
                      (v) => setState(() => _donatedBefore = v)),
                  if (_donatedBefore == true) ...[
                    _dateField('Last blood donation date', _lastDonationDate,
                        (d) => setState(() => _lastDonationDate = d)),
                    _dropdown('Last donation type', _selectedDonationType,
                        ['Whole Blood', 'Platelets', 'Plasma'],
                        (v) => setState(() => _selectedDonationType = v)),
                    _field(_donationHospitalController, 'Last donation hospital',
                        'Hospital or blood bank name'),
                  ],
                  _sectionTitle('Donation preferences'),
                  _field(_locationController, 'Preferred Donation Location',
                      'City, hospital, or blood bank'),
                  _yesNo('Available for emergency donation?', _emergencyAvailable,
                      (v) => setState(() => _emergencyAvailable = v ?? false)),
                  _sectionTitle('Health eligibility'),
                  _yesNo('Are you feeling healthy today?', _healthHealthy,
                      (v) => setState(() => _healthHealthy = v ?? true)),
                  _yesNo('Taking recent medication?', _hasRecentMedication,
                      (v) => setState(() => _hasRecentMedication = v ?? false)),
                  _sectionTitle('Location'),
                  Row(children: [
                    Expanded(child: _field(_cityController, 'City *', 'Your city')),
                    const SizedBox(width: 10),
                    Expanded(child: _field(_stateController, 'State *', 'Your state')),
                  ]),
                  _field(_pincodeController, 'Pincode *', '6-digit pincode',
                      keyboard: TextInputType.number),
                  _sectionTitle('Security'),

                  _buildInputLabel('Create Password'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: _buildInputDecoration(hintText: '••••••••'),
                  ),
                  const SizedBox(height: 16),

                  _buildInputLabel('Confirm Password'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: _buildInputDecoration(hintText: '••••••••'),
                  ),
                  const SizedBox(height: 28),
                  CheckboxListTile(
                    value: _consentAccepted,
                    onChanged: (v) => setState(() => _consentAccepted = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('I agree to the Terms & Conditions and Privacy Policy.',
                        style: TextStyle(fontSize: 12, height: 1.4,
                            color: Color(0xFF667085))),
                  ),
                  const SizedBox(height: 12),

                  // --- SUBMIT BUTTON ---
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isCreatingAccount ? null : _createAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 5,
                        shadowColor: themeRed.withValues(alpha: 0.28),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isCreatingAccount) ...[
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Text(_isCreatingAccount ? 'Creating...' : 'Create Account',
                              style: const TextStyle(fontSize: 15,
                                  letterSpacing: 0.1, fontWeight: FontWeight.w800)),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- SIGN IN LINK ---
                  RichText(
                    text: TextSpan(
                      text: 'Already have an account? ',
                      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                      children: [
                        TextSpan(
                          text: 'Sign In',
                          style: TextStyle(
                            color: themeRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => const SignInPage()),
                              );
                            },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    'By creating an account, you agree to our Terms\nof Service and Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label, {bool isRed = false}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isRed ? themeRed : const Color(0xFF4B5563),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 12),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: themeRed,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 9),
            Text(title,
                style: const TextStyle(fontSize: 15, letterSpacing: -0.1,
                    fontWeight: FontWeight.w800, color: Color(0xFF172033))),
            const SizedBox(width: 10),
            const Expanded(child: Divider(color: Color(0xFFE8EBF0))),
          ],
        ),
      );

  Widget _field(TextEditingController controller, String label, String hint,
      {TextInputType keyboard = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        decoration: _buildInputDecoration(hintText: hint).copyWith(
          labelText: label,
          prefixIcon: Icon(_fieldIcon(label), size: 19,
              color: const Color(0xFF8993A4)),
        ),
      ),
    );
  }

  Widget _dropdown(String label, String? value, List<String> values,
      ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: _buildInputDecoration(hintText: 'Select $label')
            .copyWith(labelText: label,
                prefixIcon: Icon(_fieldIcon(label), size: 19,
                    color: const Color(0xFF8993A4))),
        items: values.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _dateField(String label, DateTime? value, ValueChanged<DateTime> onChanged) {
    final text = value == null
        ? ''
        : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        readOnly: true,
        controller: TextEditingController(text: text),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            firstDate: DateTime(1940),
            lastDate: DateTime.now(),
            initialDate: value ?? DateTime(1995),
          );
          if (picked != null) onChanged(picked);
        },
        decoration: _buildInputDecoration(hintText: 'Select date').copyWith(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_month_outlined, size: 18),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
      ),
    );
  }

  Widget _yesNo(String label, bool? value, ValueChanged<bool?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: _buildInputDecoration(hintText: '').copyWith(
            labelText: label,
            prefixIcon: const Icon(Icons.verified_user_outlined, size: 19,
                color: Color(0xFF8993A4))),
        child: Row(children: [
          Expanded(child: RadioListTile<bool>(
            dense: true, contentPadding: EdgeInsets.zero, value: true,
            groupValue: value, onChanged: onChanged, title: const Text('Yes'))),
          Expanded(child: RadioListTile<bool>(
            dense: true, contentPadding: EdgeInsets.zero, value: false,
            groupValue: value, onChanged: onChanged, title: const Text('No'))),
        ]),
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFFA3ACBA), fontSize: 13),
      labelStyle: const TextStyle(color: Color(0xFF667085), fontSize: 13),
      floatingLabelStyle: TextStyle(color: themeRed, fontSize: 13,
          fontWeight: FontWeight.w600),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
      filled: true,
      fillColor: const Color(0xFFFAFBFC),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E7EC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: themeRed, width: 1.8),
      ),
    );
  }

  IconData _fieldIcon(String label) {
    final value = label.toLowerCase();
    if (value.contains('email')) return Icons.mail_outline_rounded;
    if (value.contains('mobile')) return Icons.phone_outlined;
    if (value.contains('blood')) return Icons.bloodtype_outlined;
    if (value.contains('gender')) return Icons.person_outline_rounded;
    if (value.contains('city') || value.contains('state') ||
        value.contains('location') || value.contains('hospital')) {
      return Icons.location_on_outlined;
    }
    if (value.contains('pincode')) return Icons.pin_drop_outlined;
    return Icons.person_outline_rounded;
  }
}