class DocumentChunk {
  final String id;
  final String fileId;       // Firestore file document ID
  final String fileName;     // human-readable file name
  final String content;
  final List<double> embedding;
  final int pageNumber;
  final int chunkIndex;      // sequential index within the file
  final Map<String, dynamic> metadata;

  DocumentChunk({
    required this.id,
    required this.fileId,
    this.fileName = '',
    required this.content,
    required this.embedding,
    required this.pageNumber,
    this.chunkIndex = 0,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileId': fileId,
      'fileName': fileName,
      'content': content,
      'embedding': embedding,
      'pageNumber': pageNumber,
      'chunkIndex': chunkIndex,
      'metadata': metadata,
    };
  }

  factory DocumentChunk.fromMap(Map<String, dynamic> map) {
    return DocumentChunk(
      id: map['id'] ?? '',
      // Support legacy 'documentId' field alongside new 'fileId'
      fileId: map['fileId'] ?? map['documentId'] ?? '',
      fileName: map['fileName'] ?? '',
      content: map['content'] ?? '',
      embedding: List<double>.from(
        (map['embedding'] as List? ?? []).map((e) => (e as num).toDouble()),
      ),
      pageNumber: map['pageNumber'] ?? 0,
      chunkIndex: map['chunkIndex'] ?? 0,
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  /// Returns a copy with an updated embedding vector.
  DocumentChunk withEmbedding(List<double> newEmbedding) {
    return DocumentChunk(
      id: id,
      fileId: fileId,
      fileName: fileName,
      content: content,
      embedding: newEmbedding,
      pageNumber: pageNumber,
      chunkIndex: chunkIndex,
      metadata: metadata,
    );
  }
}
