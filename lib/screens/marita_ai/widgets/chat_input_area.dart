import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:marita/design_system/marita_design_system.dart';
import 'package:marita/design_system/marita_icons.dart';
import 'package:marita/models/chat_message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marita/services/attachment_service.dart';
import 'package:marita/providers/auth_provider.dart';
import 'package:marita/providers/template_provider.dart';
import 'package:marita/providers/workspace_provider.dart';
import 'package:marita/services/template_service.dart';
import 'package:marita/models/prompt_template.dart';
import 'package:marita/screens/marita_ai/widgets/templates_sheet.dart';
import 'package:marita/screens/marita_ai/widgets/create_template_dialog.dart';
import 'package:marita/providers/chat_provider.dart';
import 'package:marita/screens/marita_ai/widgets/editing_banner.dart';


class ChatInputArea extends ConsumerStatefulWidget {
  final Function(String, List<ChatAttachment>) onSend;
  const ChatInputArea({super.key, required this.onSend});

  @override
  ConsumerState<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends ConsumerState<ChatInputArea> {
  late final TextEditingController _controller;
  bool _isMultiLine = false;
  final GlobalKey _plusButtonKey = GlobalKey();
  List<ChatAttachment> _attachments = [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_updateState);
  }

  void _updateState() {
    final text = _controller.text;
    final isMultiLine =
        text.contains('\n') || text.length > 35 || _attachments.isNotEmpty;
    if (isMultiLine != _isMultiLine) {
      setState(() {
        _isMultiLine = isMultiLine;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleUpload() async {
    final files = await AttachmentService.pickFiles();
    if (files.isNotEmpty) {
      setState(() {
        _attachments = [..._attachments, ...files];
        _updateState();
      });
    }
  }

  void _handleTakePhoto() async {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(MaritaSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Image Source',
                  style: typography.titleMedium.copyWith(
                    color: colors.contentPrimary,
                  ),
                ),
                const SizedBox(height: MaritaSpacing.xl),
                ListTile(
                  leading: const MaritaIcon(icon: MaritaIcons.camera),
                  title: Text('Take Photo', style: typography.bodyLarge),
                  subtitle: Text(
                    'Use camera to snap a picture',
                    style: typography.bodyDefault.copyWith(
                      color: colors.contentSecondary,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final photo = await AttachmentService.takePhoto();
                    if (photo != null) {
                      setState(() {
                        _attachments = [..._attachments, photo];
                        _updateState();
                      });
                    }
                  },
                ),
                ListTile(
                  leading: const MaritaIcon(icon: MaritaIcons.gallery),
                  title: Text(
                    'Choose from Gallery',
                    style: typography.bodyLarge,
                  ),
                  subtitle: Text(
                    'Upload an image from your library',
                    style: typography.bodyDefault.copyWith(
                      color: colors.contentSecondary,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final image = await AttachmentService.pickImage();
                    if (image != null) {
                      setState(() {
                        _attachments = [..._attachments, image];
                        _updateState();
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTemplatesSheet() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const TemplatesSheet(),
    );
    if (result != null) {
      if (result == 'trigger_custom') {
        _showCustomTemplateDialog();
      } else {
        setState(() {
          _controller.text = result;
          _updateState();
        });
      }
    }
  }

  void _showPlusMenu() async {
    final RenderBox renderBox =
        _plusButtonKey.currentContext!.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy - 220, // Increased height for more items
        MediaQuery.of(context).size.width - offset.dx - size.width,
        MediaQuery.of(context).size.height - offset.dy,
      ),
      color: colors.backgroundSecondary,
      shape: RoundedRectangleBorder(borderRadius: MaritaRadius.borderMedium),
      items: [
        PopupMenuItem(
          value: 'camera',
          child: Row(
            children: [
              MaritaIcon(icon: MaritaIcons.camera, size: MaritaIconSize.small),
              const SizedBox(width: MaritaSpacing.md),
              Text('Upload Image', style: typography.bodyDefault),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'upload',
          child: Row(
            children: [
              MaritaIcon(icon: MaritaIcons.upload, size: MaritaIconSize.small),
              const SizedBox(width: MaritaSpacing.md),
              Text('Upload Files', style: typography.bodyDefault),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'templates',
          child: Row(
            children: [
              MaritaIcon(
                icon: IconsaxPlusLinear.document_text,
                size: MaritaIconSize.small,
              ),
              const SizedBox(width: MaritaSpacing.md),
              Text('Prompt Templates', style: typography.bodyDefault),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'camera') {
        _handleTakePhoto();
      } else if (value == 'upload') {
        _handleUpload();
      } else if (value == 'templates') {
        _showTemplatesSheet();
      }
    });
  }

  void _showCustomTemplateDialog() async {
    final result = await showDialog<PromptTemplate>(
      context: context,
      builder: (context) => const CreateTemplateDialog(),
    );
    if (result != null) {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        // Save to Firestore
        await TemplateService.saveCustomTemplate(user.uid, result);
        // Refresh templates
        ref.invalidate(customTemplatesProvider);
      }
      _controller.text = result.prompt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;
    final canWrite = ref.watch(canWriteRobustProvider);
    final editingState = ref.watch(chatProvider.select((s) => s.editingState));
    
    // We can't put this in initState because ref.listenManual needs context ? No, ref.listen handles it in build
    ref.listen(chatProvider.select((s) => s.editingState), (previous, current) {
      if (current != null && previous?.targetGroupId != current.targetGroupId) {
        _controller.text = current.originalText;
        _attachments = [];
        _updateState();
      } else if (current == null && previous != null) {
        _controller.clear();
        _attachments = [];
        _updateState();
      }
    });

    if (!canWrite) {
      return Container(
        padding: const EdgeInsets.all(MaritaSpacing.lg),
        decoration: BoxDecoration(
          color: colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.borderPrimary),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MaritaIcon(
              icon: IconsaxPlusLinear.eye,
              color: colors.contentTertiary,
              size: MaritaIconSize.small,
            ),
            const SizedBox(width: MaritaSpacing.sm),
            Flexible(
              child: Text(
                'View Only — you cannot send messages',
                style: typography.bodyDefault.copyWith(
                  color: colors.contentTertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.fastOutSlowIn,
      padding: EdgeInsets.symmetric(
        horizontal: MaritaSpacing.md,
        vertical: _isMultiLine ? MaritaSpacing.md : MaritaSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(_isMultiLine ? 16 : 32),
        border: Border.all(color: colors.borderPrimary, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (editingState != null)
            Padding(
              padding: const EdgeInsets.only(bottom: MaritaSpacing.md),
              child: EditingBanner(
                originalTimestamp: editingState.originalTimestamp,
                promptVersion: editingState.promptVersion,
                onCancel: () {
                  ref.read(chatProvider.notifier).cancelEditing();
                },
              ),
            ),
          if (_attachments.isNotEmpty)
            Container(
              height: 56, // Adjusted height for pill-shape
              margin: const EdgeInsets.only(bottom: MaritaSpacing.md),
              child: Stack(
                children: [
                  ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(right: 48),
                    itemCount: _attachments.length,
                    itemBuilder: (context, index) {
                      final attachment = _attachments[index];
                      final isImage = attachment.type == 'image';
                      final extension =
                          attachment.name.split('.').last.toUpperCase();

                      String fileSizeStr = '';
                      try {
                        final file = File(attachment.path);
                        if (file.existsSync()) {
                          final bytes = file.lengthSync();
                          if (bytes < 1024) {
                            fileSizeStr = '${bytes}B';
                          } else if (bytes < 1024 * 1024) {
                            fileSizeStr =
                                '${(bytes / 1024).toStringAsFixed(2)}KB';
                          } else {
                            fileSizeStr =
                                '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
                          }
                        }
                      } catch (_) {}

                      return Container(
                        margin: const EdgeInsets.only(right: MaritaSpacing.sm),
                        padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                        decoration: BoxDecoration(
                          color: colors.backgroundSecondary, // Dark capsule
                          borderRadius: BorderRadius.circular(
                            100,
                          ), // Pill shape
                          border: Border.all(color: colors.borderPrimary),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Icon Container
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color:
                                    extension == 'CSV' ||
                                            extension == 'XLS' ||
                                            extension == 'XLSX'
                                        ? const Color(0xFF107C41)
                                        : colors.interactivePrimary,
                                shape: BoxShape.circle,
                              ),
                              child:
                                  isImage
                                      ? ClipOval(
                                        child: Image.file(
                                          File(attachment.path),
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                      : Center(
                                        child: MaritaIcon(
                                          icon: getAttachmentIcon(
                                            attachment.type,
                                          ),
                                          size: MaritaIconSize.small,
                                          color: Colors.white,
                                        ),
                                      ),
                            ),
                            const SizedBox(width: MaritaSpacing.sm),
                            // Text Info
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 100, // Constrain text width
                                  child: Text(
                                    attachment.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: typography.bodyDefaultBold.copyWith(
                                      color:
                                          colors
                                              .interactivePrimary, // Blue text
                                    ),
                                  ),
                                ),
                                Text(
                                  fileSizeStr.isNotEmpty
                                      ? '$extension $fileSizeStr'
                                      : extension,
                                  style: typography.bodySmall.copyWith(
                                    color: colors.contentSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: MaritaSpacing.md),
                            // Close Button
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _attachments.removeAt(index);
                                  _updateState();
                                });
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: colors.backgroundPrimary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colors.borderPrimary,
                                  ),
                                ),
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: colors.contentPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (_attachments.length > 2)
                    Positioned(
                      right: -4,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              colors.backgroundSecondary.withValues(alpha: 0),
                              colors.backgroundSecondary.withValues(alpha: 0.9),
                              colors.backgroundSecondary,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Container(
                            margin: const EdgeInsets.only(left: 12),
                            decoration: BoxDecoration(
                              color: colors.error.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.delete_sweep_rounded,
                                color: colors.error,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _attachments = [];
                                  _updateState();
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              MaritaIconButton(
                key: _plusButtonKey,
                iconPath: 'assets/icons/iconsax-add.svg',
                iconData: MaritaIcons.add,
                onTap: _showPlusMenu,
              ),
              const SizedBox(width: MaritaSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.center,
                  style: typography.bodyLarge.copyWith(
                    color: colors.contentPrimary,
                    height: 1.0, // Match font size exactly (16px)
                  ),
                  cursorColor: colors.interactivePrimary,
                  decoration: InputDecoration(
                    isCollapsed: true, // Remove all default internal padding
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 8,
                    ), // (32px container - 16px text) / 2 = 8px
                    hintText: 'Ask Marita...',
                    hintStyle: typography.bodyLarge.copyWith(
                      color: colors.contentTertiary,
                      height: 1.0,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
              const SizedBox(width: MaritaSpacing.sm),
              MaritaIconButton(
                iconPath: 'assets/icons/iconsax-send.svg',
                iconData: editingState != null ? IconsaxPlusLinear.send_1 : IconsaxPlusLinear.send_1,
                onTap: () {
                  if (_controller.text.trim().isEmpty && _attachments.isEmpty) {
                    return;
                  }
                  
                  if (editingState != null) {
                    ref.read(chatProvider.notifier).sendEditedMessage(_controller.text);
                  } else {
                    widget.onSend(_controller.text, _attachments);
                  }
                  
                  _controller.clear();
                  setState(() {
                    _attachments = [];
                    _updateState();
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

IconData getAttachmentIcon(String type) {
  switch (type) {
    case 'pdf':
      return IconsaxPlusLinear.document_text;
    case 'image':
      return IconsaxPlusLinear.gallery;
    case 'csv':
    case 'xls':
    case 'xlsx':
    case 'text':
    case 'json':
    case 'sql':
    case 'md':
    case 'xml':
      return IconsaxPlusLinear.document;
    case 'doc':
    case 'docx':
      return IconsaxPlusLinear.document_text;
    default:
      return IconsaxPlusLinear.document_cloud;
  }
}

class MaritaIconButton extends StatefulWidget {
  final String iconPath;
  final IconData iconData;
  final VoidCallback onTap;

  const MaritaIconButton({
    super.key,
    required this.iconPath,
    required this.iconData,
    required this.onTap,
  });

  @override
  State<MaritaIconButton> createState() => _MaritaIconButtonState();
}

class _MaritaIconButtonState extends State<MaritaIconButton>
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
      end: 0.85,
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

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(MaritaSpacing.xs),
          color: Colors.transparent, // Increase hit area
          child: MaritaIcon(
            icon: widget.iconData,
            size: MaritaIconSize.medium,
            color: colors.contentPrimary,
          ),
        ),
      ),
    );
  }
}
