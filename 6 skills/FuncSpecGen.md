# FuncSpecGen

Generate a functional specification Markdown document from the inbound source file.

Create a clear business-facing and user-facing functional spec using this structure:

1. `# Functional Specification: <descriptive title>`
2. `## Summary`
3. `## Business Objective`
4. `## Users and Stakeholders`
5. `## Scope`
6. `## Functional Requirements`
7. `## User Workflow`
8. `## Business Rules`
9. `## Inputs and Outputs`
10. `## Acceptance Criteria`
11. `## Open Questions`

Preserve important names, dates, roles, user actions, business rules, decisions, constraints, and expected outcomes from the source. Focus on what the solution must do for users and stakeholders, not on implementation architecture.

If the source does not explicitly define a section, infer only conservative functional details and mark uncertainty in `Open Questions`.

Return only the completed Markdown functional specification.
