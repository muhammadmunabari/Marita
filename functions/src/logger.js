// =============================================================================
// FIRESTORE LOGGER
// =============================================================================
//
// Writes structured log entries to the `logs` collection in Firestore.
//
// Schema (from firestore_schema.txt):
//   logs/{logId}
//     - type: "error" | "info"
//     - message: string
//     - context: object
//     - createdAt: timestamp
//
// =============================================================================

const { getFirestore, FieldValue } = require("firebase-admin/firestore");

/**
 * Writes a structured log entry to the Firestore `logs` collection.
 *
 * @param {"error" | "info"} type - Log severity.
 * @param {string} message - Human-readable log message.
 * @param {Object} [context={}] - Additional context data (reportId, stack, etc.).
 * @returns {Promise<void>}
 */
async function logEvent(type, message, context = {}) {
  try {
    const db = getFirestore();

    await db.collection("logs").add({
      type,
      message,
      context,
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (err) {
    // Logging should never crash the main function — fail silently to console
    console.error("Failed to write log to Firestore:", err.message);
  }
}

module.exports = { logEvent };
