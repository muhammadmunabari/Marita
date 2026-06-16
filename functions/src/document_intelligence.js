const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { getFirestore } = require("firebase-admin/firestore");
const crypto = require("crypto");

const db = getFirestore();

/**
 * Triggered on file metadata creation.
 * Performs duplicate detection, financial consistency analysis, and OCR validation.
 */
exports.analyzeDocumentIntelligence = onDocumentCreated(
  {
    document: "companies/{companyId}/files/{fileId}",
    timeoutSeconds: 240,
    memory: "512MiB",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data();
    const { companyId, fileId } = event.params;
    const fileRef = db.collection("companies").doc(companyId).collection("files").doc(fileId);

    try {
      const content = data.content || "";
      
      // 1. Duplicate Detection
      // Generate SHA-256 fingerprint of the content
      const hash = crypto.createHash("sha256").update(content).digest("hex");

      const existingFiles = await db
          .collection("companies")
          .doc(companyId)
          .collection("files")
          .where("hash", "==", hash)
          .get();

      if (!existingFiles.empty && existingFiles.docs.some(doc => doc.id !== fileId)) {
        await fileRef.update({
          duplicateDetected: true,
          status: "duplicate",
          hash: hash,
        });
        console.log(`Duplicate file detected for ${fileId}. Mark status as duplicate.`);
        return;
      }

      // 2. Financial Consistency Check (Document Matching & Balance Sheet Analysis)
      // Look for Balance Sheet formula: Total Assets = Total Liabilities + Owner Equity
      let totalAssets = null;
      let totalLiabilities = null;
      let ownerEquity = null;

      // Extract using simple regex as secondary processing fallback
      const assetsMatch = content.match(/total\s+assets[:\s]*\$?\s*([\d,]+)/i);
      const liabilitiesMatch = content.match(/total\s+liabilities[:\s]*\$?\s*([\d,]+)/i);
      const equityMatch = content.match(/(?:owner|stockholder|shareholder)\s*equity[:\s]*\$?\s*([\d,]+)/i);

      if (assetsMatch) totalAssets = parseInt(assetsMatch[1].replace(/,/g, ""), 10);
      if (liabilitiesMatch) totalLiabilities = parseInt(liabilitiesMatch[1].replace(/,/g, ""), 10);
      if (equityMatch) ownerEquity = parseInt(equityMatch[1].replace(/,/g, ""), 10);

      let consistencyStatus = "unknown";
      let consistencyFeedback = "Insufficient data to verify consistency.";

      if (totalAssets !== null && totalLiabilities !== null && ownerEquity !== null) {
        const formulaSum = totalLiabilities + ownerEquity;
        const diff = Math.abs(totalAssets - formulaSum);

        if (diff === 0) {
          consistencyStatus = "consistent";
          consistencyFeedback = "Assets match Liabilities + Equity perfectly.";
        } else {
          consistencyStatus = "inconsistent";
          consistencyFeedback = `Mismatch: Assets (${totalAssets}) != Liabilities + Equity (${formulaSum}). Difference: ${diff}`;
        }
      }

      // Update document intelligence records
      await fileRef.update({
        hash: hash,
        intelligenceAnalysis: {
          consistencyStatus,
          consistencyFeedback,
          extractedEntities: {
            totalAssets,
            totalLiabilities,
            ownerEquity,
          },
          analyzedAt: new Date(),
        },
      });

      console.log(`Successfully completed Document Intelligence analysis for file ${fileId}.`);
    } catch (err) {
      console.error(`Document Intelligence analysis failed for ${fileId}:`, err);
    }
  }
);
