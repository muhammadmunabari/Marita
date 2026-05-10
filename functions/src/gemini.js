// =============================================================================
// GEMINI AI CLIENT
// =============================================================================
//
// Handles communication with the Google Gemini API.
//
// Security (from backend_developer.md):
//   - API key is NEVER hardcoded
//   - Passed at runtime from Firebase Secrets (defineSecret)
//
// Self-Correction:
//   - Retry logic handled by the caller (analyzeReport.js)
//   - This module throws on failure so the caller can retry
//
// Response parsing:
//   - Expects JSON with: { summary, keyFindings, riskAnalysis, recommendation }
//   - Falls back to raw text extraction if JSON parse fails
//
// =============================================================================

const { GoogleGenerativeAI } = require("@google/generative-ai");

/**
 * Calls the Gemini API and parses the structured response.
 *
 * @param {string} apiKey - The Gemini API key (from Firebase Secrets).
 * @param {string} prompt - The fully built prompt string.
 * @returns {Promise<Object>} Parsed AI insight object.
 * @throws {Error} If the API call fails or response cannot be parsed.
 */
async function callGemini(apiKey, prompt) {
  if (!apiKey) {
    throw new Error("GEMINI_API_KEY is not configured. Set it via: firebase functions:secrets:set GEMINI_API_KEY");
  }

  // ---------------------------------------------------------------------------
  // Initialize client
  // ---------------------------------------------------------------------------

  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({
    model: "gemini-2.0-flash",
    generationConfig: {
      temperature: 0.3,       // Low creativity — we want precision
      topP: 0.8,
      topK: 40,
      maxOutputTokens: 1024,
      responseMimeType: "application/json",
    },
  });

  // ---------------------------------------------------------------------------
  // Call API
  // ---------------------------------------------------------------------------

  const result = await model.generateContent(prompt);
  const response = result.response;
  const text = response.text();

  if (!text || text.trim().length === 0) {
    throw new Error("Gemini returned empty response.");
  }

  // ---------------------------------------------------------------------------
  // Parse response
  // ---------------------------------------------------------------------------

  const insight = parseGeminiResponse(text);
  return insight;
}

/**
 * Parses the Gemini response text into a structured insight object.
 *
 * Tries JSON parsing first, then falls back to section-based extraction.
 *
 * @param {string} text - Raw response text from Gemini.
 * @returns {Object} { summary, keyFindings, riskAnalysis, recommendation }
 * @throws {Error} If parsing fails completely.
 */
function parseGeminiResponse(text) {
  // ---------------------------------------------------------------------------
  // Attempt 1: Direct JSON parse
  // ---------------------------------------------------------------------------

  try {
    // Strip markdown code fences if present
    const cleaned = text
      .replace(/```json\s*/gi, "")
      .replace(/```\s*/g, "")
      .trim();

    const parsed = JSON.parse(cleaned);

    // Validate required fields
    if (parsed.summary && parsed.keyFindings && parsed.riskAnalysis && parsed.recommendation) {
      return {
        summary: String(parsed.summary).trim(),
        keyFindings: String(parsed.keyFindings).trim(),
        riskAnalysis: String(parsed.riskAnalysis).trim(),
        recommendation: String(parsed.recommendation).trim(),
      };
    }
  } catch {
    // JSON parse failed — try fallback
  }

  // ---------------------------------------------------------------------------
  // Attempt 2: Section-based text extraction
  // ---------------------------------------------------------------------------

  try {
    const sections = extractSections(text);
    if (sections) return sections;
  } catch {
    // Fallback also failed
  }

  // ---------------------------------------------------------------------------
  // Attempt 3: Use raw text as summary
  // ---------------------------------------------------------------------------

  return {
    summary: text.substring(0, 500).trim(),
    keyFindings: "Unable to parse structured findings from AI response.",
    riskAnalysis: "Manual review required.",
    recommendation: "Please re-run the analysis or review the raw output above.",
  };
}

/**
 * Extracts numbered sections from a text response.
 * Handles formats like "1. Summary\n..." or "## Summary\n..."
 *
 * @param {string} text
 * @returns {Object|null} Extracted sections or null if extraction fails.
 */
function extractSections(text) {
  const patterns = {
    summary: /(?:1\.\s*Summary|##\s*Summary)[:\s]*\n?([\s\S]*?)(?=(?:2\.|##\s*Key|$))/i,
    keyFindings: /(?:2\.\s*Key\s*Findings|##\s*Key\s*Findings)[:\s]*\n?([\s\S]*?)(?=(?:3\.|##\s*Risk|$))/i,
    riskAnalysis: /(?:3\.\s*Risk\s*Analysis|##\s*Risk\s*Analysis)[:\s]*\n?([\s\S]*?)(?=(?:4\.|##\s*Rec|$))/i,
    recommendation: /(?:4\.\s*Recommendation|##\s*Recommendation)[:\s]*\n?([\s\S]*?)$/i,
  };

  const result = {};
  let matchCount = 0;

  for (const [key, regex] of Object.entries(patterns)) {
    const match = text.match(regex);
    if (match && match[1]) {
      result[key] = match[1].trim();
      matchCount++;
    }
  }

  // Only return if we found at least 3 of 4 sections
  if (matchCount >= 3) {
    return {
      summary: result.summary || "No summary provided.",
      keyFindings: result.keyFindings || "No findings extracted.",
      riskAnalysis: result.riskAnalysis || "No risk analysis provided.",
      recommendation: result.recommendation || "No recommendation provided.",
    };
  }

  return null;
}

module.exports = { callGemini };
