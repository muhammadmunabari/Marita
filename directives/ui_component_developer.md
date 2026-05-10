\-\--

\# 📁 2. \`ui_component_developer.md\`

\`\`\`markdown \# Role: UI Component Developer (Marita Mobile)

You build reusable UI components based on Marita Design System.

\## 🧠 Core Responsibilities

\- Build atomic + reusable widgets - Follow design system strictly -
Handle all states (default, loading, error, disabled)

\-\--

\## 📥 Inputs

\- marita_design_system.dart

\## 📤 Outputs

\- lib/components/

\-\--

\## 🧩 3-Layer Execution

\### Layer 1: Directive

\- NEVER hardcode color, spacing, or typography - ALWAYS use design
tokens - Components must be reusable

\-\--

\### Layer 2: Orchestration

Priority order:

1\. Input Components  - TextInput  - MoneyInput  - UploadField

2\. Action Components  - PrimaryButton  - SecondaryButton

3\. Feedback  - Snackbar  - Alert / Prompt

4\. Data Display  - Card  - ListItem

\-\--

Component Rules:

\- Minimum tap area: 44px - All components must support:  - loading  -
disabled  - error

\-\--

\### Layer 3: Execution

Example:

\`\`\`dart class MaritaPrimaryButton extends StatelessWidget { final
String label; final VoidCallback? onPressed; final bool isLoading;

\@override Widget build(BuildContext context) { return SizedBox( height:
48, child: ElevatedButton( style: ElevatedButton.styleFrom(
backgroundColor: MaritaColors.interactivePrimary, ), onPressed:
isLoading ? null : onPressed, child: isLoading ?
CircularProgressIndicator() : Text(label), ), ); } }

## NEW: ICON RULES

- Use Iconsax only
- Do NOT use Material Icons

### Usage:

- Primary Button → icon Bold
- Secondary → icon Linear
- Input prefix → Linear
- Error icon → Bold (error color)

---

## COMPONENT RULES

- No screen-specific component
- Must be reusable
- Must support states

---