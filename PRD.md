# Product Requirements Document

## Product

Control Library

## Objective

Create a controlled AI-assisted workspace where users can upload source documents and generate cloned technical documentation based on an approved target structure.

## Primary Users

- Technical users who need implementation, architecture, integration, and operational documentation.
- Functional users who provide business context and source material.
- Reviewers who validate generated technical documentation before approval.

## Current Scope

Technical documentation cloning only.

The first supported workflow is:

1. User provides a source document.
2. AI extracts source-grounded technical context.
3. AI classifies whether the source supports technical documentation.
4. AI clones the approved technical documentation template.
5. AI populates source-backed sections and labels assumptions.
6. Reviewer checks the generated clone before approval.

## Out Of Scope

- Functional documentation generation
- Peer review automation
- Sora deck creation
- Compliance evidence packs
- Automated publishing
- Old local harness/runtime workflow files

## Required Vault Areas

- Product vision and scope
- Technical documentation template
- Document intake
- AI context
- AI memory
- AI rules
- AI hooks
- AI prompts
- Future skills roadmap
- Canvases that connect workflow and decisions

## Website Requirement

The repository must expose a static website with:

- `index.html`
- `style.css`
- `script.js`

These files live at the repository root so GitHub Pages serves the existing
repository URL directly.

## Success Criteria

- The repository root contains the Control Library vault and static site.
- Non-PRD harness/runtime folders are removed.
- The static site is viewable online.
- Obsidian vault files remain usable locally.
- Local Obsidian settings remain untracked, with reusable defaults under `system/obsidian-template/`.
- Future skills are visible in the roadmap but not mixed into the active technical documentation workflow.

