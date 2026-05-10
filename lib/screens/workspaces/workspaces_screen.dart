import 'package:flutter/material.dart';
import '../../design_system/marita_design_system.dart';

class WorkspacesScreen extends StatelessWidget {
  const WorkspacesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.maritaColors.backgroundPrimary,
      body: Center(
        child: Text(
          'Workspaces Screen',
          style: context.maritaTypography.titleLarge,
        ),
      ),
    );
  }
}
