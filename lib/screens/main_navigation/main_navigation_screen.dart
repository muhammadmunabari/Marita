import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../design_system/marita_design_system.dart';

class MainNavigationScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainNavigationScreen({super.key, required this.navigationShell});

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar:
          isKeyboardVisible
              ? null
              : _MaritaBottomBar(
                currentIndex: navigationShell.currentIndex,
                onTap: _onTap,
              ),
    );
  }
}

class _MaritaBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _MaritaBottomBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: MaritaColors.black,
        border: Border(
          top: BorderSide(color: MaritaColors.shadow700, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: MaritaSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MaritaNavItem(
                iconPath: 'assets/icons/Marita AI.svg',
                label: 'Marita AI',
                isSelected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _MaritaNavItem(
                iconPath: 'assets/icons/iconsax-chart.svg',
                label: 'Report',
                isSelected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _MaritaNavItem(
                iconPath: 'assets/icons/iconsax-folder.svg',
                label: 'Files',
                isSelected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _MaritaNavItem(
                iconPath: 'assets/icons/iconsax-buildings.svg',
                label: 'Workspaces',
                isSelected: currentIndex == 3,
                onTap: () => onTap(3),
              ),
              _MaritaNavItem(
                iconPath: 'assets/icons/iconsax-setting.svg',
                label: 'Settings',
                isSelected: currentIndex == 4,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaritaNavItem extends StatefulWidget {
  final String iconPath;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _MaritaNavItem({
    required this.iconPath,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_MaritaNavItem> createState() => _MaritaNavItemState();
}

class _MaritaNavItemState extends State<_MaritaNavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;
    final color =
        widget.isSelected ? colors.interactivePrimary : colors.contentSecondary;

    return Expanded(
      child: GestureDetector(
        onTapDown: (_) {
          _controller.forward();
          HapticFeedback.selectionClick();
        },
        onTapUp: (_) {
          _controller.reverse();
          widget.onTap();
        },
        onTapCancel: () {
          _controller.reverse();
        },
        behavior: HitTestBehavior.opaque,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                widget.iconPath,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: (widget.isSelected
                        ? typography.bodyDefaultBold
                        : typography.bodyDefault)
                    .copyWith(color: color, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
