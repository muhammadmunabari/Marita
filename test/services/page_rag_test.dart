import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marita/models/chunk_model.dart';
import 'package:marita/services/document_chunker_service.dart';
import 'package:marita/services/rag_service.dart';

class FakeFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Page-Aware Chunking Tests', () {
    final fakeDb = FakeFirestore();
    final chunker = DocumentChunkerService(db: fakeDb);

    test('chunkTextWithPage preserves page number and adds page to metadata', () {
      const text = 'Halaman pertama dari dokumen contoh ini memiliki beberapa teks.';
      final chunks = chunker.chunkTextWithPage(
        text,
        'dokumen.pdf',
        'file_123',
        pageNumber: 3,
      );

      expect(chunks, isNotEmpty);
      expect(chunks.first.pageNumber, equals(3));
      expect(chunks.first.metadata['page'], equals(3));
      expect(chunks.first.fileName, equals('dokumen.pdf'));
      expect(chunks.first.fileId, equals('file_123'));
    });

    test('chunkText fallback defaults to page number 1', () {
      const text = 'Fallback text chunking test.';
      final chunks = chunker.chunkText(
        text,
        'dokumen.txt',
        'file_456',
      );

      expect(chunks, isNotEmpty);
      expect(chunks.first.pageNumber, equals(1));
      expect(chunks.first.metadata['page'], equals(1)); // fallback adds default page 1 to metadata
      expect(chunks.first.fileName, equals('dokumen.txt'));
    });
  });

  group('RAG Service Context Building Tests', () {
    final fakeDb = FakeFirestore();
    final rag = RAGService(firestore: fakeDb);

    test('buildContextString formats with Indonesian Halaman label', () {
      final chunks = [
        DocumentChunk(
          id: 'chunk_1',
          fileId: 'file_1',
          fileName: 'laporan_keuangan.pdf',
          content: 'Laba bersih meningkat sebesar 15%.',
          pageNumber: 5,
          chunkIndex: 0,
          embedding: [],
          metadata: {},
        ),
      ];

      final context = rag.buildContextString(chunks);
      expect(context, contains('Source [1] — laporan_keuangan.pdf, Halaman 5:'));
      expect(context, contains('Laba bersih meningkat sebesar 15%.'));
    });

    test('buildContextString handles empty chunk list gracefully', () {
      final context = rag.buildContextString([]);
      expect(context, equals('No additional source document context found.'));
    });
  });
}
