import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home.dart';
import 'donate_blood_page.dart';
import 'medical_profile_page.dart';
import 'user_profile_store.dart';
import 'widgets/floating_nav.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  static const Color themeRed = Color(0xFF8C1D18);
  static const Color themeBg = Color(0xFFF8F9FA);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _selectedIndex = 3;
  String _displayName = 'Donor';
  String _bloodGroup = '--';
  String _email = '';
  String _phone = '';
  String _city = '';
  String _state = '';
  Uint8List? _photoBytes;
  bool _registered = false;
  final List<String> _bloodGroups = const ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  // Stay signed in toggle (default true = do not auto logout)
  bool _staySignedIn = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    final bloodGroup = await UserProfileStore.getBloodGroup();
    Map<String, dynamic> profile = {};
    try {
      profile = await ApiService().getMyDonorProfile();
    } catch (_) {}
    Uint8List? photoBytes;
    if (profile['profilePhotoAvailable'] == true) {
      try {
        photoBytes = await ApiService().getMyProfilePhoto();
      } catch (_) {}
    }
    // load stay-signed-in preference
    try {
      final prefs = await SharedPreferences.getInstance();
      _staySignedIn = prefs.getBool('stay_signed_in') ?? true;
    } catch (_) {
      _staySignedIn = true;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _displayName = (profile['fullName']?.toString().trim().isNotEmpty == true)
          ? profile['fullName'].toString().trim()
          : user?.displayName?.trim().isNotEmpty == true
              ? user!.displayName!.trim()
          : 'Donor';
      _bloodGroup = (bloodGroup == null || bloodGroup.isEmpty) ? '--' : bloodGroup;
      _email = profile['email']?.toString() ?? user?.email ?? '';
      _phone = profile['phone']?.toString() ?? '';
      _city = profile['city']?.toString() ?? '';
      _state = profile['state']?.toString() ?? '';
      _photoBytes = photoBytes;
      _registered = profile['registered'] == true;
    });
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 700,
      imageQuality: 78,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final encoded = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    try {
      await ApiService().updateDonorProfile({'profilePhotoUrl': encoded});
      if (!mounted) return;
      setState(() => _photoBytes = bytes);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update photo: $e')),
      );
    }
  }

  Future<void> _showEditProfileDialog() async {
    final nameController = TextEditingController(text: _displayName);
    final phoneController = TextEditingController(text: _phone);
    final cityController = TextEditingController(text: _city);
    final stateController = TextEditingController(text: _state);
    String selectedGroup = _bloodGroups.contains(_bloodGroup) ? _bloodGroup : _bloodGroups.first;
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile Number'),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: cityController,
                    decoration: const InputDecoration(labelText: 'City'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: stateController,
                    decoration: const InputDecoration(labelText: 'State'))),
              ]),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (context, setLocalState) {
                  return DropdownButtonFormField<String>(
                    initialValue: selectedGroup,
                    items: _bloodGroups
                        .map((group) => DropdownMenuItem<String>(
                              value: group,
                              child: Text(group),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setLocalState(() {
                        selectedGroup = value;
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Blood Group'),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (shouldSave != true) {
      return;
    }

    final updatedName = nameController.text.trim();
    if (updatedName.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty.')),
      );
      return;
    }

    await FirebaseAuth.instance.currentUser?.updateDisplayName(updatedName);
    await UserProfileStore.saveBloodGroup(selectedGroup);
    await ApiService().updateDonorProfile({
      'fullName': updatedName,
      'bloodGroup': selectedGroup,
      'phone': phoneController.text.trim(),
      'city': cityController.text.trim(),
      'state': stateController.text.trim(),
    });
    phoneController.dispose();
    cityController.dispose();
    stateController.dispose();
    await _loadUserData();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated.')),
    );
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) {
        return;
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SignInPage()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Logout failed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProfilePage.themeBg,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _photoAvatar(54),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: ProfilePage.themeRed,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                color: Colors.white, size: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Text(
                          _displayName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _showEditProfileDialog,
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        color: ProfilePage.themeRed,
                        tooltip: 'Edit profile',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.location_on_outlined, size: 16,
                        color: Color(0xFF98A2B3)),
                    const SizedBox(width: 4),
                    Text(
                      [_city, _state].where((v) => v.trim().isNotEmpty).join(', ').isEmpty
                          ? 'Location not added'
                          : [_city, _state].where((v) => v.trim().isNotEmpty).join(', '),
                      style: const TextStyle(color: Color(0xFF667085), fontSize: 13),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.verified_outlined, size: 16, color: Color(0xFF0284C7)),
                        SizedBox(width: 6),
                        Text(
                          'Verified Donor',
                          style: TextStyle(
                            color: Color(0xFF0284C7),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  _buildInfoCard(),

                  const SizedBox(height: 20),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Your blood group',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: ProfilePage.themeRed,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: ProfilePage.themeRed.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _bloodGroup,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _registered ? 'Donor profile active' : 'Complete your donor profile',
                          style: const TextStyle(color: Color(0xFF667085), fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ProfilePage.themeRed,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            icon: const Icon(Icons.share_outlined, size: 18, color: Colors.white),
                            label: const Text(
                              'Share Status',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Stay signed in toggle — if enabled, app will not auto-logout the user
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Stay signed in (do not auto logout)',
                                style: TextStyle(fontSize: 14, color: Colors.black87),
                              ),
                            ),
                            Switch.adaptive(
                              value: _staySignedIn,
                              onChanged: (val) async {
                                setState(() => _staySignedIn = val);
                                try {
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setBool('stay_signed_in', val);
                                } catch (_) {
                                  // ignore storage errors
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(val ? 'Stay signed in enabled' : 'Stay signed in disabled')),
                                  );
                                }
                              },
                            ),
                          ],
                        ),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: ProfilePage.themeRed),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            icon: const Icon(Icons.download_outlined, size: 18, color: ProfilePage.themeRed),
                            label: const Text(
                              'Download Card',
                              style: TextStyle(color: ProfilePage.themeRed, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  _buildMenuTile(
                    icon: Icons.history_rounded,
                    iconBg: const Color(0xFFE0F2FE),
                    iconColor: const Color(0xFF0284C7),
                    title: 'Donation History',
                    subtitle: 'Past donations & dates',
                    onTap: () {},
                  ),
                  _buildMenuTile(
                    icon: Icons.medical_services_outlined,
                    iconBg: const Color(0xFFE0F2FE),
                    iconColor: const Color(0xFF0284C7),
                    title: 'Medical Profile',
                    subtitle: 'Registration details',
                    onTap: () async {
                      final ctx = context;
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please sign in to view your medical profile.')));
                        return;
                      }

                      // Check local cache first, then API
                      final prefs = await SharedPreferences.getInstance();
                      final localFlag = prefs.getBool('donor_registered_${user.uid}') ?? false;

                      bool registered = localFlag;
                      if (!registered) {
                        try {
                          final data = await ApiService().getMyDonorProfile();
                          registered = data['registered'] == true;
                        } catch (_) {
                          registered = false;
                        }
                      }

                      if (!mounted) return;

                      if (registered) {
                        Navigator.push(
                          ctx,
                          MaterialPageRoute(builder: (context) => const MedicalProfilePage()),
                        );
                      } else {
                        final go = await showDialog<bool>(
                          context: ctx,
                          builder: (context) => AlertDialog(
                            title: const Text('Complete Registration'),
                            content: const Text('You need to complete donor registration before viewing your medical profile. Go to registration now?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Go')),
                            ],
                          ),
                        );
                        if (!mounted) return;
                        if (go == true) {
                          Navigator.push(
                            ctx,
                            MaterialPageRoute(builder: (context) => const DonateBloodPage()),
                          );
                        }
                      }
                    },
                  ),
                  _buildMenuTile(
                    icon: Icons.workspace_premium_outlined,
                    iconBg: const Color(0xFFE0F2FE),
                    iconColor: const Color(0xFF0284C7),
                    title: 'Rewards & Badges',
                    subtitle: 'View achievements',
                    onTap: () {},
                  ),
                  _buildMenuTile(
                    icon: Icons.help_outline_rounded,
                    iconBg: const Color(0xFFE0F2FE),
                    iconColor: const Color(0xFF0284C7),
                    title: 'Help & Support',
                    onTap: () {},
                  ),
                  _buildMenuTile(
                    icon: Icons.settings_outlined,
                    iconBg: const Color(0xFFE0F2FE),
                    iconColor: const Color(0xFF0284C7),
                    title: 'Settings & Privacy',
                    onTap: () {},
                  ),
                  const SizedBox(height: 8),
                  _buildMenuTile(
                    icon: Icons.logout_rounded,
                    iconBg: const Color(0xFFFEE2E2),
                    iconColor: const Color(0xFFEF4444),
                    title: 'Log Out',
                    titleColor: const Color(0xFFDC2626),
                    showChevron: false,
                    onTap: _logout,
                  ),

                  const SizedBox(height: 110),
                ],
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 16,
              child: FloatingNav(selectedIndex: _selectedIndex),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7EAF0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Contact details', style: TextStyle(fontSize: 15,
            fontWeight: FontWeight.w800, color: Color(0xFF172033))),
        const SizedBox(height: 14),
        _detailRow(Icons.mail_outline_rounded, _email.isEmpty ? 'Email not available' : _email),
        const SizedBox(height: 10),
        _detailRow(Icons.phone_outlined, _phone.isEmpty ? 'Mobile number not added' : _phone),
      ]),
    );
  }

  Widget _detailRow(IconData icon, String value) {
    return Row(children: [
      Icon(icon, size: 18, color: ProfilePage.themeRed),
      const SizedBox(width: 10),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13,
          color: Color(0xFF667085), fontWeight: FontWeight.w500))),
    ]);
  }

  Widget _photoAvatar(double radius) {
    if (_photoBytes != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(_photoBytes!),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFFFE7EA),
      child: Text(
        _displayName.isEmpty ? 'D' : _displayName.trim()[0].toUpperCase(),
        style: TextStyle(color: ProfilePage.themeRed, fontSize: radius * .62,
            fontWeight: FontWeight.w800),
      ),
    );
  }

  static Widget _buildMenuTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    String? subtitle,
    Color titleColor = const Color(0xFF1E293B),
    bool showChevron = true,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: titleColor,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              )
            : null,
        trailing: showChevron ? const Icon(Icons.chevron_right_rounded, color: Colors.grey) : null,
      ),
    );
  }
}
