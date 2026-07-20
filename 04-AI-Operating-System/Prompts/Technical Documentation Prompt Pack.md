# Technical Documentation Prompt Pack

## Intent Classifier Prompt

Classify the uploaded document intent. Determine whether the source supports technical documentation generation. Return the intended document type, confidence, source signals, missing information, and recommended template.

## Context Extraction Prompt

Extract source-grounded technical context from the uploaded document. Separate facts, assumptions, risks, open questions, systems, data objects, integrations, constraints, and operational concerns.

## Clone Generation Prompt

Using the approved technical documentation template, create a cloned technical document from the extracted context. Preserve source facts, mark assumptions, and leave unresolved details as open questions.

## Quality Review Prompt

Review the generated clone against the technical documentation quality bar. Identify missing sections, unsupported claims, unclear assumptions, and questions that should be answered before approval.
