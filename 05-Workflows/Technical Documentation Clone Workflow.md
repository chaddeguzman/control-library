# Technical Documentation Clone Workflow

## Goal

Convert an uploaded source document into a source-grounded technical documentation clone.

## Workflow

1. Receive source document.
2. Store source reference in [[03-Document-Intake/Uploaded-Source-Docs/README|Uploaded Source Docs]].
3. Extract parsed context into [[03-Document-Intake/Parsed-Context/README|Parsed Context]].
4. Classify intent using [[02-Technical-Documentation/Technical Doc Intent Model|Technical Doc Intent Model]].
5. If technical intent is confirmed, clone [[02-Technical-Documentation/Templates/Technical Documentation Template|Technical Documentation Template]].
6. Populate the clone with source-grounded content.
7. Run [[02-Technical-Documentation/Technical Doc Quality Bar|Technical Doc Quality Bar]].
8. Store output in [[03-Document-Intake/Generated-Clones/README|Generated Clones]].
9. Route for technical review.

## Stop Conditions

- Source does not support technical documentation.
- Required technical context is missing.
- Template selection is ambiguous.
- Confidentiality rules prevent generation.
