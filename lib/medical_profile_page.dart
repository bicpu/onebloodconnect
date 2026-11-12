import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/api_service.dart';

class MedicalProfilePage extends StatefulWidget {
  const MedicalProfilePage({super.key});

  @override
  State<MedicalProfilePage> createState() => _MedicalProfilePageState();
}

class _MedicalProfilePageState extends State<MedicalProfilePage> {
  static const primaryRed = Color(0xFFC8102E);
  static const bgLight = Color(0xFFF8FAFC);

  // Active state indicators
  bool isHealthDeclarationUpdated = false;
  bool isCardShared = false;

  // Donor data loaded from Firestore
  DateTime? _lastDonationDate;
  int? _lastDonationUnits;
  bool _readyAnyTime = false;
  bool _showToOthers = false;
  String? _preferredVenue;

  @override
  void initState() {
    super.initState();
    _loadDonorData();
  }

  Future<void> _loadDonorData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final data = await ApiService().getMyDonorProfile();
      if (data['registered'] == false) return;

      setState(() {
        if (data['lastDonationDate'] != null) {
          _lastDonationDate = DateTime.tryParse(data['lastDonationDate'] as String);
        }
        _lastDonationUnits = data['lastDonationUnits'] as int?;
        _readyAnyTime  = data['readyAnyTime']  == true;
        _showToOthers  = data['showToOthers']  == true;
        _preferredVenue = data['preferredVenue'] as String?;
      });
    } catch (e) {
      // ignore errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'One Blood Connect',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF475569)),
            onPressed: () {},
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: primaryRed,
              child: Icon(Icons.person, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Badge & ID
              Row(
                children: [
                  const Text(
                    'Medical Profile',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.share_outlined, color: Color(0xFF2563EB), size: 20),
                    onPressed: () => _showQrModal(),
                  ),
                  const Icon(Icons.verified, color: primaryRed, size: 20),
                ],
              ),
              Row(
                children: const [
                  Icon(Icons.circle, size: 6, color: primaryRed),
                  SizedBox(width: 4),
                  Text(
                    'VERIFIED DONOR • ID: OBC-MED-84920',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Health Centre Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.add_box_outlined, color: primaryRed, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Pondicherry University\nHealth Centre',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), height: 1.2),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryRed,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('ACTIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // User Info Card
              _buildDonorCard(),

              const SizedBox(height: 18),

              // Donation Eligibility
              _buildEligibilityCard(),

              const SizedBox(height: 18),

              // Donor Health Criteria
              _buildHealthCriteria(),

              const SizedBox(height: 18),

              // Medical Alerts & Notes
              _buildMedicalAlerts(),

              const SizedBox(height: 18),

              // Certificates & Documents
              _buildCertificatesSection(),

              const SizedBox(height: 18),

              // Emergency Contact
              _buildEmergencyContact(),

              const SizedBox(height: 20),

              // Action Buttons
              _buildActionButtons(),

              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: const [
                    Text('🔒 CONFIDENTIAL DONOR RECORD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    SizedBox(height: 2),
                    Text('Pondicherry University Lifesaver Network', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Donor Details Hero Box
  Widget _buildDonorCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: primaryRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('O-', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('TYPE', style: TextStyle(fontSize: 8, color: Colors.white70, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(FirebaseAuth.instance.currentUser?.displayName ?? 'Donor', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const SizedBox(width: 4),
                        const Icon(Icons.check_circle, size: 14, color: primaryRed),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('${FirebaseAuth.instance.currentUser?.displayName != null ? '' : ''}Rh Negative (D-) • Male, 21 yrs', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEAEA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.stars_outlined, size: 14, color: primaryRed),
                SizedBox(width: 6),
                Text('Universal Whole Blood Donor', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryRed)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Eligibility Timeline Progress Box
  Widget _buildEligibilityCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Donation Eligibility', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Text(_lastDonationDate != null ? (_lastDonationDate!.add(const Duration(days: 90)).difference(DateTime.now()).inDays > 0 ? 'In Cooldown' : 'Eligible Now') : 'Status', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryRed)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const CircleAvatar(
                radius: 14,
                backgroundColor: Color(0xFFF1F5F9),
                child: Icon(Icons.access_time, size: 16, color: primaryRed),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Next Eligible Donation', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text(
                      _lastDonationDate != null
                          ? '${_lastDonationDate!.day}/${_lastDonationDate!.month}/${_lastDonationDate!.year}'
                          : 'No record',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEAEA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _lastDonationDate != null ? '${(90 - DateTime.now().difference(_lastDonationDate!).inDays).clamp(0, 90)} Days Left' : '—',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryRed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _lastDonationDate != null ? (DateTime.now().difference(_lastDonationDate!).inDays / 90.0).clamp(0.0, 1.0) : 0.0,
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(primaryRed),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _lastDonationDate != null ? '${DateTime.now().difference(_lastDonationDate!).inDays} days elapsed' : 'No record',
                style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
              ),
              const Text('90-day standard interval', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
            ],
          ),
        ],
      ),
    );
  }

  // Health Criteria Check List
  Widget _buildHealthCriteria() {
    final criteria = [
      {'title': 'Age & Weight Criteria Met (68 kg)', 'status': 'Verified'},
      {'title': 'General Health Declaration Current', 'status': 'Cleared'},
      {'title': 'No Recent Surgeries or Tattoos (6+ mos)', 'status': 'Confirmed'},
      {'title': 'No Active Prohibited Medications', 'status': 'Passed'},
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Donor Health Criteria', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Text('All Passed', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
            ],
          ),
          const SizedBox(height: 10),
          ...criteria.map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 16, color: primaryRed),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(c['title']!, style: const TextStyle(fontSize: 11, color: Color(0xFF334155))),
                    ),
                    Text(c['status']!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // Medical Alert Box
  Widget _buildMedicalAlerts() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Medical Alerts & Notes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 16, color: primaryRed),
                        SizedBox(width: 6),
                        Text('Known Allergy: Penicillin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      ],
                    ),
                    Text('ALERT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: primaryRed)),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Mild rash history noted. Inform phlebotomist prior to medication administration.',
                  style: TextStyle(fontSize: 10, color: Color(0xFF475569), height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: const [
              Icon(Icons.verified_user_outlined, size: 12, color: Color(0xFF2563EB)),
              SizedBox(width: 4),
              Text('Blood Group record verified by PU Health Centre', style: TextStyle(fontSize: 9, color: Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }

  // Certificates & Documents with Download and View QR
  Widget _buildCertificatesSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Certificates & Documents', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Text('2 Available', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 12),

          // Certificate 1
          _buildDocTile(
            icon: Icons.article_outlined,
            iconBg: const Color(0xFFFFEAEA),
            iconColor: primaryRed,
            title: 'Blood Donor Certificate',
            subtitle: 'PU Health Centre • PDF',
            onView: () => _downloadSampleCertificate('Blood Donor Certificate'),
            onDownload: () => _downloadSampleCertificate('Blood Donor Certificate'),
          ),

          const SizedBox(height: 8),

          // Certificate 2 (With QR Pop-Up Action)
          _buildDocTile(
            icon: Icons.badge_outlined,
            iconBg: const Color(0xFFFFEAEA),
            iconColor: primaryRed,
            title: 'Health Clearance & Blood Pass',
            subtitle: 'Verified ID Pass • Digital QR',
            isQrAction: true,
            onView: () => _showQrModal(),
            onDownload: () => _downloadSampleCertificate('Health Clearance Pass'),
          ),
        ],
      ),
    );
  }

  // Document Tile Item
  Widget _buildDocTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    bool isQrAction = false,
    required VoidCallback onView,
    required VoidCallback onDownload,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: iconBg,
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Text(subtitle, style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
              ],
            ),
          ),
          IconButton(
            icon: Icon(isQrAction ? Icons.qr_code_2 : Icons.visibility_outlined, size: 18, color: const Color(0xFF2563EB)),
            onPressed: onView,
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined, size: 18, color: Color(0xFF64748B)),
            onPressed: onDownload,
          ),
        ],
      ),
    );
  }

  // Emergency Contact Section
  Widget _buildEmergencyContact() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Emergency Contact', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFFFEAEA),
                child: Icon(Icons.star, color: primaryRed, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Sarah Johnson', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('Primary Kin (Sister)', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    SizedBox(height: 2),
                    Text('+91 98421 90214', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.phone_in_talk, color: Color(0xFF2563EB), size: 20),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Calling Emergency Kin: +91 98421 90214...'), backgroundColor: primaryRed),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Interactive Buttons with Color Dynamic Feedback
  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isHealthDeclarationUpdated ? const Color(0xFF15803D) : primaryRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              setState(() {
                isHealthDeclarationUpdated = !isHealthDeclarationUpdated;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isHealthDeclarationUpdated ? 'Health Declaration Updated Successfully!' : 'Declaration Reset'),
                  backgroundColor: isHealthDeclarationUpdated ? const Color(0xFF15803D) : primaryRed,
                ),
              );
            },
            icon: Icon(isHealthDeclarationUpdated ? Icons.check : Icons.edit_note, color: Colors.white, size: 18),
            label: Text(
              isHealthDeclarationUpdated ? 'Health Declaration Updated' : 'Update Health Declaration',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: isCardShared ? const Color(0xFFDBEAFE) : const Color(0xFFEFF6FF),
              side: BorderSide(color: isCardShared ? const Color(0xFF2563EB) : const Color(0xFFBFDBFE)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              setState(() {
                isCardShared = !isCardShared;
              });
              _showQrModal();
            },
            icon: Icon(Icons.qr_code, color: const Color(0xFF2563EB), size: 18),
            label: Text(
              isCardShared ? 'Medical Pass Shared / Active' : 'Share Medical Card / Pass',
              style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  // Simulated Certificate Download Action
  void _downloadSampleCertificate(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.download_done, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('Downloading "$title.pdf"... Complete!')),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // QR Pass Dialog Popup Modal
  void _showQrModal() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Center(
            child: Column(
              children: const [
                Text('Verified Donor QR Pass', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                SizedBox(height: 2),
                Text('ID: OBC-MED-84920', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.qr_code, size: 160, color: Color(0xFF0F172A)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFFFEAEA), borderRadius: BorderRadius.circular(12)),
                      child: const Text('O- Universal Donor', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryRed)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('Alex Johnson', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const Text('Pondicherry University Lifesaver Network', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
              const SizedBox(height: 8),
              const Text(
                'Show this QR code at any affiliated health center or blood bank for instant verification.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Color(0xFF475569)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close Pass', style: TextStyle(color: primaryRed, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}