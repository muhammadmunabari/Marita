import re
import os

with open('lib/screens/marita_ai/marita_ai_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

def extract_block(regex_pattern):
    match = re.search(regex_pattern, code, re.DOTALL)
    if not match: return ''
    start = match.start()
    open_braces = 0
    in_string = False
    escape = False
    string_char = ''
    for i in range(match.end() - 1, len(code)):
        if in_string:
            if escape:
                escape = False
            elif code[i] == '\\':
                escape = True
            elif code[i] == string_char:
                in_string = False
        else:
            if code[i] == '"' or code[i] == "'":
                in_string = True
                string_char = code[i]
            elif code[i] == '{': open_braces += 1
            elif code[i] == '}': 
                open_braces -= 1
                if open_braces == 0:
                    return code[start:i+1]
    return ''

# Blocks to extract
chat_message_bubble_code = extract_block(r'class _MessageBubble extends')
ai_action_icon_code = extract_block(r'class _AIActionIcon extends')
attachment_preview_bubble_code = extract_block(r'class _AttachmentPreviewBubble extends')

chat_input_area_code = extract_block(r'class _MaritaAIInputArea extends')
chat_input_area_state_code = extract_block(r'class _MaritaAIInputAreaState extends')
marita_icon_button_code = extract_block(r'class _MaritaIconButton extends')
marita_icon_button_state_code = extract_block(r'class _MaritaIconButtonState extends')
get_attachment_icon_code = extract_block(r'IconData _getAttachmentIcon\(')

sidebar_drawer_code = extract_block(r'class _MaritaSidebarDrawer extends')

templates_sheet_code = extract_block(r'class _TemplatesSheet extends')
templates_sheet_state_code = extract_block(r'class _TemplatesSheetState extends')
template_card_code = extract_block(r'class _TemplateCard extends')
template_action_button_code = extract_block(r'class _TemplateActionButton extends')

create_template_dialog_code = extract_block(r'class _CreateTemplateDialog extends')
create_template_dialog_state_code = extract_block(r'class _CreateTemplateDialogState extends')

# Function to rename classes
def rename(text, old, new):
    if not text: return text
    return re.sub(r'\b' + old + r'\b', new, text)

chat_message_bubble_code = rename(chat_message_bubble_code, '_MessageBubble', 'ChatMessageBubble')
chat_message_bubble_code = rename(chat_message_bubble_code, '_AIActionIcon', 'AIActionIcon')
chat_message_bubble_code = rename(chat_message_bubble_code, '_AttachmentPreviewBubble', 'AttachmentPreviewBubble')

ai_action_icon_code = rename(ai_action_icon_code, '_AIActionIcon', 'AIActionIcon')

attachment_preview_bubble_code = rename(attachment_preview_bubble_code, '_AttachmentPreviewBubble', 'AttachmentPreviewBubble')
attachment_preview_bubble_code = rename(attachment_preview_bubble_code, '_getAttachmentIcon', 'getAttachmentIcon')

chat_input_area_code = rename(chat_input_area_code, '_MaritaAIInputArea', 'ChatInputArea')
chat_input_area_state_code = rename(chat_input_area_state_code, '_MaritaAIInputArea', 'ChatInputArea')
chat_input_area_state_code = rename(chat_input_area_state_code, '_MaritaAIInputAreaState', '_ChatInputAreaState')
chat_input_area_state_code = rename(chat_input_area_state_code, '_MaritaIconButton', 'MaritaIconButton')

marita_icon_button_code = rename(marita_icon_button_code, '_MaritaIconButton', 'MaritaIconButton')
marita_icon_button_state_code = rename(marita_icon_button_state_code, '_MaritaIconButton', 'MaritaIconButton')
marita_icon_button_state_code = rename(marita_icon_button_state_code, '_MaritaIconButtonState', '_MaritaIconButtonState')

get_attachment_icon_code = rename(get_attachment_icon_code, '_getAttachmentIcon', 'getAttachmentIcon')

sidebar_drawer_code = rename(sidebar_drawer_code, '_MaritaSidebarDrawer', 'SidebarDrawer')

templates_sheet_code = rename(templates_sheet_code, '_TemplatesSheet', 'TemplatesSheet')
templates_sheet_state_code = rename(templates_sheet_state_code, '_TemplatesSheet', 'TemplatesSheet')
templates_sheet_state_code = rename(templates_sheet_state_code, '_TemplatesSheetState', '_TemplatesSheetState')
templates_sheet_state_code = rename(templates_sheet_state_code, '_TemplateCard', 'TemplateCard')
templates_sheet_state_code = rename(templates_sheet_state_code, '_CreateTemplateDialog', 'CreateTemplateDialog')

template_card_code = rename(template_card_code, '_TemplateCard', 'TemplateCard')
template_card_code = rename(template_card_code, '_TemplateActionButton', 'TemplateActionButton')
template_action_button_code = rename(template_action_button_code, '_TemplateActionButton', 'TemplateActionButton')

create_template_dialog_code = rename(create_template_dialog_code, '_CreateTemplateDialog', 'CreateTemplateDialog')
create_template_dialog_state_code = rename(create_template_dialog_state_code, '_CreateTemplateDialog', 'CreateTemplateDialog')
create_template_dialog_state_code = rename(create_template_dialog_state_code, '_CreateTemplateDialogState', '_CreateTemplateDialogState')


# File content generation
def generate_file(imports, parts):
    return imports + "\n\n" + "\n\n".join(parts) + "\n"

# 1. chat_message_bubble.dart
imports = """import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:marita/models/chat_message.dart';
import 'package:marita/theme/marita_theme.dart';
import 'chat_input_area.dart'; // for getAttachmentIcon
import 'package:flutter/services.dart';"""
with open('lib/screens/marita_ai/widgets/chat_message_bubble.dart', 'w', encoding='utf-8') as f:
    f.write(generate_file(imports, [chat_message_bubble_code, ai_action_icon_code, attachment_preview_bubble_code]))

# 2. chat_input_area.dart
imports = """import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:marita/theme/marita_theme.dart';
import 'package:marita/models/chat_message.dart';"""
with open('lib/screens/marita_ai/widgets/chat_input_area.dart', 'w', encoding='utf-8') as f:
    f.write(generate_file(imports, [chat_input_area_code, chat_input_area_state_code, get_attachment_icon_code, marita_icon_button_code, marita_icon_button_state_code]))

# 3. sidebar_drawer.dart
imports = """import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:marita/theme/marita_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marita/providers/auth_provider.dart';"""
with open('lib/screens/marita_ai/widgets/sidebar_drawer.dart', 'w', encoding='utf-8') as f:
    f.write(generate_file(imports, [sidebar_drawer_code]))

# 4. templates_sheet.dart
imports = """import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:marita/theme/marita_theme.dart';
import 'package:marita/models/prompt_template.dart';
import 'package:marita/services/template_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marita/providers/auth_provider.dart';
import 'create_template_dialog.dart';"""
with open('lib/screens/marita_ai/widgets/templates_sheet.dart', 'w', encoding='utf-8') as f:
    f.write(generate_file(imports, [templates_sheet_code, templates_sheet_state_code, template_card_code, template_action_button_code]))

# 5. create_template_dialog.dart
imports = """import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:marita/theme/marita_theme.dart';
import 'package:marita/models/prompt_template.dart';"""
with open('lib/screens/marita_ai/widgets/create_template_dialog.dart', 'w', encoding='utf-8') as f:
    f.write(generate_file(imports, [create_template_dialog_code, create_template_dialog_state_code]))


# Replace in marita_ai_screen.dart
new_code = code

# Remove the blocks
blocks_to_remove = [
    r'class _MessageBubble extends.*?^}',
    r'class _AIActionIcon extends.*?^}',
    r'class _AttachmentPreviewBubble extends.*?^}',
    r'class _MaritaAIInputArea extends.*?^}',
    r'class _MaritaAIInputAreaState extends.*?^}',
    r'class _MaritaIconButton extends.*?^}',
    r'class _MaritaIconButtonState extends.*?^}',
    r'IconData _getAttachmentIcon\([^}]*\}',
    r'class _MaritaSidebarDrawer extends.*?^}',
    r'class _TemplatesSheet extends.*?^}',
    r'class _TemplatesSheetState extends.*?^}',
    r'class _TemplateCard extends.*?^}',
    r'class _TemplateActionButton extends.*?^}',
    r'class _CreateTemplateDialog extends.*?^}',
    r'class _CreateTemplateDialogState extends.*?^}'
]

for block in [chat_message_bubble_code, ai_action_icon_code, attachment_preview_bubble_code, 
              chat_input_area_code, chat_input_area_state_code, get_attachment_icon_code,
              marita_icon_button_code, marita_icon_button_state_code, sidebar_drawer_code,
              templates_sheet_code, templates_sheet_state_code, template_card_code, template_action_button_code,
              create_template_dialog_code, create_template_dialog_state_code]:
    # We will just replace the exact text we extracted to ensure correctness
    pass

import sys

# Because we used `extract_block`, we can just string-replace the original strings.
original_blocks = [
    extract_block(r'class _MessageBubble extends'),
    extract_block(r'class _AIActionIcon extends'),
    extract_block(r'class _AttachmentPreviewBubble extends'),
    extract_block(r'class _MaritaAIInputArea extends'),
    extract_block(r'class _MaritaAIInputAreaState extends'),
    extract_block(r'class _MaritaIconButton extends'),
    extract_block(r'class _MaritaIconButtonState extends'),
    extract_block(r'IconData _getAttachmentIcon\('),
    extract_block(r'class _MaritaSidebarDrawer extends'),
    extract_block(r'class _TemplatesSheet extends'),
    extract_block(r'class _TemplatesSheetState extends'),
    extract_block(r'class _TemplateCard extends'),
    extract_block(r'class _TemplateActionButton extends'),
    extract_block(r'class _CreateTemplateDialog extends'),
    extract_block(r'class _CreateTemplateDialogState extends')
]

for block in original_blocks:
    if block:
        new_code = new_code.replace(block, "")

# Now rename the instantiations in the main file
new_code = rename(new_code, '_MessageBubble', 'ChatMessageBubble')
new_code = rename(new_code, '_MaritaAIInputArea', 'ChatInputArea')
new_code = rename(new_code, '_MaritaSidebarDrawer', 'SidebarDrawer')
new_code = rename(new_code, '_TemplatesSheet', 'TemplatesSheet')

# Add imports for the new files
import_statements = """import 'widgets/chat_message_bubble.dart';
import 'widgets/chat_input_area.dart';
import 'widgets/sidebar_drawer.dart';
import 'widgets/templates_sheet.dart';
"""

# Find the last import
last_import_match = list(re.finditer(r'^import .*?;', new_code, re.MULTILINE))[-1]
new_code = new_code[:last_import_match.end()] + '\n' + import_statements + new_code[last_import_match.end():]

with open('lib/screens/marita_ai/marita_ai_screen.dart', 'w', encoding='utf-8') as f:
    f.write(new_code)

print("Split completed successfully")
