// =============================================================================
// MARITA CLOUD FUNCTIONS — ENTRY POINT
// =============================================================================
//
// Exports all Cloud Functions for the Marita backend.
//
// Functions:
//   - analyzeReport  : Triggered on Firestore report creation.
//                      Calculates Beneish M-Score, calls Gemini AI,
//                      writes structured insight back to the report.
//
// Security:
//   - API keys stored in Firebase environment config (functions.config())
//     or Cloud Secret Manager. NEVER hardcoded.
//   - All Firestore access via Admin SDK (bypasses security rules).
//
// =============================================================================

const { analyzeReport } = require("./src/analyzeReport");
const { sendVerificationEmail } = require("./src/auth");

exports.analyzeReport = analyzeReport;
exports.sendVerificationEmail = sendVerificationEmail;
