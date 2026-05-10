// =============================================================================
// CLOUD FUNCTION: analyzeReport
// =============================================================================
//
// Triggered when a new document is created in `reports/{reportId}`.
//
// Flow (from backend_developer.md):
//   1. User submits financial data → saved to Firestore as "pending"
//   2. This function triggers automatically (onCreate)
//   3. Status → "processing"
//   4. Calculate Beneish M-Score
//   5. Call Gemini API with structured prompt
//   6. Parse AI response into { summary, keyFindings, riskAnalysis, recommendation }
//   7. Save result + status → "completed"
//
// Self-Correction:
//   - If Gemini fails → retry up to 3 times
//   - If all retries fail → status → "failed", log error
//
// Security:
//   - Gemini API key stored via `firebase functions:secrets:set GEMINI_API_KEY`
//   - NEVER exposed in source code
//
// =============================================================================

const { onDocumentCreated } = require("firebase-functions/v2/firestore");

const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { initializeApp } = require("firebase-admin/app");

const { calculateBeneishScore } = require("./beneish");
const { callGemini } = require("./gemini");
const { buildPrompt } = require("./prompt");
const { logEvent } = require("./logger");

// ---------------------------------------------------------------------------
// Firebase init
// ---------------------------------------------------------------------------

initializeApp();
const db = getFirestore();



// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const MAX_RETRIES = 3;
const RETRY_DELAY_MS = 2000;

// ---------------------------------------------------------------------------
// Cloud Function
// ---------------------------------------------------------------------------

/**
 * Triggered when a new report document is created.
 *
 * Expects the document to have:
 *   - input: { revenue, netIncome, totalAssets, totalLiabilities, cashFlow }
 *   - status: "pending"
 *   - companyId: string
 *   - createdBy: string (userId)
 */
exports.analyzeReport = onDocumentCreated(
  {
    document: "reports/{reportId}",
    timeoutSeconds: 120,
    memory: "512MiB",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.error("No data in event.");
      return;
    }

    const reportId = event.params.reportId;
    const reportRef = db.collection("reports").doc(reportId);
    const data = snap.data();

    // -----------------------------------------------------------------------
    // Validate input
    // -----------------------------------------------------------------------

    const input = data.input;
    if (!input) {
      await reportRef.update({
        status: "failed",
        completedAt: FieldValue.serverTimestamp(),
      });
      await logEvent("error", `Report ${reportId}: missing input data`, {
        reportId,
      });
      return;
    }

    const { revenue, netIncome, totalAssets, totalLiabilities, cashFlow } =
      input;

    if (
      [revenue, netIncome, totalAssets, totalLiabilities, cashFlow].some(
        (v) => v === undefined || v === null || typeof v !== "number"
      )
    ) {
      await reportRef.update({
        status: "failed",
        completedAt: FieldValue.serverTimestamp(),
      });
      await logEvent(
        "error",
        `Report ${reportId}: invalid input fields — all must be numbers`,
        { reportId, input }
      );
      return;
    }

    // -----------------------------------------------------------------------
    // Step 1: Mark as processing
    // -----------------------------------------------------------------------

    await reportRef.update({ status: "processing" });

    try {
      // ---------------------------------------------------------------------
      // Step 2: Calculate Beneish M-Score
      // ---------------------------------------------------------------------

      const beneishScore = calculateBeneishScore(input);
      const fraudRisk = classifyFraudRisk(beneishScore);

      // ---------------------------------------------------------------------
      // Step 3: Build Gemini prompt
      // ---------------------------------------------------------------------

      const prompt = buildPrompt({
        revenue,
        netIncome,
        totalAssets,
        totalLiabilities,
        cashFlow,
        beneishScore,
      });

      // ---------------------------------------------------------------------
      // Step 4: Call Gemini API with retry
      // ---------------------------------------------------------------------

      let aiInsight = null;
      let lastError = null;

      for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
        try {
          aiInsight = await callGemini(process.env.GEMINI_API_KEY, prompt);
          break; // success — exit retry loop
        } catch (err) {
          lastError = err;
          console.warn(
            `Gemini attempt ${attempt}/${MAX_RETRIES} failed:`,
            err.message
          );

          if (attempt < MAX_RETRIES) {
            await sleep(RETRY_DELAY_MS * attempt); // exponential backoff
          }
        }
      }

      // All retries failed
      if (!aiInsight) {
        throw new Error(
          `Gemini API failed after ${MAX_RETRIES} retries: ${lastError?.message}`
        );
      }

      // ---------------------------------------------------------------------
      // Step 5: Batch write results
      // ---------------------------------------------------------------------

      const batch = db.batch();

      batch.update(reportRef, {
        status: "completed",
        beneishScore,
        fraudRisk,
        aiInsight,
        completedAt: FieldValue.serverTimestamp(),
      });

      await batch.commit();

      await logEvent("info", `Report ${reportId}: analysis completed`, {
        reportId,
        beneishScore,
        fraudRisk,
      });

      console.log(`✅ Report ${reportId} completed successfully.`);
    } catch (error) {
      // -------------------------------------------------------------------
      // Error — mark as failed
      // -------------------------------------------------------------------

      console.error(`❌ Report ${reportId} failed:`, error);

      await reportRef.update({
        status: "failed",
        completedAt: FieldValue.serverTimestamp(),
      });

      await logEvent("error", `Report ${reportId}: ${error.message}`, {
        reportId,
        stack: error.stack,
      });
    }
  }
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Classifies fraud risk based on Beneish M-Score.
 *
 * - M-Score > -1.78 → high risk (likely manipulator)
 * - M-Score between -1.78 and -2.22 → medium risk (grey zone)
 * - M-Score < -2.22 → low risk (unlikely manipulator)
 *
 * @param {number} score - The Beneish M-Score.
 * @returns {"low" | "medium" | "high"}
 */
function classifyFraudRisk(score) {
  if (score > -1.78) return "high";
  if (score > -2.22) return "medium";
  return "low";
}

/**
 * Simple promise-based sleep for retry backoff.
 * @param {number} ms - Milliseconds to wait.
 */
function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
