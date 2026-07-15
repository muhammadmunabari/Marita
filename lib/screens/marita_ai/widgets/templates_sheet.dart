import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:marita/design_system/marita_design_system.dart';
import 'package:marita/models/prompt_template.dart';
import 'package:marita/services/template_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marita/providers/auth_provider.dart';
import 'create_template_dialog.dart';
import 'package:marita/providers/template_provider.dart';

class TemplatesSheet extends ConsumerStatefulWidget {
  const TemplatesSheet({super.key});

  @override
  ConsumerState<TemplatesSheet> createState() => _TemplatesSheetState();
}

class _TemplatesSheetState extends ConsumerState<TemplatesSheet> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _createNewTemplate() async {
    final result = await showDialog<PromptTemplate>(
      context: context,
      builder: (context) => const CreateTemplateDialog(),
    );
    if (result != null) {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        try {
          await TemplateService.saveCustomTemplate(user.uid, result);
          ref.invalidate(customTemplatesProvider);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Template created successfully')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error creating template: $e')),
            );
          }
        }
      }
    }
  }

  void _editTemplate(PromptTemplate template) async {
    final result = await showDialog<PromptTemplate>(
      context: context,
      builder: (context) => CreateTemplateDialog(template: template),
    );
    if (result != null) {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        try {
          await TemplateService.updateCustomTemplate(user.uid, result);
          ref.invalidate(customTemplatesProvider);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Template updated successfully')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error updating template: $e')),
            );
          }
        }
      }
    }
  }

  void _deleteTemplate(PromptTemplate template) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: context.maritaColors.backgroundPrimary,
            title: Text('Delete Template', style: context.maritaTypography.h4),
            content: Text(
              'Are you sure you want to delete "${template.title}"?',
              style: context.maritaTypography.bodyDefault,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: context.maritaColors.contentSecondary,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.maritaColors.error,
                ),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        try {
          await TemplateService.deleteCustomTemplate(user.uid, template.id);
          ref.invalidate(customTemplatesProvider);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Template deleted successfully')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error deleting template: $e')),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    final staticTemplates =
        TemplateService.getStaticTemplates().where((t) {
          final query = _searchQuery.toLowerCase();
          return t.title.toLowerCase().contains(query) ||
              t.description.toLowerCase().contains(query);
        }).toList();

    final categoriesOrder = [
      'Document Summary',
      'Fraud Detection',
      'Investment Analysis',
      'Business Analysis',
      'Generate Reports',
    ];

    final categoryIcons = {
      'Document Summary': IconsaxPlusLinear.document_text,
      'Fraud Detection': IconsaxPlusLinear.shield_search,
      'Investment Analysis': IconsaxPlusLinear.chart_2,
      'Business Analysis': IconsaxPlusLinear.briefcase,
      'Generate Reports': IconsaxPlusLinear.document_favorite,
    };

    final templatesByCategory = <String, List<PromptTemplate>>{};
    for (final category in categoriesOrder) {
      final templates =
          staticTemplates.where((t) => t.category == category).toList();
      if (templates.isNotEmpty) {
        templatesByCategory[category] = templates;
      }
    }

    final customTemplatesAsync = ref.watch(customTemplatesProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.fromLTRB(
        MaritaSpacing.xl,
        MaritaSpacing.xl,
        MaritaSpacing.xl,
        0,
      ),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.borderPrimary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: MaritaSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prompt Templates',
                    style: typography.titleMedium.copyWith(
                      color: colors.contentPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Analyze your data faster with pre-built prompts.',
                    style: typography.bodySmall.copyWith(
                      color: colors.contentSecondary,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _createNewTemplate,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.interactivePrimary,
                    borderRadius: MaritaRadius.borderSmall,
                  ),
                  child: Icon(
                    IconsaxPlusLinear.add,
                    color: colors.backgroundPrimary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MaritaSpacing.xl),
          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: MaritaSpacing.md),
            decoration: BoxDecoration(
              color: colors.backgroundSecondary,
              borderRadius: MaritaRadius.borderMedium,
              border: Border.all(color: colors.borderPrimary),
            ),
            child: Row(
              children: [
                Icon(
                  IconsaxPlusLinear.search_normal_1,
                  size: 18,
                  color: colors.contentTertiary,
                ),
                const SizedBox(width: MaritaSpacing.md),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: typography.bodyDefault,
                    decoration: InputDecoration(
                      hintText: 'Search templates...',
                      hintStyle: typography.bodyDefault.copyWith(
                        color: colors.contentTertiary,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: colors.contentTertiary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: MaritaSpacing.xl),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: MaritaSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (staticTemplates.isNotEmpty) ...[
                    for (final category in categoriesOrder)
                      if (templatesByCategory.containsKey(category)) ...[
                        _buildCategoryHeader(
                          context,
                          category,
                          categoryIcons[category] ?? IconsaxPlusLinear.document,
                        ),
                        const SizedBox(height: MaritaSpacing.md),
                        _buildList(context, templatesByCategory[category]!),
                        const SizedBox(height: MaritaSpacing.xl),
                      ],
                  ],
                  customTemplatesAsync.when(
                    data: (customTemplates) {
                      final filteredCustom =
                          customTemplates.where((t) {
                            final query = _searchQuery.toLowerCase();
                            return t.title.toLowerCase().contains(query) ||
                                t.description.toLowerCase().contains(query);
                          }).toList();

                      if (filteredCustom.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(context, 'Your Templates'),
                          const SizedBox(height: MaritaSpacing.md),
                          _buildList(context, filteredCustom),
                        ],
                      );
                    },
                    loading:
                        () => const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: MaritaSpacing.md,
                            ),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    error:
                        (err, stack) => Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: MaritaSpacing.md,
                          ),
                          child: Text(
                            'Error loading templates: $err',
                            style: typography.bodySmall.copyWith(
                              color: colors.error,
                            ),
                          ),
                        ),
                  ),
                  if (staticTemplates.isEmpty &&
                      (customTemplatesAsync.value ?? []).where((t) {
                        final query = _searchQuery.toLowerCase();
                        return t.title.toLowerCase().contains(query) ||
                            t.description.toLowerCase().contains(query);
                      }).isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(MaritaSpacing.xxl),
                        child: Column(
                          children: [
                            Icon(
                              IconsaxPlusLinear.search_status,
                              size: 48,
                              color: colors.contentTertiary,
                            ),
                            const SizedBox(height: MaritaSpacing.md),
                            Text(
                              'No templates found for "$_searchQuery"',
                              textAlign: TextAlign.center,
                              style: typography.bodyDefault.copyWith(
                                color: colors.contentSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: context.maritaTypography.bodySmallBold.copyWith(
        color: context.maritaColors.contentTertiary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildCategoryHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return Row(
      children: [
        Icon(icon, size: 16, color: colors.contentTertiary),
        const SizedBox(width: MaritaSpacing.xs),
        Text(
          title.toUpperCase(),
          style: typography.bodySmallBold.copyWith(
            color: colors.contentTertiary,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context, List<PromptTemplate> templates) {
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: templates.length,
      separatorBuilder:
          (context, index) => const SizedBox(height: MaritaSpacing.md),
      itemBuilder: (context, index) {
        final template = templates[index];
        return TemplateCard(
          template: template,
          onTap: () {
            Navigator.pop(context, template.prompt);
          },
          onEdit: template.isCustom ? () => _editTemplate(template) : null,
          onDelete: template.isCustom ? () => _deleteTemplate(template) : null,
        );
      },
    );
  }
}

class TemplateCard extends StatelessWidget {
  final PromptTemplate template;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const TemplateCard({
    super.key,
    required this.template,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return InkWell(
      onTap: onTap,
      borderRadius: MaritaRadius.borderMedium,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(MaritaSpacing.md),
        decoration: BoxDecoration(
          color: colors.backgroundSecondary,
          borderRadius: MaritaRadius.borderMedium,
          border: Border.all(color: colors.borderPrimary),
          boxShadow: [
            BoxShadow(
              color: colors.contentPrimary.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.title,
                    style: typography.bodyDefaultBold.copyWith(
                      color: colors.contentPrimary,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    template.description,
                    style: typography.bodySmall.copyWith(
                      color: colors.contentSecondary,
                      height: 1.2,
                    ),
                  ),
                  if (template.requiredInput.isNotEmpty) ...[
                    const SizedBox(height: MaritaSpacing.md),
                    Text(
                      'Required Input',
                      style: typography.bodySmallBold.copyWith(
                        color: colors.contentTertiary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      template.requiredInput,
                      style: typography.bodySmall.copyWith(
                        color: colors.contentSecondary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (template.isCustom) ...[
              const SizedBox(width: MaritaSpacing.sm),
              Column(
                children: [
                  TemplateActionButton(
                    icon: IconsaxPlusLinear.edit_2,
                    onTap: onEdit ?? () {},
                  ),
                  const SizedBox(height: MaritaSpacing.xs),
                  TemplateActionButton(
                    icon: IconsaxPlusLinear.trash,
                    color: colors.error,
                    onTap: onDelete ?? () {},
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class TemplateActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const TemplateActionButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Prevent tapping the card itself
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: context.maritaColors.backgroundPrimary,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 14,
          color: color ?? context.maritaColors.contentSecondary,
        ),
      ),
    );
  }
}
