# TechSpecGen

Generate a technical specification Markdown document from the inbound source file.

Create a clear engineering-facing tech spec using this structure:

1. `# Technical Specification: <descriptive title>`
2. `## Summary`
3. `## Goals`
4. `## Non-Goals`
5. `## Inputs and Outputs`
6. `## Functional Requirements`
7. `## Workflow`
8. `## Edge Cases and Failure Handling`
9. `## Acceptance Criteria`
10. `## Open Questions`

Preserve important names, dates, systems, fields, constraints, business rules, and user decisions from the source. If the source does not explicitly define a section, infer only conservative implementation details and mark uncertainty in `Open Questions`.

Return only the completed Markdown technical specification.
