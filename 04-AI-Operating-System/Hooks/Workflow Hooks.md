# Workflow Hooks

Hooks are workflow trigger points where AI behavior can be attached later.

## Active Hooks

### On Source Upload

- Store source reference in [[03-Document-Intake/Uploaded-Source-Docs/README|Uploaded Source Docs]].
- Extract context into [[03-Document-Intake/Parsed-Context/README|Parsed Context]].
- Run intent classification using [[02-Technical-Documentation/Technical Doc Intent Model|Technical Doc Intent Model]].

### On Technical Intent Confirmed

- Clone [[02-Technical-Documentation/Templates/Technical Documentation Template|Technical Documentation Template]].
- Populate source-grounded sections.
- Mark assumptions and open questions.

### On Clone Generated

- Run [[02-Technical-Documentation/Technical Doc Quality Bar|Technical Doc Quality Bar]].
- Set status to `needs-technical-review`.

## Future Hooks

- On peer review requested
- On deck requested
- On functional documentation requested
