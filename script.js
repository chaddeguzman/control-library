const workflowSteps = [
  {
    title: "Receive source document",
    body: "Store or link the uploaded material before any AI extraction runs."
  },
  {
    title: "Extract parsed context",
    body: "Separate systems, data, integrations, constraints, risks, and missing information."
  },
  {
    title: "Classify intent",
    body: "Confirm whether the source supports technical documentation generation."
  },
  {
    title: "Clone the template",
    body: "Use the approved technical documentation structure as the target document."
  },
  {
    title: "Generate source-grounded sections",
    body: "Populate content from source facts and label assumptions clearly."
  },
  {
    title: "Run review checks",
    body: "Route the generated clone for technical review with open questions visible."
  }
];

const folders = [
  ["00", "Control Library", "Home, maps, and operating entry points."],
  ["01", "Product Vision", "Product brief and scope guardrails."],
  ["02", "Technical Documentation", "Intent model, quality bar, template, and examples."],
  ["03", "Document Intake", "Uploaded sources, parsed context, and generated clones."],
  ["04", "AI Operating System", "Context, memory, rules, hooks, prompts, and roadmap."],
  ["05", "Workflows", "Repeatable operating workflows and startup checklist."],
  ["06", "Canvases", "Visual maps connecting notes and decision paths."],
  ["07", "Decisions", "Durable product and architecture decisions."],
  ["08", "Backlog", "Now, next, and later work items."],
  ["09", "Archive", "Inactive notes and retired drafts."]
];

const aiItems = [
  ["Context", "Current workspace facts and active scope."],
  ["Memory", "Stable product facts and durable decisions."],
  ["Rules", "Mandatory behavior for generation and review."],
  ["Hooks", "Trigger points for source upload, clone generation, and review."],
  ["Prompts", "Reusable classifier, extraction, generation, and quality prompts."],
  ["Skills Roadmap", "Deferred capabilities such as peer review and Sora deck creation."]
];

const templateSections = [
  "Summary",
  "Source Inputs",
  "Technical Context",
  "Architecture",
  "Data and Integration Details",
  "Implementation Plan",
  "Operational Concerns",
  "Security and Compliance Notes",
  "Risks and Assumptions",
  "Open Questions",
  "Review Checklist"
];

const qualityItems = [
  "Every major claim is source-grounded or labeled as an assumption.",
  "The output follows the approved technical documentation template.",
  "Risks, open questions, and unresolved source gaps remain visible.",
  "Engineers can identify systems, dependencies, interfaces, and failure modes.",
  "Future skills stay discoverable but inactive until promoted."
];

const canvases = [
  ["Control Library Map", "Top-level relationship between product, scope, intake, technical docs, and AI operations."],
  ["Technical Documentation Pipeline", "Source upload through reviewable generated clone."],
  ["AI Operating System", "How context, memory, rules, hooks, and prompts relate."],
  ["Future Skills Map", "Deferred skills and promotion path."],
  ["Intake Decision Map", "Decision route for technical intent versus future skills."],
  ["Technical Document Anatomy", "Template, quality bar, prompts, parsed context, and generated clones."]
];

function renderWorkflow() {
  const target = document.querySelector("#workflowSteps");
  target.innerHTML = workflowSteps
    .map(
      (step, index) => `
        <article class="step">
          <div class="step-number">${index + 1}</div>
          <h3>${step.title}</h3>
          <p>${step.body}</p>
        </article>
      `
    )
    .join("");
}

function renderFolders() {
  const target = document.querySelector("#folderGrid");
  target.innerHTML = folders
    .map(
      ([number, title, body]) => `
        <article class="folder-card">
          <span>${number}</span>
          <h3>${title}</h3>
          <p>${body}</p>
        </article>
      `
    )
    .join("");
}

function renderAiSystem() {
  const target = document.querySelector("#aiList");
  target.innerHTML = aiItems
    .map(
      ([title, body]) => `
        <article class="ai-item">
          <span>AI layer</span>
          <h3>${title}</h3>
          <p>${body}</p>
        </article>
      `
    )
    .join("");
}

function renderTemplate() {
  document.querySelector("#templateList").innerHTML = templateSections
    .map((section) => `<li>${section}</li>`)
    .join("");

  document.querySelector("#qualityList").innerHTML = qualityItems
    .map((item) => `<li>${item}</li>`)
    .join("");
}

function renderCanvases() {
  const target = document.querySelector("#canvasGrid");
  target.innerHTML = canvases
    .map(
      ([title, body]) => `
        <article class="canvas-card">
          <span>Canvas</span>
          <h3>${title}</h3>
          <p>${body}</p>
        </article>
      `
    )
    .join("");
}

renderWorkflow();
renderFolders();
renderAiSystem();
renderTemplate();
renderCanvases();
