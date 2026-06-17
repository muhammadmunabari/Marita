import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../components/marita_primary_button.dart';
import '../../design_system/marita_design_system.dart';
import '../../design_system/marita_icons.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.maritaColors.backgroundPrimary,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MaritaSpacing.xl,
                  ), // 24px margin
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 3),
                      // Logo
                      Center(
                        child: Image.asset(
                          'assets/logos/Logobug colored bg.png',
                          width: 64,
                          height: 64,
                        ),
                      ),
                      const SizedBox(height: MaritaSpacing.lg),
                      // Title
                      Text(
                        'WELCOME\nTO MARITA',
                        textAlign: TextAlign.center,
                        style: context.maritaTypography.displaySmall.copyWith(
                          color: context.maritaColors.contentPrimary,
                        ),
                      ),
                      const Spacer(flex: 4),
                      // Feature 1
                      _FeatureItem(
                        iconWidget: SvgPicture.asset(
                          'assets/icons/gemini.svg',
                          width: MaritaIconSize.medium,
                          height: MaritaIconSize.medium,
                          colorFilter: ColorFilter.mode(
                            context.maritaColors.contentPrimary,
                            BlendMode.srcIn,
                          ),
                        ),
                        title: 'AI Assistant',
                        description:
                            'Understand complex financial data & get clear answers and actionable insights in seconds.',
                      ),
                      const SizedBox(height: MaritaSpacing.xl),
                      // Feature 2
                      _FeatureItem(
                        iconWidget: MaritaIcon(
                          icon: MaritaIcons.search,
                          size: MaritaIconSize.medium,
                          color: context.maritaColors.contentPrimary,
                        ),
                        title: 'Audit System',
                        description:
                            'Strengthen financial accountability. Track issues, risks, and audit findings with clarity.',
                      ),
                      const SizedBox(height: MaritaSpacing.xl),
                      // Feature 3
                      _FeatureItem(
                        iconWidget: MaritaIcon(
                          icon: MaritaIcons.folder,
                          size: MaritaIconSize.medium,
                          color: context.maritaColors.contentPrimary,
                        ),
                        title: 'Automated Financial Report',
                        description:
                            'Generate reports instantly. Turn raw data into clear executive insights.',
                      ),
                      const Spacer(flex: 4),
                      // Button
                      MaritaPrimaryButton(
                        label: 'Get started now',
                        onPressed: () {
                          context.push('/signup');
                        },
                      ),
                      const SizedBox(height: MaritaSpacing.md),
                      // Login Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: context.maritaTypography.bodyDefault.copyWith(
                              color: context.maritaColors.contentSecondary,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              context.push('/login');
                            },
                            child: Text(
                              'Log in',
                              style: context.maritaTypography.bodyDefaultBold.copyWith(
                                color: context.maritaColors.interactivePrimary,
                                decoration: TextDecoration.underline,
                                decorationColor:
                                    context.maritaColors.interactivePrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: MaritaSpacing.lg),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final Widget iconWidget;
  final String title;
  final String description;

  const _FeatureItem({
    required this.iconWidget,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        iconWidget,
        const SizedBox(width: MaritaSpacing.lg), // 16px as requested
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.maritaTypography.titleSmall.copyWith(
                  color: context.maritaColors.contentPrimary,
                ),
              ),
              const SizedBox(height: MaritaSpacing.xs),
              Text(
                description,
                style: context.maritaTypography.bodyDefault.copyWith(
                  color: context.maritaColors.contentSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
