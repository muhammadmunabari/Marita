# Financial Statement Report Evaluation Flowchart

This document outlines the pipeline for the Financial Statement Report Evaluation, specifically detailing the integration of the "LLM as a Judge" for fact verification.

```mermaid
flowchart TD
    %% Define Styles
    classDef input fill:#e1f5fe,stroke:#0288d1,stroke-width:2px,color:#000
    classDef process fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px,color:#000
    classDef llmJudge fill:#fff3e0,stroke:#e65100,stroke-width:2px,color:#000
    classDef criteria fill:#e8eaf6,stroke:#3f51b5,stroke-width:2px,color:#000
    classDef output fill:#e8f5e9,stroke:#388e3c,stroke-width:2px,color:#000

    %% Core Flow
    A[Financial Statement Report Collection<br/>PDF Upload & RAG Context]:::input
    B[Test Questions<br/>14-Stage Analysis System Prompts]:::input
    C[Gemini Responses<br/>Phase 1 & 2 Generation & Draft Audit]:::process
    
    %% New LLM as a Judge Step
    D[LLM as a Judge<br/>Fact Verification against Source Context]:::llmJudge
    
    %% Assessment & Evaluation
    E[Assessment Criteria]:::criteria
    F(Full Correct):::output
    G(Semi Correct):::output
    H(Incorrect):::output
    
    I[Evaluation and Analysis<br/>Precision & Confidence Metrics]:::process
    J[Final Risk Intelligence Report]:::output

    %% Relationships
    A --> C
    B --> C
    
    %% Passing the draft to the judge
    C --> D
    
    %% Judge applies criteria
    D --> E
    E --> F
    E --> G
    E --> H
    
    %% Criteria fed into Evaluation
    F --> I
    G --> I
    H --> I
    
    %% Final output
    I --> J
```
