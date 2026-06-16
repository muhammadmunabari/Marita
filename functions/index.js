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
const { sendVerificationEmail, sendWorkspaceInvitationEmail, onWorkspaceInvitationUpdated } = require("./src/auth");
const { chunkFile } = require("./src/chunk");
const { analyzeDocumentIntelligence } = require("./src/document_intelligence");

exports.analyzeReport = analyzeReport;
exports.sendVerificationEmail = sendVerificationEmail;
exports.sendWorkspaceInvitationEmail = sendWorkspaceInvitationEmail;
exports.onWorkspaceInvitationUpdated = onWorkspaceInvitationUpdated;
exports.chunkFile = chunkFile;
exports.analyzeDocumentIntelligence = analyzeDocumentIntelligence;
