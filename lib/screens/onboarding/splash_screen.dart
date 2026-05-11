import 'package:flutter/material.dart';
import '../../design_system/marita_design_system.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.maritaColors.backgroundPrimary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logos/Logobug colored bg.png',
              width: 80,
              height: 80,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: context.maritaColors.interactivePrimary,
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
