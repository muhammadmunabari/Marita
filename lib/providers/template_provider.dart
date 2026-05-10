import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marita/models/prompt_template.dart';
import 'package:marita/services/template_service.dart';
import 'package:marita/providers/auth_provider.dart';

final customTemplatesProvider = FutureProvider<List<PromptTemplate>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return TemplateService.getCustomTemplates(user.uid);
});

final allTemplatesProvider = Provider<List<PromptTemplate>>((ref) {
  final staticTemplates = TemplateService.getStaticTemplates();
  final customTemplates = ref.watch(customTemplatesProvider).value ?? [];
  return [...staticTemplates, ...customTemplates];
});
