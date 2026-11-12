import 'package:flutter/material.dart';

class PendingProofPage extends StatelessWidget {
  final String facilityName;

  const PendingProofPage({super.key, required this.facilityName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proof Under Review'),
        backgroundColor: const Color(0xFF8B0000),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.hourglass_top, color: Color(0xFFD97706), size: 58),
                  const SizedBox(height: 16),
                  const Text('Donation proof submitted',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(
                    '$facilityName will verify your photo and doctor slip. '
                    'Your certificate and cooling period will appear after approval.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  const Chip(
                    avatar: Icon(Icons.pending_outlined, size: 18),
                    label: Text('Pending verification'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                    child: const Text('Back to dashboard'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
