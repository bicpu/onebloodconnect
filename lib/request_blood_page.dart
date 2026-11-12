import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/api_service.dart';
import 'request_sent_page.dart';

class RequestBloodPage extends StatefulWidget {
  const RequestBloodPage({super.key});

  @override
  State<RequestBloodPage> createState() => _RequestBloodPageState();
}

class _RequestBloodPageState extends State<RequestBloodPage> {
  static const primaryRed = Color(0xFFC8102E);
  static const bgLight = Color(0xFFF8FAFC);

  // Form Controllers
  final _nameController = TextEditingController(text: 'Rohan Sharma');
  final _ageController = TextEditingController(text: '32');
  final _hospitalController = TextEditingController(text: 'JIPMER Super Speciality Hospital, Pondicherry');
  final _wardController = TextEditingController(text: 'ICU Tower B');
  final _bedController = TextEditingController(text: 'Bed #14');
  final _attenderController = TextEditingController(text: 'Ananya Sharma (Sister)');
  final _phoneController = TextEditingController(text: '9842170920');

  // Interactive States
  String selectedUrgency = 'Critical Red';
  String selectedGender = 'Male';
  String selectedBloodGroup = 'O+';
  int unitsRequired = 2;
  String selectedComponent = 'PRBC (Packed Red)';
  String selectedHubZone = 'JIPMER / Gorimedu';

  // Dispatch Toggles
  bool emergencyPush = true;
  bool notifyNss = true;
  bool declarationAccepted = true;

  // File Upload State
  String? uploadedFileName = 'JIPMER_ICU_Req_Slip_01.pdf';
  String uploadedFileSize = '1.2 MB';
  bool isFileUploaded = true;

  // Broadcast loading state
  bool _isBroadcasting = false;

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
              // Header Title & Verification Badge
              Row(
                children: [
                  const Text(
                    'Request Blood',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEAEA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.circle, size: 6, color: primaryRed),
                        SizedBox(width: 4),
                        Text(
                          'LIVE VERIFICATION',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: primaryRed),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Broadcast urgent medical requirements instantly to 12,400+ verified donors & regional university network blood banks.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
              ),

              const SizedBox(height: 16),

              // Urgency Protocol Section
              _buildUrgencyProtocol(),

              const SizedBox(height: 20),

              // Patient Profile Card
              _buildPatientProfileCard(),

              const SizedBox(height: 20),

              // Hospital Destination Card
              _buildHospitalDestinationCard(),

              const SizedBox(height: 20),

              // Attender & Verification Card with File Upload
              _buildAttenderAndVerificationCard(),

              const SizedBox(height: 20),

              // Dispatch & Radius Settings
              _buildDispatchSettings(),

              const SizedBox(height: 16),

              // Declaration Checkbox Box
              _buildDeclarationBox(),

              const SizedBox(height: 20),

              // Broadcast Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: declarationAccepted && !_isBroadcasting
                        ? primaryRed
                        : Colors.grey.shade400,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: declarationAccepted && !_isBroadcasting ? 2 : 0,
                  ),
                  onPressed: declarationAccepted && !_isBroadcasting
                      ? _broadcastRequest
                      : null,
                  icon: _isBroadcasting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.cell_tower, color: Colors.white, size: 18),
                  label: const Text(
                    'Broadcast Blood Request Now',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Center(
                child: Text(
                  '🔒 End-to-End Encrypted • 24/7 Desk Active • HIPAA Compliant',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Urgency Protocol Selector
  Widget _buildUrgencyProtocol() {
    final urgencyOptions = [
      {'title': 'Critical Red', 'sub': '< 15 Mins Immediate', 'color': primaryRed},
      {'title': 'Urgent', 'sub': '1 - 12 Hours', 'color': const Color(0xFF2563EB)},
      {'title': 'Standard', 'sub': '24 - 48 Hours', 'color': const Color(0xFF64748B)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('🚨 URGENCY PROTOCOL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
            Text('Determines alert radius', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: urgencyOptions.map((option) {
            final title = option['title'] as String;
            final isSelected = selectedUrgency == title;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => selectedUrgency = title),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected ? option['color'] as Color : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? option['color'] as Color : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        option['sub'] as String,
                        style: TextStyle(
                          fontSize: 9,
                          color: isSelected ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // 2. Patient Profile Card
  Widget _buildPatientProfileCard() {
    return _buildCardWrapper(
      title: '👤 Patient Profile',
      stepText: 'Step 1 of 3',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputLabel('PATIENT FULL NAME'),
          _buildTextField(_nameController, Icons.person_outline),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel('AGE (YEARS)'),
                    _buildTextField(_ageController, Icons.cake_outlined, isNumber: true),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel('BIOLOGICAL GENDER'),
                    Row(
                      children: ['Male', 'Female', 'Other'].map((g) {
                        final isSelected = selectedGender == g;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => selectedGender = g),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? primaryRed : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  g,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInputLabel('REQUIRED BLOOD GROUP'),
          const SizedBox(height: 6),
          _buildBloodGroupGrid(),
          const SizedBox(height: 12),
          _buildUnitsRequiredCounter(),
          const SizedBox(height: 12),
          _buildInputLabel('REQUIRED COMPONENT'),
          const SizedBox(height: 6),
          _buildComponentGrid(),
        ],
      ),
    );
  }

  // Blood Group Grid Selector
  Widget _buildBloodGroupGrid() {
    final groups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groups.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1.8,
      ),
      itemBuilder: (context, index) {
        final g = groups[index];
        final isSelected = selectedBloodGroup == g;
        return GestureDetector(
          onTap: () => setState(() => selectedBloodGroup = g),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected ? primaryRed : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isSelected ? primaryRed : Colors.transparent),
            ),
            child: Center(
              child: Text(
                g,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Units Increment/Decrement Counter
  Widget _buildUnitsRequiredCounter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Units Required', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Text('Standard 450ml per unit', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: primaryRed, size: 22),
                onPressed: unitsRequired > 1 ? () => setState(() => unitsRequired--) : null,
              ),
              Text(
                '$unitsRequired Units',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryRed),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: primaryRed, size: 22),
                onPressed: () => setState(() => unitsRequired++),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Component Selector Grid
  Widget _buildComponentGrid() {
    final components = [
      {'title': 'Whole Blood', 'icon': Icons.water_drop_outlined},
      {'title': 'PRBC (Packed Red)', 'icon': Icons.opacity},
      {'title': 'Platelets / RDP', 'icon': Icons.grain},
      {'title': 'Fresh Frozen Plasma', 'icon': Icons.local_pharmacy_outlined},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: components.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.5,
      ),
      itemBuilder: (context, index) {
        final c = components[index];
        final title = c['title'] as String;
        final isSelected = selectedComponent == title;

        return GestureDetector(
          onTap: () => setState(() => selectedComponent = title),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected ? primaryRed : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(c['icon'] as IconData, size: 16, color: isSelected ? Colors.white : primaryRed),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : const Color(0xFF334155),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 3. Hospital Destination Card
  Widget _buildHospitalDestinationCard() {
    return _buildCardWrapper(
      title: '🏥 Hospital Destination',
      actionText: '📍 Auto GPS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputLabel('HOSPITAL / MEDICAL CENTER'),
          _buildTextField(_hospitalController, Icons.location_on_outlined),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel('WARD / DEPARTMENT'),
                    _buildTextField(_wardController, null),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel('BED / ROOM NO.'),
                    _buildTextField(_bedController, null),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInputLabel('PONDICHERRY HUB ZONE'),
          const SizedBox(height: 6),
          Row(
            children: ['JIPMER / Gorimedu', 'PU Central Campus', 'MGMCRI'].map((zone) {
              final isSelected = selectedHubZone == zone;
              return GestureDetector(
                onTap: () => setState(() => selectedHubZone = zone),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFFEAEA) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? primaryRed : Colors.transparent),
                  ),
                  child: Text(
                    zone,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? primaryRed : const Color(0xFF475569),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 4. Attender & Verification Card (With File Upload / PDF Viewer)
  Widget _buildAttenderAndVerificationCard() {
    return _buildCardWrapper(
      title: '🛡️ Attender & Verification',
      actionText: '🔒 Encrypted',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputLabel('PRIMARY ATTENDER & RELATION'),
          _buildTextField(_attenderController, Icons.person_pin_outlined),
          const SizedBox(height: 12),
          _buildInputLabel('EMERGENCY CONTACT MOBILE'),
          _buildTextField(_phoneController, Icons.phone_outlined, isNumber: true),
          const SizedBox(height: 14),

          // File Upload / Doctor's Slip Attachment
          _buildInputLabel("HOSPITAL REQUISITION / DOCTOR'S SLIP"),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _showFileUploadModal,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isFileUploaded ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isFileUploaded ? const Color(0xFFBFDBFE) : const Color(0xFFCBD5E1),
                  style: isFileUploaded ? BorderStyle.solid : BorderStyle.none,
                ),
              ),
              child: isFileUploaded
                  ? Row(
                      children: [
                        const Icon(Icons.picture_as_pdf, color: primaryRed, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                uploadedFileName!,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$uploadedFileSize • Auto-Licensed',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _showFileUploadModal,
                          icon: const Icon(Icons.swap_horiz, size: 14, color: primaryRed),
                          label: const Text('Change', style: TextStyle(fontSize: 11, color: primaryRed, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    )
                  : Column(
                      children: const [
                        Icon(Icons.cloud_upload_outlined, color: primaryRed, size: 30),
                        SizedBox(height: 6),
                        Text('Tap to Upload Doctor Requisition Slip', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        SizedBox(height: 2),
                        Text('Supports PDF, JPG, PNG (Max 5MB)', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // Modal Sheet to Choose File (PDF / Camera / Gallery)
  void _showFileUploadModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Upload Requisition Slip', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Select doctor prescription or hospital request letter', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFFFEAEA), child: Icon(Icons.picture_as_pdf, color: primaryRed)),
                title: const Text('Choose PDF Document', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                onTap: () {
                  setState(() {
                    uploadedFileName = 'JIPMER_ICU_Req_Slip_01.pdf';
                    uploadedFileSize = '1.2 MB';
                    isFileUploaded = true;
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFEFF6FF), child: Icon(Icons.camera_alt, color: Color(0xFF2563EB))),
                title: const Text('Take Photo with Camera', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                onTap: () {
                  setState(() {
                    uploadedFileName = 'Captured_Prescription.jpg';
                    uploadedFileSize = '2.8 MB';
                    isFileUploaded = true;
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFF1F5F9), child: Icon(Icons.photo_library, color: Color(0xFF475569))),
                title: const Text('Choose Image from Gallery', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                onTap: () {
                  setState(() {
                    uploadedFileName = 'Requisition_Image.png';
                    uploadedFileSize = '850 KB';
                    isFileUploaded = true;
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 5. Dispatch Settings
  Widget _buildDispatchSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('📡 Dispatch & Radius Settings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: emergencyPush,
          activeThumbColor: primaryRed,
          onChanged: (val) => setState(() => emergencyPush = val),
          title: const Text('Emergency push to radius (15 km)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          subtitle: const Text('Notifies active donors on Pondicherry network', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: notifyNss,
          activeThumbColor: primaryRed,
          onChanged: (val) => setState(() => notifyNss = val),
          title: const Text('Notify Campus NSS & Youth Red Cross', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          subtitle: const Text('Direct emergency broadcast to student corps', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
        ),
      ],
    );
  }

  // 6. Declaration Box
  Widget _buildDeclarationBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: declarationAccepted,
              activeColor: primaryRed,
              onChanged: (val) => setState(() => declarationAccepted = val ?? false),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'I declare that this blood request is medically certified by the attending physician and is intended solely for critical clinical treatment under Pondicherry University health emergency protocol.',
              style: TextStyle(fontSize: 10, color: Color(0xFF475569), height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widgets
  Widget _buildCardWrapper({required String title, String? stepText, String? actionText, required Widget child}) {
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
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              if (stepText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFFFEAEA), borderRadius: BorderRadius.circular(10)),
                  child: Text(stepText, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryRed)),
                ),
              if (actionText != null)
                Text(actionText, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.6)),
    );
  }

  Widget _buildTextField(TextEditingController controller, IconData? icon, {bool isNumber = false}) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
        decoration: InputDecoration(
          prefixIcon: icon != null ? Icon(icon, size: 16, color: const Color(0xFF64748B)) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          filled: true,
          fillColor: const Color(0xFFF1F5F9),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Future<void> _broadcastRequest() async {
    if (_isBroadcasting) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to broadcast a request.')),
      );
      return;
    }

    setState(() => _isBroadcasting = true);

    try {
      final result = await ApiService().createBloodRequest(
        patientName:          _nameController.text.trim(),
        patientAge:           int.tryParse(_ageController.text.trim()) ?? 0,
        patientGender:        selectedGender,
        bloodGroup:           selectedBloodGroup,
        units:                unitsRequired,
        component:            selectedComponent,
        urgency:              selectedUrgency,
        hospital:             _hospitalController.text.trim(),
        ward:                 _wardController.text.trim(),
        bedNumber:            _bedController.text.trim(),
        hubZone:              selectedHubZone,
        attender:             _attenderController.text.trim(),
        contactPhone:         _phoneController.text.trim(),
        emergencyPushEnabled: emergencyPush,
        notifyNss:            notifyNss,
        attachmentFileName:   isFileUploaded ? uploadedFileName : null,
      );

      if (!mounted) return;

      // Navigate to RequestSentPage (confirmation) → it navigates to TrackRequestPage
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RequestSentPage(requestId: result['_id'] as String),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Broadcast failed: ${e.toString()}'),
          backgroundColor: primaryRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isBroadcasting = false);
    }
  }
}