import 'package:flutter/material.dart';

class PromptTemplate {
  final String id;
  final String title;
  final String description;
  final String prompt;
  final int iconCodePoint;
  final String? iconFontFamily;
  final String? iconFontPackage;
  final bool isCustom;
  final String category;
  final String requiredInput;

  const PromptTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.prompt,
    required this.iconCodePoint,
    this.iconFontFamily,
    this.iconFontPackage,
    this.isCustom = false,
    this.category = '',
    this.requiredInput = '',
  });

  IconData get icon => IconData(
    iconCodePoint,
    fontFamily: iconFontFamily,
    fontPackage: iconFontPackage,
  );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'prompt': prompt,
      'iconCode': iconCodePoint,
      'iconFontFamily': iconFontFamily,
      'iconFontPackage': iconFontPackage,
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
      iconCodePoint: map['iconCode'] ?? 0,
      iconFontFamily: map['iconFontFamily'],
      iconFontPackage: map['iconFontPackage'],
      isCustom: map['isCustom'] ?? false,
      category: map['category'] ?? '',
      requiredInput: map['requiredInput'] ?? '',
    );
  }
}
