import 'package:flutter/material.dart';
import '../../design_system/marita_design_system.dart';

class FilesScreen extends StatelessWidget {
  const FilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.maritaColors.backgroundPrimary,
      body: Center(
        child: Text(
          'Files Screen',
          style: context.maritaTypography.titleLarge,
        ),
      ),
    );
  }
}
