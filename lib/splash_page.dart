import 'package:flutter/material.dart';
import 'home.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFC8102E);

    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFD),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // Logo Container with soft glow
            Center(
              child: Container(
                width: 250,
                height: 230,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(color: primaryRed.withValues(alpha: 0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: primaryRed.withValues(alpha: 0.18),
                      blurRadius: 30,
                      spreadRadius: 5,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Blood Drop Icon Illustration
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(
                          Icons.water_drop,
                          size: 90,
                          color: primaryRed,
                        ),
                        Positioned(
                          top: 32,
                          child: Row(
                            children: const [
                              Icon(Icons.person, size: 18, color: Colors.white),
                              SizedBox(width: 2),
                              Icon(Icons.favorite, size: 12, color: Colors.white),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Title & Subtitle
                    const Text(
                      'One Blood Connect',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const FittedBox(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 20, child: Divider(thickness: 1, color: Colors.black38)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6.0),
                            child: Text(
                              'By Pondicherry University',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          SizedBox(width: 20, child: Divider(thickness: 1, color: Colors.black38)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Red Loading Bar Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: const LinearProgressIndicator(
                  value: 0.85,
                  minHeight: 4,
                  backgroundColor: Color(0xFFFFD6D6),
                  valueColor: AlwaysStoppedAnimation<Color>(primaryRed),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Status Text
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.circle, size: 8, color: primaryRed),
                SizedBox(width: 6),
                Text(
                  'Initializing application...',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 36),

            // Proceed to Sign In Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36.0),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: Colors.black12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  onPressed: () {
                    // Navigate to your SignInPage
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignInPage(),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'Proceed to Sign In',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.black54,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Spacer(),

            // Footer Section
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.favorite, color: primaryRed, size: 12),
                SizedBox(width: 4),
                Text(
                  'Every Drop Counts • Saving Lives Together',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Powered by Pondicherry University • Secured & Encrypted',
              style: TextStyle(
                fontSize: 10,
                color: Colors.black38,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}