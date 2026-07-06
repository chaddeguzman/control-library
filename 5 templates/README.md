# 5 templates

Reusable output templates live here.

Add one Markdown file per baseline document type, such as:

- `Reports Template.md`
- `Smartform Template.md`
- `Interface Template.md`
- `Enhancement Template.md`

The harness compares each inbound file name and content against these template names, headings, `topics`, and `applies_to` front matter. When a match is found, the selected skill uses that template as the baseline structure for the generated output.
