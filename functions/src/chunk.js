const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { getFirestore } = require("firebase-admin/firestore");
const { GoogleGenerativeAI } = require("@google/generative-ai");

const db = getFirestore();

/**
 * Triggered when a new file metadata record is created in Firestore.
 * Performs chunking, generates embeddings, and saves chunks.
 */
exports.chunkFile = onDocumentCreated(
  {
    document: "companies/{companyId}/files/{fileId}",
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data();
    const { content, name, pageCount } = data;

    if (!content || typeof content !== "string") {
      console.warn("Document does not contain extractable text content. Skipping chunking.");
      return;
    }

    const { companyId, fileId } = event.params;
    const fileRef = db.collection("companies").doc(companyId).collection("files").doc(fileId);

    try {
      // 1. Chunking Logic (Hybrid Strategy)
      const paragraphs = content.split(/\n\n+/);
      const chunks = [];
      let currentChunkText = "";
      let pageNumber = 1;

      for (const p of paragraphs) {
        if (currentChunkText.length + p.length > 800) {
          chunks.add({
            content: currentChunkText.trim(),
            pageNumber,
            metadata: { fileName: name, length: currentChunkText.length },
          });
          currentChunkText = p + "\n";
        } else {
          currentChunkText += p + "\n";
        }
      }

      if (currentChunkText.trim().length > 0) {
        chunks.add({
          content: currentChunkText.trim(),
          pageNumber,
          metadata: { fileName: name, length: currentChunkText.length },
        });
      }

      // Initialize Gemini Client for Embeddings
      const apiKey = process.env.GEMINI_API_KEY;
      if (!apiKey) {
        throw new Error("GEMINI_API_KEY environment variable is missing.");
      }
      const genAI = new GoogleGenerativeAI(apiKey);
      const embedModel = genAI.getGenerativeModel({ model: "text-embedding-004" });

      const batch = db.batch();

      // 2. Generate Embeddings & Batch Write Chunks
      for (let i = 0; i < chunks.length; i++) {
        const chunk = chunks[i];
        try {
          const result = await embedModel.embedContent(chunk.content);
          const embedding = result.embedding.values;

          const chunkRef = fileRef.collection("chunks").doc(`chunk_${i}`);
          batch.set(chunkRef, {
            content: chunk.content,
            pageNumber: chunk.pageNumber,
            embedding: embedding,
            metadata: chunk.metadata,
            createdAt: new Date(),
          });
        } catch (embedError) {
          console.error(`Embedding generation failed for chunk ${i}:`, embedError);
        }
      }

      await batch.commit();
      await fileRef.update({ chunkingStatus: "completed" });
      console.log(`Successfully generated and indexed ${chunks.length} chunks for file ${fileId}.`);
    } catch (err) {
      console.error(`Chunking failed for file ${fileId}:`, err);
      await fileRef.update({ chunkingStatus: "failed", error: err.message });
    }
  }
);

// Helper for arrays
Array.prototype.add = function (item) {
  this.push(item);
};
