# TechSpecGen

Generate a technical specification Markdown document from the inbound source file.

Before drafting, identify the inbound object's type from the file name and source content. Examples include Report, Smartform, Interface, Enhancement, Table, Batch Job, Form, Workflow, or other program/object families.

Use the matching Markdown file from `5 templates/` as the baseline when one exists. For example:

- A Reports program should use a Reports template.
- A Smartform should use a Smartform template.
- An Interface should use an Interface template.

Follow the matched template's headings, section order, and required fields. Use the inbound file to populate the template, preserve source-specific details, and do not invent unsupported business facts. If a required template section cannot be completed from the source, mark it as `TBD` or capture it under `Open Questions`.

If no matching template exists, create a clear engineering-facing tech spec using this fallback structure:

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
