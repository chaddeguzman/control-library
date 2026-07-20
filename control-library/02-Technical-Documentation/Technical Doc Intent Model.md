# Technical Doc Intent Model

Use this model to decide whether an uploaded source document should become a technical document.

## Strong Signals

- Mentions architecture, systems, APIs, data flow, integrations, jobs, infrastructure, environments, deployment, monitoring, or security controls.
- Describes implementation steps, technical decisions, constraints, dependencies, interfaces, schemas, or operational behavior.
- Includes diagrams, endpoints, field mappings, tables, platform names, logs, or configuration values.

## Weak Signals

- Contains business requirements but no implementation detail.
- Describes user journeys without technical systems.
- Requests a presentation, executive summary, or training artifact.

## Classification Output

Capture:

- `intended_doc_type`
- `confidence`
- `source_signals`
- `missing_information`
- `recommended_template`

If confidence is low, route the item to clarification rather than forcing a technical clone.
