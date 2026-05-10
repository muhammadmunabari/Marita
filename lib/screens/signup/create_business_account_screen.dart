import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/marita_primary_button.dart';
import '../../components/marita_text_input.dart';
import '../../components/marita_select_field.dart';
import '../../design_system/marita_design_system.dart';
import '../../design_system/marita_icons.dart';
import '../../providers/auth_provider.dart';

class CreateBusinessAccountScreen extends ConsumerStatefulWidget {
  const CreateBusinessAccountScreen({super.key});

  @override
  ConsumerState<CreateBusinessAccountScreen> createState() =>
      _CreateBusinessAccountScreenState();
}

class _CreateBusinessAccountScreenState
    extends ConsumerState<CreateBusinessAccountScreen> {
  final _companyNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _taxIdController = TextEditingController();

  String _selectedCurrency = 'Indonesian Rupiah (IDR)';
  String _selectedRole = 'CEO';
  bool _isLoading = false;

  @override
  void dispose() {
    _companyNameController.dispose();
    _addressController.dispose();
    _taxIdController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _companyNameController.text.trim().isNotEmpty &&
      _selectedCurrency.isNotEmpty &&
      _selectedRole.isNotEmpty;

  Future<void> _submit() async {
    if (!_isValid || _isLoading) return;
    setState(() => _isLoading = true);

    try {
      await ref.read(authServiceProvider).createBusinessAccount(
        companyName: _companyNameController.text,
        currency: _selectedCurrency,
        role: _selectedRole,
        address: _addressController.text.isNotEmpty ? _addressController.text : null,
        taxId: _taxIdController.text.isNotEmpty ? _taxIdController.text : null,
      );
      // The auth provider listener in the router will handle redirection to home
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void _showCurrencyPicker() {
    // For now, a simple mock selection. In a real app, this would be a full picker.
    final currencies = ['Indonesian Rupiah (IDR)', 'US Dollar (USD)', 'Singapore Dollar (SGD)'];
    _showPicker('Select Currency', currencies, (val) {
      setState(() => _selectedCurrency = val);
    });
  }

  void _showRolePicker() {
    final roles = ['CEO', 'CFO', 'Owner', 'Manager', 'Accountant'];
    _showPicker('Select Role', roles, (val) {
      setState(() => _selectedRole = val);
    });
  }

  void _showPicker(String title, List<String> options, Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.maritaColors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(MaritaRadius.large)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(MaritaSpacing.lg),
              child: Text(
                title,
                style: context.maritaTypography.titleSmall,
              ),
            ),
            const Divider(),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(options[index], style: context.maritaTypography.bodyLarge),
                    onTap: () {
                      onSelect(options[index]);
                      context.pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MaritaSpacing.xl,
                vertical: MaritaSpacing.md,
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
                        color: colors.contentPrimary,
                      ),
                    ),
                  ),
                  Image.asset(
                    'assets/logos/Logomark colored.png',
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: MaritaSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 48), // Match large gap in reference

                    // Title
                    Text(
                      'Business Account',
                      style: typography.displaySmall.copyWith(
                        color: colors.contentPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: MaritaSpacing.sm),

                    // Subtitle
                    Text(
                      'Create a new business account to access clear financial oversight.',
                      style: typography.bodyDefault.copyWith(
                        color: colors.contentSecondary,
                      ),
                    ),
                    
                    const SizedBox(height: 40),

                    // Company Name
                    MaritaTextInput(
                      controller: _companyNameController,
                      hint: 'Company name*',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: MaritaSpacing.lg),

                    // Currency
                    MaritaSelectField(
                      label: 'Currency*',
                      value: _selectedCurrency,
                      onTap: _showCurrencyPicker,
                      suffixWidget: Text(
                        _selectedCurrency.contains('IDR') ? 'Rp' : r'$',
                        style: typography.bodyDefault.copyWith(
                          color: colors.contentSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: MaritaSpacing.lg),

                    // Role
                    MaritaSelectField(
                      label: 'Role*',
                      value: _selectedRole,
                      onTap: _showRolePicker,
                    ),
                    const SizedBox(height: MaritaSpacing.lg),

                    // Address (Optional)
                    MaritaTextInput(
                      controller: _addressController,
                      hint: 'Address',
                      maxLines: 3,
                    ),
                    const SizedBox(height: MaritaSpacing.lg),

                    // Tax ID (Optional)
                    MaritaTextInput(
                      controller: _taxIdController,
                      hint: 'Tax Identification Number',
                      keyboardType: TextInputType.number,
                    ),
                    
                    const SizedBox(height: MaritaSpacing.xxl),
                  ],
                ),
              ),
            ),

            // Bottom Actions
            Padding(
              padding: const EdgeInsets.all(MaritaSpacing.xl),
              child: MaritaPrimaryButton(
                label: 'Continue',
                isLoading: _isLoading,
                onPressed: _isValid ? _submit : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
