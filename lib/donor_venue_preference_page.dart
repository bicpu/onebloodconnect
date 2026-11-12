import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'book_hospital_slot_page.dart';
import 'dashboard.dart';
import 'profile.dart';
import 'services/api_service.dart';

class DonorVenuePreferencePage extends StatefulWidget {
  const DonorVenuePreferencePage({super.key});

  @override
  State<DonorVenuePreferencePage> createState() =>
      _DonorVenuePreferencePageState();
}

class _DonorVenuePreferencePageState extends State<DonorVenuePreferencePage> {
  static const Color primaryRed = Color(0xFFC8102E);
  static const Color darkText = Color(0xFF0F172A);
  static const Color subText = Color(0xFF64748B);
  static const Color cardBg = Color(0xFFF1F5F9);

  int selectedVenueIndex = 0;
  String? _selectedFacilityName;
  Map<String, dynamic>? _selectedFacility;
  bool _isSavingPreference = false;
  late Future<List<Map<String, dynamic>>> _facilitiesFuture;
  late Future<Map<String, dynamic>> _profileFuture;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // Temporary on-screen debug message
  String _debugMessage = '';

  @override
  void initState() {
    super.initState();
    _facilitiesFuture = ApiService().getAllDonationFacilities();
    _profileFuture = ApiService().getMyDonorProfile();
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfilePage()),
    );
  }

  void _goToDashboard() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const DashboardPage()),
      (route) => false,
    );
  }

  Future<void> _savePreferenceAndNavigate() async {
    if (_isSavingPreference) return;
    setState(() {
      _isSavingPreference = true;
      _debugMessage = 'Confirm pressed: processing...';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Processing...'), duration: Duration(seconds: 1)),
      );
    }

    // ignore: avoid_print
    print('[DonorVenue] _savePreferenceAndNavigate invoked; selectedVenueIndex=$selectedVenueIndex');

    final selectedVenue = _selectedFacilityName ??
        (selectedVenueIndex == 0 ? 'Hospital / Medical Center' : 'Campus Drive / Mobile Camp');

    if (_selectedFacility != null) {
      // Every live hospital or blood-bank facility opens slot booking.
      try {
        if (Navigator.of(context).canPop()) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => BookHospitalSlotPage(initialVenue: _selectedFacility)),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => BookHospitalSlotPage(initialVenue: _selectedFacility)),
          );
        }
        if (mounted) setState(() => _debugMessage = 'Navigated to BookHospitalSlotPage');
      } catch (e) {
        if (mounted) setState(() => _debugMessage = 'Navigation to booking failed');
        _goToDashboard();
      }

      _savePreferenceBackground(selectedVenue);
      if (mounted) setState(() => _isSavingPreference = false);
      return;
    }

    // Non-hospital: save then go to dashboard
    try {
      await ApiService().updateDonorProfile({
        'preferredVenue':        selectedVenue,
        'showToOthers':          true,
        'readyAnyTime':          true,
        'hospitalBookingActive': false,
        'bookingStatus':         'ready_to_donate',
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save preference: ${e.toString()}'), backgroundColor: primaryRed),
        );
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Venue preference saved successfully!'), backgroundColor: primaryRed),
    );
    _goToDashboard();
    if (mounted) setState(() => _isSavingPreference = false);
  }

  void _savePreferenceBackground(String selectedVenue) async {
    // ignore: avoid_print
    print('[DonorVenue] Background saving preference: $selectedVenue');
    if (mounted) setState(() => _debugMessage = 'Background saving preference...');
    try {
      await ApiService().updateDonorProfile({
        'preferredVenue':        selectedVenue,
        'showToOthers':          true,
        'readyAnyTime':          true,
        'hospitalBookingActive': false,
        'bookingStatus':         'ready_to_donate',
      });
      // ignore: avoid_print
      print('[DonorVenue] Background save complete');
      if (mounted) setState(() => _debugMessage = 'Background save complete');
    } catch (e) {
      // ignore: avoid_print
      print('[DonorVenue] Background save failed: ${e.toString()}');
      if (mounted) setState(() => _debugMessage = 'Background save failed: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _goToDashboard();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: const Color(0xFFC8102E),
              child: const Icon(
                Icons.water_drop,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          title: const Text(
            'One Blood Connect',
            style: TextStyle(
              color: darkText,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_none, color: darkText),
              onPressed: () {},
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: GestureDetector(
                onTap: _openProfile,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: primaryRed,
                  child: const Icon(Icons.person, color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
          floatingActionButton: _debugMessage.isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: () {
                    setState(() => _debugMessage = '');
                  },
                  backgroundColor: Colors.black87,
                  icon: const Icon(Icons.bug_report, color: Colors.white),
                  label: Text(
                    _debugMessage.length > 40 ? '${_debugMessage.substring(0, 40)}...' : _debugMessage,
                    style: const TextStyle(color: Colors.white),
                  ),
                )
              : null,
          body: FutureBuilder<Map<String, dynamic>>(
          future: _profileFuture,
          builder: (context, snapshot) {
            String userName = 'Donor';
            String bloodGroup = '--';
            String donorId = 'Not available';
            bool isUniversal = false;

            if (snapshot.hasData) {
              final data = snapshot.data!;
              if (data['registered'] == true) {
                userName   = (data['fullName'] as String? ?? 'Donor').split(' ').first;
                bloodGroup = data['bloodGroup'] as String? ?? '--';
                donorId    = data['_id'] as String? ?? 'Not available';
                isUniversal = bloodGroup == 'O-';
              }
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _goToDashboard,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              size: 18,
                              color: darkText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: primaryRed,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Registration Confirmed',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: darkText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.circle, size: 8, color: primaryRed),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: const Color(0xFFFFEAEA),
                                child: const Icon(
                                  Icons.volunteer_activism,
                                  color: primaryRed,
                                  size: 28,
                                ),
                              ),
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: primaryRed,
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Thank You, Lifesaver!',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: darkText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Welcome to One Blood Connect, $userName!\nYour single pledge can restore hope and\nsave up to 3 lives.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: subText,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: primaryRed,
                                  child: Text(
                                    bloodGroup,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'DONOR ID',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: subText,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      donorId,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: darkText,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                if (isUniversal)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFEAEA),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(
                                          Icons.star,
                                          size: 12,
                                          color: darkText,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Universal\nDonor',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: darkText,
                                            height: 1.1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Where Would You Prefer to\nDonate?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: darkText,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Choose your primary donation site so we can reserve your priority slot.',
                      style: TextStyle(fontSize: 12, color: subText),
                    ),
                    const SizedBox(height: 16),
                    _buildLiveFacilities(),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryRed,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _savePreferenceAndNavigate,
                        icon: const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Confirm Venue & Schedule Slot',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: _goToDashboard,
                        child: const Text(
                          "I'll Decide Later (Go to Home)",
                          style: TextStyle(
                            fontSize: 12,
                            color: subText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline, size: 12, color: subText),
                          SizedBox(width: 4),
                          Text(
                            'Pondicherry University Lifesaver Network • ICMR Verified',
                            style: TextStyle(fontSize: 10, color: subText),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLiveFacilities() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _facilitiesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _facilityMessage(
            Icons.cloud_off_outlined,
            'Facilities are temporarily unavailable',
            'Refresh the page or try again in a moment.',
          );
        }
        final banks = snapshot.data ?? [];
        if (banks.isEmpty) {
          return _facilityMessage(
            Icons.location_searching_rounded,
            'No hospitals or blood banks available',
            'Facilities will appear here once they are registered by the administrator.',
          );
        }
        if (_selectedFacilityName == null && banks.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedFacilityName == null) {
              setState(() {
                _selectedFacilityName =
                    banks.first['name']?.toString().trim().isNotEmpty == true
                        ? banks.first['name'].toString().trim()
                        : 'Blood bank';
                _selectedFacility = banks.first;
              });
            }
          });
        }
        return Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text('${banks.length} live donation facilities',
                  style: const TextStyle(fontSize: 12, color: subText,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 10),
            ...List.generate(banks.length, (index) {
              final bank = banks[index];
              final name = bank['name']?.toString().trim();
              final facilityName = name?.isNotEmpty == true ? name! : 'Blood bank';
              final address = bank['address']?.toString().trim() ?? '';
              final city = bank['city']?.toString().trim() ?? '';
              final hours = bank['hours']?.toString().trim() ?? '';
              final phone = bank['phone']?.toString().trim() ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildVenueCard(
                  index: index,
                  icon: Icons.local_hospital_outlined,
                  title: facilityName,
                  badgeText: bank['isVerified'] == true ? 'Verified facility' : 'Registered facility',
                  description: [address, city].where((v) => v.isNotEmpty).join(' • ').isEmpty
                      ? 'Live facility details are available for appointment booking.'
                      : [address, city].where((v) => v.isNotEmpty).join(' • '),
                  tags: [
                    if (hours.isNotEmpty) hours,
                    if (phone.isNotEmpty) phone,
                    'Real-time listing',
                  ],
                  facility: bank,
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _facilityMessage(IconData icon, String title, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Icon(icon, color: subText, size: 30),
        const SizedBox(height: 10),
        Text(title, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: darkText)),
        const SizedBox(height: 5),
        Text(message, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: subText, height: 1.4)),
      ]),
    );
  }

  Widget _buildVenueCard({
    required int index,
    required IconData icon,
    required String title,
    required String badgeText,
    required String description,
    required List<String> tags,
    Map<String, dynamic>? facility,
  }) {
    final bool isSelected = selectedVenueIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedVenueIndex = index;
          _selectedFacilityName = title;
          _selectedFacility = facility;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryRed : Colors.transparent,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryRed.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: const Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: darkText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeText,
                          style: const TextStyle(
                            fontSize: 9,
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? primaryRed : const Color(0xFFE2E8F0),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(fontSize: 11, color: subText, height: 1.4),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 10,
                      color: darkText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
