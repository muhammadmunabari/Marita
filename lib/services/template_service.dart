import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:marita/models/prompt_template.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

class TemplateService {
  static final _firestore = FirebaseFirestore.instance;

  static List<PromptTemplate> getStaticTemplates() {
    return [
      const PromptTemplate(
        id: 'summarize_document',
        title: 'Summarize this document',
        description: 'Extract and summarize information from complex documents.',
        prompt: 'You are a senior document analyst with over 15 years of experience extracting and summarising information from complex documents – including financial reports, contracts, invoices, research papers, scanned images, spreadsheets, and text files. Your task is to summarise the attached file(s) and extract all relevant, structured data from them. The file can be in any common format: PDF, Word (.doc/.docx), Excel (.xls/.xlsx), CSV, image (JPG, PNG, TIFF – OCR will be assumed), plain text, or PowerPoint. Your methodology: - First, identify the document type and its primary purpose (e.g., “This is a quarterly financial report”, “This is an employment contract”, “This is an invoice”). - Second, extract key quantitative and qualitative data points (e.g., dates, names, total amounts, itemised costs, key clauses, or summary findings). - Third, provide a high-level summary (3–5 sentences) of the overall content. - Fourth, list any critical action items, risks, or upcoming deadlines found in the document. Formatting: Use clear headings and bullet points. If you find financial data, present it in a clean markdown table. If the document is an image or scan, proceed with extraction as if OCR has been applied. Your goal is to provide a complete, professional overview so I don\'t have to read the entire document myself.',
        icon: IconsaxPlusLinear.document_text,
      ),
      const PromptTemplate(
        id: 'analyze_financials',
        title: 'Analyze financial statement',
        description: 'Perform a comprehensive analysis of financial statements.',
        prompt: 'You are an expert Forensic Accountant and Financial Analyst specializing in deep-dive financial audits and corporate performance evaluation. Your objective is to perform a comprehensive analysis of the attached financial statement(s) (Balance Sheet, Income Statement, Cash Flow Statement, or Trial Balance). Your analysis must cover the following: 1. Financial Health Check: Evaluate the company’s liquidity, solvency, and profitability based on the provided data. Calculate key ratios (e.g., Current Ratio, Debt-to-Equity, Net Profit Margin) if sufficient data exists. 2. Trend Identification: Identify significant year-over-year or month-over-month changes in revenue, expenses, and asset values. Highlight any alarming trends. 3. Cash Flow Assessment: Determine if the cash flow matches the reported profits and identify where the majority of cash is being spent or generated. 4. Discrepancy & Red Flag Detection: Point out any inconsistencies, such as abnormal expense spikes, missing documentation references, or unusual accounting treatments. Formatting: Start with an Executive Summary. Use tables for financial ratio comparisons. End with a “Conclusion and Recommendations” section. Be thorough, objective, and professional.',
        icon: IconsaxPlusLinear.graph,
      ),
      const PromptTemplate(
        id: 'detect_fraud',
        title: 'Detect fraud indicators',
        description: 'Scrutinize records to identify potential fraud red flags.',
        prompt: 'You are a Certified Fraud Examiner (CFE) and Anti-Money Laundering (AML) specialist. Your mission is to scrutinise the attached financial records, transaction logs, or bank statements to identify potential fraud indicators (red flags). Apply the Fraud Triangle theory (Incentive, Opportunity, Rationalisation) and focus on the following: 1. Duplicate & Ghost Transactions: Look for duplicate invoice numbers, similar amounts paid to the same vendor within a short window, or payments to suspicious/unregistered entities. 2. Unusual Patterns: Identify transactions occurring at irregular hours, rounded-sum payments, or frequent small transfers that stay just below reporting thresholds (structuring). 3. Vendor/Employee Anomalies: Check for potential conflicts of interest, such as vendors sharing addresses with employees or unusual changes in vendor banking details. 4. Regulatory Non-Compliance: Flag any transactions that appear to violate standard accounting principles or local financial regulations. Output: Provide a “Risk Assessment Score” (Low, Medium, High). List each suspicious finding in a bulleted list, explaining WHY it is considered a red flag. Recommend immediate investigative next steps.',
        icon: IconsaxPlusLinear.shield_search,
      ),
      const PromptTemplate(
        id: 'generate_findings',
        title: 'Generate audit findings',
        description: 'Generate formal audit findings based on compliance reports.',
        prompt: 'You are a Lead Internal Auditor responsible for preparing professional audit reports for executive management and stakeholders. Based on the provided files (could be internal controls documentation, ledger entries, or compliance reports), your task is to generate formal audit findings. Structure each finding using the standard audit criteria: 1. Condition: Describe the specific issue or deviation found (e.g., "Lack of dual authorization for payments over \$5,000"). 2. Criteria: State the standard, policy, or regulation that should have been followed (e.g., "Company Policy #104 requires two signatures for large disbursements"). 3. Cause: Explain why the issue occurred (e.g., "System override by a single administrator"). 4. Effect: Detail the potential impact or risk (e.g., "Increased risk of unauthorized fund transfers and financial loss"). 5. Recommendation: Provide a clear, actionable solution to remediate the finding. Formatting: Use a structured report format. Ensure the tone is objective and constructive. If multiple findings are found, rank them by severity (High, Medium, Low).',
        icon: IconsaxPlusLinear.document_favorite,
      ),
    ];
  }

  /// Fetches custom templates for a specific user from Firestore.
  static Future<List<PromptTemplate>> getCustomTemplates(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('custom_templates')
          .get();

      return snapshot.docs
          .map((doc) => PromptTemplate.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Saves a new custom template to Firestore.
  static Future<bool> saveCustomTemplate(String userId, PromptTemplate template) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('custom_templates')
          .doc(template.id)
          .set(template.toMap());
      return true;
    } catch (e) {
      return false;
    }
  }
}
