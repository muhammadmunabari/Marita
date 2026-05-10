// =============================================================================
// GEMINI PROMPT BUILDER
// =============================================================================
//
// Builds the structured prompt for Gemini AI based on gemini_prompt.txt.
//
// Template variables:
//   {{revenue}}, {{netIncome}}, {{totalAssets}},
//   {{totalLiabilities}}, {{cashFlow}}, {{beneishScore}}
//
// The prompt enforces:
//   - Structured 4-part output (Summary, Key Findings, Risk, Recommendation)
//   - Max 200 words
//   - Direct, intelligent tone — no fluff
//   - JSON output wrapper for reliable parsing
//
// =============================================================================

/**
 * Builds the complete Gemini prompt with financial data injected.
 *
 * @param {Object} data - Financial data to inject into template.
 * @param {number} data.revenue
 * @param {number} data.netIncome
 * @param {number} data.totalAssets
 * @param {number} data.totalLiabilities
 * @param {number} data.cashFlow
 * @param {number} data.beneishScore
 * @returns {string} The complete prompt string.
 */
function buildPrompt(data) {
  const {
    revenue,
    netIncome,
    totalAssets,
    totalLiabilities,
    cashFlow,
    beneishScore,
  } = data;

  // Format numbers for readability in the prompt
  const fmt = (n) => Number(n).toLocaleString("en-US");

  return `You are a financial analyst AI.

Your task is to analyze financial data and detect potential fraud signals using Beneish M-Score logic and financial reasoning.

---

## INPUT DATA

Revenue: ${fmt(revenue)}
Net Income: ${fmt(netIncome)}
Total Assets: ${fmt(totalAssets)}
Total Liabilities: ${fmt(totalLiabilities)}
Cash Flow: ${fmt(cashFlow)}
Beneish Score: ${beneishScore}

---

## INSTRUCTIONS

- Be direct, precise, and structured.
- Do NOT hallucinate unknown data.
- Base your reasoning ONLY on provided data.
- Write like a senior financial analyst.

---

## OUTPUT FORMAT (STRICT)

You MUST respond with a valid JSON object with exactly these 4 keys:

{
  "summary": "Short explanation of financial condition.",
  "keyFindings": "Bullet points explaining anomalies or signals. Use \\n for line breaks.",
  "riskAnalysis": "Explain fraud likelihood and reasoning.",
  "recommendation": "Clear actions for the user."
}

---

## STYLE (VERY IMPORTANT)

- Direct
- Intelligent
- No fluff
- No generic advice
- No repetition

---

## EXAMPLE TONE

Bad:
"The company seems okay overall but might have some issues."

Good:
"Revenue growth is not supported by cash flow. This is a classic early warning signal."

---

## CONSTRAINTS

- Max 200 words total across all 4 fields
- Avoid vague words like "maybe", "possibly"
- Be confident but not absolute
- Return ONLY the JSON object, no markdown fences, no explanation

---

Respond now.`;
}

module.exports = { buildPrompt };
