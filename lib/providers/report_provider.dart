// =============================================================================
// REPORT PROVIDERS — Riverpod
// =============================================================================
//
// Provides report data and actions to the widget tree.
//
// Providers:
//   - firestoreServiceProvider   → singleton FirestoreService instance
//   - companyReportsProvider     → real-time reports stream for a company
//   - reportDetailProvider       → real-time single report stream
//
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'workspace_provider.dart';

/// Real-time stream of reports for a specific company.
///
/// Uses the composite index: companyId + createdAt DESC.
///
/// Usage:
/// ```dart
/// final reports = ref.watch(companyReportsProvider(companyId));
/// ```
final companyReportsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, companyId) {
      final firestoreService = ref.watch(firestoreServiceProvider);
      return firestoreService.watchCompanyReports(companyId);
    });

/// Real-time stream of a single report by ID.
///
/// Useful for live status tracking (pending → processing → completed).
///
/// Usage:
/// ```dart
/// final report = ref.watch(reportDetailProvider(reportId));
/// ```
final reportDetailProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, reportId) {
      final firestoreService = ref.watch(firestoreServiceProvider);
      return firestoreService.watchReport(reportId);
    });
