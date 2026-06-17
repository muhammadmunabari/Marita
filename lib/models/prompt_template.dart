import 'package:flutter/material.dart';

class PromptTemplate {
  final String id;
  final String title;
  final String description;
  final String prompt;
  final IconData icon;
  final bool isCustom;
  final String category;
  final String requiredInput;

  const PromptTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.prompt,
    required this.icon,
    this.isCustom = false,
    this.category = '',
    this.requiredInput = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'prompt': prompt,
      'iconCode': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
      'iconFontPackage': icon.fontPackage,
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
      icon: IconData(
        map['iconCode'] ?? 0,
        fontFamily: map['iconFontFamily'],
        fontPackage: map['iconFontPackage'],
      ),
      isCustom: map['isCustom'] ?? false,
      category: map['category'] ?? '',
      requiredInput: map['requiredInput'] ?? '',
    );
  }
}
