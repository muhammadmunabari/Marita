import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

class PromptTemplate {
  final String id;
  final String title;
  final String description;
  final String prompt;
  final String iconName;
  final bool isCustom;
  final String category;
  final String requiredInput;

  const PromptTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.prompt,
    required this.iconName,
    this.isCustom = false,
    this.category = '',
    this.requiredInput = '',
  });

  IconData get icon {
    switch (iconName) {
      case 'document_text':
        return IconsaxPlusLinear.document_text;
      case 'shield_search':
        return IconsaxPlusLinear.shield_search;
      case 'chart_2':
        return IconsaxPlusLinear.chart_2;
      case 'briefcase':
        return IconsaxPlusLinear.briefcase;
      case 'document_favorite':
        return IconsaxPlusLinear.document_favorite;
      default:
        return IconsaxPlusLinear.document_text;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'prompt': prompt,
      'iconName': iconName,
      'isCustom': isCustom,
      'category': category,
      'requiredInput': requiredInput,
    };
  }

  factory PromptTemplate.fromMap(Map<String, dynamic> map) {
    return PromptTemplate(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      prompt: map['prompt'] ?? '',
      iconName: map['iconName'] ?? 'document_text',
      isCustom: map['isCustom'] ?? false,
      category: map['category'] ?? '',
      requiredInput: map['requiredInput'] ?? '',
    );
  }
}
