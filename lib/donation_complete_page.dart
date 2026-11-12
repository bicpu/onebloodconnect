import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'services/api_service.dart';
import 'donation_processing_page.dart';

class DonationCompletePage extends StatefulWidget {
  final String bookingId;
  final String donorName;
  final String bloodGroup;
  final String component;
  final DateTime slotDate;
  final String slotTime;
  final int coolingDays;
  final String coolingNote;
  final String facilityName;

  const DonationCompletePage({
    super.key,
    required this.bookingId,
    required this.donorName,
    required this.bloodGroup,
    required this.component,
    required this.slotDate,
    required this.slotTime,
    required this.coolingDays,
    required this.coolingNote,
    required this.facilityName,
  });

  @override
  State<DonationCompletePage> createState() => _DonationCompletePageState();
}

class _DonationCompletePageState extends State<DonationCompletePage> {
  // ── Palette ────────────────────────────────────────────────────────────────
  static const Color activeRed   = Color(0xFFC8102E);
  static const Color darkText    = Color(0xFF0F172A);
  static const Color subText     = Color(0xFF64748B);
  static const Color softRedBg   = Color(0xFFFFEAEA);
  static const Color softBlueBg  = Color(0xFFEFF6FF);
  static const Color softGreenBg = Color(0xFFDCFCE7);
  static const Color green       = Color(0xFF15803D);

  // ── State ──────────────────────────────────────────────────────────────────
  File? _donationPhoto;
  File? _doctorSlip;
  bool  _isSubmitting = false;

  final ImagePicker _picker = ImagePicker();

  // ── Image helpers ──────────────────────────────────────────────────────────
  Future<void> _pickDonationPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 60,
      maxWidth: 1024,
    );
    if (picked != null) setState(() => _donationPhoto = File(picked.path));
  }

  Future<void> _pickDonationPhotoGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
      maxWidth: 1024,
    );
    if (picked != null) setState(() => _donationPhoto = File(picked.path));
  }

  Future<void> _pickDoctorSlip() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1024,
    );
    if (picked != null) setState(() => _doctorSlip = File(picked.path));
  }

  Future<void> _pickDoctorSlipGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1024,
    );
    if (picked != null) setState(() => _doctorSlip = File(picked.path));
  }

  // Convert image file → base-64 data-URI to send to backend
  Future<String> _toBase64(File file) async {
    final bytes  = await file.readAsBytes();
    final b64    = base64Encode(bytes);
    final ext    = file.path.split('.').last.toLowerCase();
    final mime   = ext == 'png' ? 'image/png' : 'image/jpeg';
    return 'data:$mime;base64,$b64';
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_donationPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add your donation photo.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_doctorSlip == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add the doctor\'s slip / receipt.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final photoUrl = await _toBase64(_donationPhoto!);
      final slipUrl  = await _toBase64(_doctorSlip!);

      final booking = await ApiService().completeBooking(
        bookingId:        widget.bookingId,
        donationPhotoUrl: photoUrl,
        doctorSlipUrl:    slipUrl,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DonationProcessingPage(
            bookingId: widget.bookingId,
            donorName: widget.donorName,
            bloodGroup: widget.bloodGroup,
            component: widget.component,
            donatedAt: DateTime.tryParse(
                  booking['donatedAt'] as String? ?? '') ??
                DateTime.now(),
            coolingDays: widget.coolingDays,
            facilityName: widget.facilityName,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: CircleAvatar(
            backgroundColor: activeRed,
            child: const Icon(Icons.water_drop, color: Colors.white, size: 18),
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Header ───────────────────────────────────────────────
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: softBlueBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back,
                          size: 18, color: darkText),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Confirm Donation',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: darkText,
                          ),
                        ),
                        Text(
                          'Upload proof to complete your donation record',
                          style: TextStyle(fontSize: 11, color: subText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Congrats banner ───────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B0000), Color(0xFFC8102E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.favorite,
                          color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'You donated, ${widget.donorName.split(' ').first}!',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.component} • ${widget.facilityName}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Info note ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: softBlueBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline,
                        color: Color(0xFF2563EB), size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Upload a selfie taken at the donation centre and the doctor\'s slip/receipt. Both are required to activate your cooling period countdown.',
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF1E40AF),
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Donation Photo ────────────────────────────────────────
              _buildSectionLabel(
                Icons.photo_camera,
                'Donation Photo',
                'Selfie at the donation centre',
              ),
              const SizedBox(height: 10),
              _buildImagePicker(
                file: _donationPhoto,
                onCamera: _pickDonationPhoto,
                onGallery: _pickDonationPhotoGallery,
                hint: 'Take a selfie or choose from gallery',
              ),

              const SizedBox(height: 24),

              // ── Doctor Slip ───────────────────────────────────────────
              _buildSectionLabel(
                Icons.receipt_long,
                'Doctor\'s Slip / Receipt',
                'Hospital-issued donation certificate',
              ),
              const SizedBox(height: 10),
              _buildImagePicker(
                file: _doctorSlip,
                onCamera: _pickDoctorSlip,
                onGallery: _pickDoctorSlipGallery,
                hint: 'Scan or choose doctor\'s slip from gallery',
              ),

              const SizedBox(height: 28),

              // ── Cooling period preview ────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_top_rounded,
                        color: Color(0xFFEA580C), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cooling period will start after submission',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7C2D12),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${widget.component}: ${widget.coolingNote} — next eligible donation date will be calculated from today.',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF92400E),
                                height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Submit button ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        (_donationPhoto != null && _doctorSlip != null)
                            ? green
                            : Colors.grey.shade400,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline,
                          color: Colors.white, size: 20),
                  label: Text(
                    _isSubmitting
                        ? 'Submitting…'
                        : 'Submit & Start Cooling Period',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Both photo and slip are required before submitting.',
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey.shade500),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section label ──────────────────────────────────────────────────────────
  Widget _buildSectionLabel(
      IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: softRedBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: activeRed, size: 18),
        ),
        const SizedBox(width: 10),
        Column(
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
            Text(subtitle,
                style:
                    const TextStyle(fontSize: 11, color: subText)),
          ],
        ),
      ],
    );
  }

  // ── Image picker card ──────────────────────────────────────────────────────
  Widget _buildImagePicker({
    required File? file,
    required VoidCallback onCamera,
    required VoidCallback onGallery,
    required String hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: file != null
              ? green
              : const Color(0xFFE2E8F0),
          width: file != null ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          // Preview or placeholder
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(13),
              topRight: Radius.circular(13),
            ),
            child: file != null
                ? Image.file(
                    file,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: double.infinity,
                    height: 130,
                    color: const Color(0xFFF8FAFC),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 40,
                            color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          hint,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
          ),
          // Buttons row
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: onCamera,
                    icon: const Icon(Icons.camera_alt,
                        size: 15, color: darkText),
                    label: const Text(
                      'Camera',
                      style: TextStyle(
                          fontSize: 12,
                          color: darkText,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: onGallery,
                    icon: const Icon(Icons.photo_library,
                        size: 15, color: darkText),
                    label: const Text(
                      'Gallery',
                      style: TextStyle(
                          fontSize: 12,
                          color: darkText,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                if (file != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: softGreenBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.check_circle,
                        color: green, size: 20),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
