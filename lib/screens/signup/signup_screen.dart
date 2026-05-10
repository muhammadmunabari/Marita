import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/marita_primary_button.dart';
import '../../components/marita_text_input.dart';
import '../../design_system/marita_design_system.dart';
import '../../design_system/marita_icons.dart';
import '../../providers/auth_provider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  // Track if fields have been touched/submitted to show errors
  bool _hasSubmitted = false;
  bool _isLoading = false;

  // Dropdown state
  final LayerLink _phoneLayerLink = LayerLink();
  final GlobalKey _phoneInputKey = GlobalKey();
  bool _isDropdownOpen = false;
  OverlayEntry? _dropdownOverlay;
  String _selectedCountryCode = '+62';
  final List<Map<String, String>> _countries = [
    {'code': '+1', 'name': 'United States'},
    {'code': '+62', 'name': 'Indonesia'},
  ];

  void _toggleDropdown() {
    if (_isDropdownOpen) {
      _closeDropdown();
    } else {
      _showDropdown();
    }
  }

  void _closeDropdown() {
    _dropdownOverlay?.remove();
    _dropdownOverlay = null;
    if (mounted) {
      setState(() {
        _isDropdownOpen = false;
      });
    }
  }

  void _showDropdown() {
    final RenderBox? renderBox =
        _phoneInputKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;

    _dropdownOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeDropdown,
                child: Container(),
              ),
            ),
            CompositedTransformFollower(
              link: _phoneLayerLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 4),
              child: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: size.width,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        _countries.map((country) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedCountryCode = country['code']!;
                                });
                                _closeDropdown();
                              },
                              child: Container(
                                height: 56,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: MaritaSpacing.lg,
                                ),
                                decoration: BoxDecoration(
                                  color: context.maritaColors.backgroundPrimary,
                                  borderRadius: MaritaRadius.borderMedium,
                                  border: Border.all(
                                    color: context.maritaColors.borderPrimary,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 40,
                                      child: Text(
                                        country['code']!,
                                        style: context
                                            .maritaTypography
                                            .bodyLarge
                                            .copyWith(
                                              color:
                                                  context
                                                      .maritaColors
                                                      .contentPrimary,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: MaritaSpacing.sm),
                                    Text(
                                      country['name']!,
                                      style: context.maritaTypography.bodyLarge
                                          .copyWith(
                                            color:
                                                context
                                                    .maritaColors
                                                    .contentPrimary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_dropdownOverlay!);
    setState(() {
      _isDropdownOpen = true;
    });
  }

  @override
  void dispose() {
    _closeDropdown();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _validateAndSubmit() async {
    setState(() {
      _hasSubmitted = true;
    });

    if (!_isFormValid) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      // Construct phone number
      String phone = _phoneController.text.trim();
      if (phone.startsWith('0')) {
        phone = phone.substring(1);
      }
      final phoneWithPrefix = '$_selectedCountryCode$phone';

      await authService.signUpWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
        phoneNumber: phoneWithPrefix,
      );

      // We rely on GoRouter's redirect to automatically navigate us
      // to the next screen once auth state changes, so we don't manually go()
      // or reset _isLoading on success to avoid lifecycle assertion errors.
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: context.maritaColors.error,
          ),
        );
      }
    }
  }

  bool get _isEmailValid {
    final text = _emailController.text.trim();
    if (text.isEmpty) return false;
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(text);
  }

  bool get _hasMinLength => _passwordController.text.length >= 8;
  bool get _hasUppercase => _passwordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase => _passwordController.text.contains(RegExp(r'[a-z]'));
  bool get _hasNumber => _passwordController.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecialChar =>
      _passwordController.text.contains(RegExp(r'[!@#\$&*~^\-_=+%|?/.,;:]'));

  bool get _isPasswordValid {
    return _hasMinLength &&
        _hasUppercase &&
        _hasLowercase &&
        _hasNumber &&
        _hasSpecialChar;
  }

  bool get _isFormValid {
    return _nameController.text.trim().isNotEmpty &&
        _isEmailValid &&
        _phoneController.text.trim().isNotEmpty &&
        _isPasswordValid;
  }

  String? get _emailErrorText {
    if (!_hasSubmitted && _emailController.text.isEmpty) return null;
    if (_emailController.text.isNotEmpty && !_isEmailValid) {
      return '*Please enter a valid email address.';
    }
    return null;
  }

  String? get _passwordErrorText {
    if (!_hasSubmitted && _passwordController.text.isEmpty) return null;
    if (_passwordController.text.isNotEmpty && !_isPasswordValid) {
      List<String> errors = [];
      if (!_hasMinLength) errors.add('At least 8 characters');
      if (!_hasUppercase) errors.add('At least 1 uppercase letter');
      if (!_hasLowercase) errors.add('At least 1 lowercase letter');
      if (!_hasNumber) errors.add('At least 1 number');
      if (!_hasSpecialChar) errors.add('At least 1 special character');
      return 'Password must contain:\n• ${errors.join('\n• ')}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // We rebuild when text changes to update validation logic
    return Scaffold(
      backgroundColor: context.maritaColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Header: Back button + Logo
            Padding(
              padding: const EdgeInsets.only(
                left: MaritaSpacing.xl,
                right: MaritaSpacing.xl,
                top: MaritaSpacing.md,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => context.pop(),
                      child: MaritaIcon(
                        icon: MaritaIcons.arrowLeft,
                        size: MaritaIconSize.medium,
                        color: context.maritaColors.contentPrimary,
                      ),
                    ),
                  ),
                  Image.asset(
                    'assets/logos/Logobug black bg.png',
                    width: 48,
                    height: 48,
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: MaritaSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24), // 24px spacing
                    // Title
                    Text(
                      'Setting up your account',
                      style: context.maritaTypography.titleMedium.copyWith(
                        color: context.maritaColors.contentPrimary,
                      ),
                    ),
                    const SizedBox(height: 8), // 8px spacing
                    // Subtitle
                    Text(
                      'Create a new account to access clear financial oversight.',
                      style: context.maritaTypography.bodyDefault.copyWith(
                        color: context.maritaColors.contentSecondary,
                      ),
                    ),
                    const SizedBox(height: 32), // 32px spacing
                    // Form Fields
                    MaritaTextInput(
                      hint: 'Full name*',
                      controller: _nameController,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16), // 16px gap

                    MaritaTextInput(
                      hint: 'Email*',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      errorText: _emailErrorText,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),

                    CompositedTransformTarget(
                      link: _phoneLayerLink,
                      child: Container(
                        key: _phoneInputKey,
                        child: MaritaTextInput(
                          hint: '812 3456 7890',
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          onChanged: (val) {
                            if (val.startsWith('0')) {
                              final cleanedText = val.replaceFirst(
                                RegExp(r'^0+'),
                                '',
                              );
                              _phoneController.value = TextEditingValue(
                                text: cleanedText,
                                selection: TextSelection.collapsed(
                                  offset: cleanedText.length,
                                ),
                              );
                            }
                            setState(() {});
                          },
                          prefixWidget: _buildCountryPrefix(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    MaritaTextInput(
                      hint: 'Password*',
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      errorText: _passwordErrorText,
                      onChanged: (_) => setState(() {}),
                      suffixIcon:
                          _obscurePassword
                              ? MaritaIcons.eyeSlash
                              : MaritaIcons.eye,
                      onSuffixIconTap: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Bottom Action
            Padding(
              padding: const EdgeInsets.only(
                left: MaritaSpacing.xl,
                right: MaritaSpacing.xl,
                bottom: 24, // 24px
              ),
              child: MaritaPrimaryButton(
                label: _isLoading ? 'Creating account...' : 'Continue',
                onPressed:
                    (_isLoading || !_isFormValid) ? null : _validateAndSubmit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryPrefix(BuildContext context) {
    return GestureDetector(
      onTap: _toggleDropdown,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedCountryCode,
              style: context.maritaTypography.bodyLarge.copyWith(
                color: context.maritaColors.contentPrimary,
              ),
            ),
            const SizedBox(width: 8),
            MaritaIcon(
              icon:
                  _isDropdownOpen ? MaritaIcons.arrowUp : MaritaIcons.arrowDown,
              size: MaritaIconSize.medium,
              color: context.maritaColors.contentPrimary,
            ),
          ],
        ),
      ),
    );
  }
}
