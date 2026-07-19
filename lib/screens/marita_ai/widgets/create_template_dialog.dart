import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:marita/design_system/marita_design_system.dart';
import 'package:marita/models/prompt_template.dart';

class CreateTemplateDialog extends StatefulWidget {
  final PromptTemplate? template;
  const CreateTemplateDialog({super.key, this.template});

  @override
  State<CreateTemplateDialog> createState() => _CreateTemplateDialogState();
}

class _CreateTemplateDialogState extends State<CreateTemplateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _promptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.template != null) {
      _titleController.text = widget.template!.title;
      _descController.text = widget.template!.description;
      _promptController.text = widget.template!.prompt;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return Dialog(
      backgroundColor: colors.backgroundPrimary,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: MaritaSpacing.xl),
      shape: RoundedRectangleBorder(
        borderRadius: MaritaRadius.borderLarge,
        side: BorderSide(color: colors.borderPrimary),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(MaritaSpacing.xl),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.template == null
                                ? 'New Template'
                                : 'Edit Template',
                            style: typography.h4,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Create a reusable prompt for your analysis.',
                            style: typography.bodySmall.copyWith(
                              color: colors.contentTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: colors.contentSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: MaritaSpacing.xl),

                TextFormField(
                  controller: _titleController,
                  style: typography.bodyDefault,
                  maxLength: 50,
                  validator:
                      (v) =>
                          (v == null || v.isEmpty) ? 'Title is required' : null,
                  decoration: InputDecoration(
                    labelText: 'Template Title',
                    hintText: 'e.g., Financial Report Analysis',
                    filled: true,
                    fillColor: colors.backgroundSecondary,
                    border: OutlineInputBorder(
                      borderRadius: MaritaRadius.borderSmall,
                      borderSide: BorderSide(color: colors.borderPrimary),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: MaritaRadius.borderSmall,
                      borderSide: BorderSide(color: colors.borderPrimary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: MaritaRadius.borderSmall,
                      borderSide: BorderSide(
                        color: colors.interactivePrimary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: MaritaSpacing.lg),
                TextFormField(
                  controller: _descController,
                  style: typography.bodyDefault,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'What does this template do?',
                    filled: true,
                    fillColor: colors.backgroundSecondary,
                    border: OutlineInputBorder(
                      borderRadius: MaritaRadius.borderSmall,
                      borderSide: BorderSide(color: colors.borderPrimary),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: MaritaRadius.borderSmall,
                      borderSide: BorderSide(color: colors.borderPrimary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: MaritaRadius.borderSmall,
                      borderSide: BorderSide(
                        color: colors.interactivePrimary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: MaritaSpacing.lg),
                TextFormField(
                  controller: _promptController,
                  maxLines: 6,
                  maxLength: 1000,
                  style: typography.bodyDefault,
                  validator:
                      (v) =>
                          (v == null || v.isEmpty)
                              ? 'Prompt is required'
                              : null,
                  decoration: InputDecoration(
                    labelText: 'Prompt',
                    hintText: 'Write your instructions here...',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: colors.backgroundSecondary,
                    border: OutlineInputBorder(
                      borderRadius: MaritaRadius.borderSmall,
                      borderSide: BorderSide(color: colors.borderPrimary),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: MaritaRadius.borderSmall,
                      borderSide: BorderSide(color: colors.borderPrimary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: MaritaRadius.borderSmall,
                      borderSide: BorderSide(
                        color: colors.interactivePrimary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: MaritaSpacing.xxl),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        final template = PromptTemplate(
                          id: widget.template?.id ?? const Uuid().v4(),
                          title: _titleController.text.trim(),
                          description: _descController.text.trim(),
                          prompt: _promptController.text.trim(),
                          iconName: widget.template?.iconName ?? 'document_text',
                          isCustom: true,
                        );
                        Navigator.pop(context, template);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.interactivePrimary,
                      foregroundColor: colors.backgroundPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: MaritaRadius.borderMedium,
                      ),
                    ),
                    child: Text(
                      widget.template == null
                          ? 'Create Template'
                          : 'Save Changes',
                      style: typography.bodyDefaultBold.copyWith(
                        color: colors.backgroundPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
