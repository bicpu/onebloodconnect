import 'package:flutter/material.dart';
import 'widgets/floating_nav.dart';

class CertificatePage extends StatelessWidget {
  final Map<String, dynamic> certificate;

  const CertificatePage({super.key, required this.certificate});

  String _date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return '--';
    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Donation Certificate'),
        backgroundColor: const Color(0xFF8B0000),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
              child: _certificateCard(),
            ),
          ),
          const Positioned(
            left: 20,
            right: 20,
            bottom: 16,
            child: FloatingNav(selectedIndex: 2),
          ),
        ],
      ),
    );
  }

  Widget _certificateCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFC8102E), width: 2),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 12),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.workspace_premium,
              color: Color(0xFFC8102E), size: 56),
          const SizedBox(height: 12),
          const Text(
            'CERTIFICATE OF APPRECIATION',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'One Blood Connect',
            style: TextStyle(
              color: Color(0xFF8B0000),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'This certifies that ${certificate['donorName'] ?? 'the donor'}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'donated ${certificate['component'] ?? 'blood'} '
            '(${certificate['bloodGroup'] ?? ''})',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'at ${certificate['facilityName'] ?? 'the blood bank'} '
            'on ${_date(certificate['donatedAt'])}.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF475569)),
          ),
          const SizedBox(height: 24),
          Text(
            'Certificate No. ${certificate['certificateNo'] ?? '--'}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            'Issued ${_date(certificate['issuedAt'])}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
