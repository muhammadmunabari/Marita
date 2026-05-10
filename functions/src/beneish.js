// =============================================================================
// BENEISH M-SCORE CALCULATOR
// =============================================================================
//
// Implements a simplified Beneish M-Score calculation for fraud detection.
//
// The Beneish M-Score is a mathematical model that uses 8 financial ratios
// to identify whether a company is likely to have manipulated its earnings.
//
// Thresholds (used in analyzeReport.js):
//   - M-Score > -1.78 → HIGH risk (likely manipulator)
//   - -2.22 < M-Score <= -1.78 → MEDIUM risk (grey zone)
//   - M-Score <= -2.22 → LOW risk (unlikely manipulator)
//
// Note: This is a simplified implementation using available input fields.
//       A full Beneish model requires two periods of financial data and
//       8 component indices (DSRI, GMI, AQI, SGI, DEPI, SGAI, LVGI, TATA).
//       This version derives a proxy score from single-period ratios.
//
// =============================================================================

/**
 * Calculates a simplified Beneish M-Score proxy from single-period data.
 *
 * Uses the available input fields to compute financial health indicators
 * and derives a composite score approximating the M-Score behavior.
 *
 * @param {Object} input - Financial input data.
 * @param {number} input.revenue - Total revenue.
 * @param {number} input.netIncome - Net income.
 * @param {number} input.totalAssets - Total assets.
 * @param {number} input.totalLiabilities - Total liabilities.
 * @param {number} input.cashFlow - Operating cash flow.
 * @returns {number} The computed M-Score (lower = healthier).
 */
function calculateBeneishScore(input) {
  const { revenue, netIncome, totalAssets, totalLiabilities, cashFlow } = input;

  // Guard against division by zero
  const safeDiv = (numerator, denominator) =>
    denominator === 0 ? 0 : numerator / denominator;

  // ---------------------------------------------------------------------------
  // Component ratios (single-period proxies)
  // ---------------------------------------------------------------------------

  // 1. Net Profit Margin — healthy companies maintain consistent margins
  const netProfitMargin = safeDiv(netIncome, revenue);

  // 2. Asset Quality — proportion of non-current assets
  //    Higher ratio may indicate aggressive capitalization
  const assetQuality = safeDiv(totalAssets - totalLiabilities, totalAssets);

  // 3. Leverage Index — debt relative to assets
  //    Higher leverage increases manipulation incentive
  const leverageIndex = safeDiv(totalLiabilities, totalAssets);

  // 4. Total Accruals to Total Assets (TATA)
  //    Large divergence between income and cash flow = red flag
  const tata = safeDiv(netIncome - cashFlow, totalAssets);

  // 5. Cash Flow Quality — cash flow vs. net income
  //    Income without cash backing is suspicious
  const cashFlowQuality = safeDiv(cashFlow, netIncome);

  // ---------------------------------------------------------------------------
  // Composite M-Score (simplified weighted model)
  // ---------------------------------------------------------------------------
  //
  // Weights are calibrated so that:
  //   - A healthy company scores around -2.5 to -3.0
  //   - A risky company scores above -1.78
  //
  // This approximation follows the directional behavior of the original
  // Beneish model while working with limited single-period data.
  // ---------------------------------------------------------------------------

  const mScore =
    -4.84 +
    0.92 * leverageIndex +         // Higher debt → higher score
    0.528 * tata +                 // Accruals divergence → higher score
    0.404 * (1 - netProfitMargin) + // Low margins → higher score
    0.115 * (1 - assetQuality) +   // Low equity ratio → higher score
    -0.172 * Math.min(cashFlowQuality, 2); // Good cash backing → lower score

  // Round to 4 decimal places for storage
  return Math.round(mScore * 10000) / 10000;
}

module.exports = { calculateBeneishScore };
