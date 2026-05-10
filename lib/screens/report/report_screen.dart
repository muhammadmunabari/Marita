import 'package:flutter/material.dart';
import '../../design_system/marita_design_system.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.maritaColors.backgroundPrimary,
      body: Center(
        child: Text(
          'Report Screen',
          style: context.maritaTypography.titleLarge,
        ),
      ),
    );
  }
}
