/* ---------- toast ---------- */

const toast = document.querySelector(".toast");

function showToast(message) {
    if (!toast) {
        return;
    }
    toast.textContent = message;
    toast.classList.add("visible");
    window.clearTimeout(showToast.timeout);
    showToast.timeout = window.setTimeout(() => {
        toast.classList.remove("visible");
    }, 2200);
}

async function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(text);
        return;
    }
    const textArea = document.createElement("textarea");
    textArea.value = text;
    textArea.setAttribute("readonly", "");
    textArea.style.position = "fixed";
    textArea.style.left = "-9999px";
    document.body.appendChild(textArea);
    textArea.select();
    document.execCommand("copy");
    document.body.removeChild(textArea);
}

document.addEventListener("click", async (event) => {
    const copyButton = event.target.closest("[data-copy]");
    const blockButton = event.target.closest("[data-copy-block]");

    if (!copyButton && !blockButton) {
        return;
    }

    const value = copyButton
        ? copyButton.dataset.copy
        : document.getElementById(blockButton.dataset.copyBlock)?.innerText;

    if (!value) {
        showToast("Nothing to copy");
        return;
    }

    try {
        await copyText(value.trim());
        showToast("Copied to clipboard");
    } catch (error) {
        showToast("Copy failed");
    }
});

/* ---------- mobile nav toggle ---------- */

const navToggle = document.querySelector(".nav-toggle");
const navActions = document.querySelector(".nav-actions");

if (navToggle && navActions) {
    navToggle.addEventListener("click", () => {
        const isOpen = navActions.classList.toggle("is-open");
        navToggle.setAttribute("aria-expanded", String(isOpen));
    });

    navActions.querySelectorAll("a").forEach((link) => {
        link.addEventListener("click", () => {
            navActions.classList.remove("is-open");
            navToggle.setAttribute("aria-expanded", "false");
        });
    });
}

/* ---------- active nav link + scroll reveal ---------- */

const revealTargets = document.querySelectorAll(".reveal");

if (revealTargets.length) {
    const revealObserver = new IntersectionObserver(
        (entries) => {
            entries.forEach((entry) => {
                if (entry.isIntersecting) {
                    entry.target.classList.add("is-visible");
                    revealObserver.unobserve(entry.target);
                }
            });
        },
        { threshold: 0.12 }
    );
    revealTargets.forEach((el) => revealObserver.observe(el));
}

const navLinks = document.querySelectorAll(".nav-actions a[href^='#']");
const navSections = Array.from(navLinks)
    .map((link) => document.querySelector(link.getAttribute("href")))
    .filter(Boolean);

if (navSections.length) {
    const navObserver = new IntersectionObserver(
        (entries) => {
            entries.forEach((entry) => {
                const link = document.querySelector(`.nav-actions a[href="#${entry.target.id}"]`);
                if (!link) return;
                if (entry.isIntersecting) {
                    navLinks.forEach((l) => l.classList.remove("is-active"));
                    link.classList.add("is-active");
                }
            });
        },
        { rootMargin: "-45% 0px -45% 0px" }
    );
    navSections.forEach((section) => navObserver.observe(section));
}

/* ---------- pipeline simulation ---------- */

const pipelineTrack = document.getElementById("pipelineTrack");
const pipelineToken = document.getElementById("pipelineToken");
const runButton = document.getElementById("runPipeline");
const consoleOutput = document.getElementById("consoleOutput");
const consoleDot = document.getElementById("consoleDot");
const skillChoice = document.getElementById("skillChoice");
const skillChoiceButtons = document.querySelectorAll(".skill-choice-btn");
const selectedSkillPanel = document.getElementById("selectedSkill");
const createSkillForm = document.getElementById("createSkillForm");
const createSkillQuestion = document.getElementById("createSkillQuestion");
const createSkillAnswer = document.getElementById("createSkillAnswer");

const pipelineSteps = pipelineTrack ? Array.from(pipelineTrack.querySelectorAll(".flow-node")) : [];
const skillOptions = {
    tech: {
        label: "Technical Specs",
        file: "TechSpecGen.md",
        inboundFile: "1 inbound/ZSD_SALESREPORT.txt",
        fileType: "Reports",
        fileTypeDescription: "Reports program",
        template: "Reports Template.md",
        output: "ZSD_SALESREPORT - tech specs.md",
    },
    func: {
        label: "Functional Specs",
        file: "FuncSpecGen.md",
        template: "Functional spec template",
        output: "functional-spec.md",
    },
    create: {
        label: "Create New Skill",
        file: "CreateSkill.MD",
        utility: true,
    },
};

function logLine(text, ok) {
    if (!consoleOutput) return;
    const placeholder = consoleOutput.querySelector(".console-placeholder");
    if (placeholder) placeholder.remove();

    const line = document.createElement("div");
    line.className = "log-line" + (ok ? " is-ok" : "");
    const time = new Date().toLocaleTimeString([], { hour12: false });
    line.innerHTML = `<span class="t">${time}</span>${text}`;
    consoleOutput.appendChild(line);
    consoleOutput.scrollTop = consoleOutput.scrollHeight;
}

function moveTokenTo(node) {
    if (!pipelineToken || !pipelineTrack) return;
    const trackRect = pipelineTrack.getBoundingClientRect();
    const nodeRect = node.getBoundingClientRect();
    const top = nodeRect.top - trackRect.top + nodeRect.height / 2;
    const left = nodeRect.left - trackRect.left + nodeRect.width / 2;
    pipelineToken.style.top = `${top}px`;
    pipelineToken.style.left = `${left}px`;
    pipelineToken.classList.add("is-live");
}

function sleep(ms) {
    return new Promise((resolve) => window.setTimeout(resolve, ms));
}

function getSafeSkillFileName(name) {
    let safeName = String(name || "").trim().replace(/[^A-Za-z0-9]+/g, "");
    if (!safeName) {
        safeName = "NewSkill";
    }
    return `${safeName}.md`;
}

function requestCreateSkillDetails() {
    if (!createSkillForm) {
        return Promise.resolve({
            skillName: "NewSkill",
            goal: "Create a new reusable skill.",
            functionality: "Transforms source material into a structured output.",
            input: "User-provided source material.",
            output: "A structured Markdown document.",
        });
    }

    createSkillForm.hidden = false;
    const questions = [
        {
            key: "skillName",
            label: "Skill Name",
            placeholder: "Example: PeerReviewer",
        },
        {
            key: "goal",
            label: "Goal",
            placeholder: "What should this skill help accomplish?",
        },
        {
            key: "functionality",
            label: "Functionality",
            placeholder: "What should this skill do step by step?",
        },
        {
            key: "input",
            label: "Expected Input",
            placeholder: "What source file, notes, data, or context should it expect?",
        },
        {
            key: "output",
            label: "Expected Output",
            placeholder: "What final document, sections, format, or deliverable should it produce?",
        },
    ];
    const answers = {};
    let index = 0;

    const showQuestion = () => {
        const question = questions[index];
        if (createSkillQuestion) createSkillQuestion.textContent = question.label;
        if (createSkillAnswer) {
            createSkillAnswer.value = "";
            createSkillAnswer.placeholder = `${question.placeholder} Press Enter to continue.`;
            createSkillAnswer.focus();
        }
    };

    showQuestion();

    return new Promise((resolve) => {
        const handleAnswerKeydown = (event) => {
            if (event.key === "Enter" && !event.shiftKey) {
                event.preventDefault();
                createSkillForm.requestSubmit();
            }
        };

        const handleSubmit = (event) => {
            event.preventDefault();
            const question = questions[index];
            const answer = createSkillAnswer ? createSkillAnswer.value.trim() : "";
            if (!answer) return;

            answers[question.key] = answer;
            logLine(`${question.label}: ${answer}`);
            index += 1;

            if (index < questions.length) {
                showQuestion();
                return;
            }

            createSkillForm.hidden = true;
            createSkillForm.removeEventListener("submit", handleSubmit);
            if (createSkillAnswer) {
                createSkillAnswer.removeEventListener("keydown", handleAnswerKeydown);
            }
            resolve(answers);
        };

        createSkillForm.addEventListener("submit", handleSubmit);
        if (createSkillAnswer) {
            createSkillAnswer.addEventListener("keydown", handleAnswerKeydown);
        }
    });
}

async function runCreateSkillSimulation(selectedSkill) {
    logLine("Create New Skill wizard started", true);
    await sleep(420);
    logLine("Answer each question below the run log.");
    const details = await requestCreateSkillDetails();
    await sleep(420);
    const skillFileName = getSafeSkillFileName(details.skillName);
    logLine(`Skill functionality captured: ${details.functionality}`);
    logLine(`Created skill file in 3 skills/${skillFileName}`, true);
}

function chooseSkill() {
    if (!skillChoice) return Promise.resolve(skillOptions.tech);

    skillChoice.hidden = false;
    skillChoiceButtons.forEach((button) => {
        button.disabled = false;
        button.classList.remove("is-selected");
    });

    return new Promise((resolve) => {
        const handleChoice = (event) => {
            const button = event.currentTarget;
            const selected = skillOptions[button.dataset.skill] || skillOptions.tech;
            skillChoiceButtons.forEach((btn) => {
                btn.disabled = true;
                btn.classList.toggle("is-selected", btn === button);
            });
            window.setTimeout(() => {
                skillChoice.hidden = true;
                skillChoiceButtons.forEach((btn) => btn.removeEventListener("click", handleChoice));
                resolve(selected);
            }, 260);
        };

        skillChoiceButtons.forEach((button) => button.addEventListener("click", handleChoice));
    });
}

async function runPipelineSimulation() {
    if (!pipelineSteps.length || !runButton) return;

    runButton.disabled = true;
    runButton.textContent = "Running…";
    if (consoleDot) consoleDot.classList.add("is-live");

    if (consoleOutput) {
        consoleOutput.innerHTML = "";
    }

    pipelineSteps.forEach((n) => n.classList.remove("is-active", "is-done"));
    if (skillChoice) skillChoice.hidden = true;
    if (createSkillForm) createSkillForm.hidden = true;
    if (selectedSkillPanel) {
        selectedSkillPanel.hidden = true;
        const value = selectedSkillPanel.querySelector("strong");
        if (value) value.textContent = "None";
    }
    let selectedSkill = null;

    for (let i = 0; i < pipelineSteps.length; i += 1) {
        const node = pipelineSteps[i];
        pipelineSteps.forEach((n) => n.classList.remove("is-active"));
        node.classList.add("is-active");
        moveTokenTo(node);

        if (node.dataset.skipLog !== "true") {
            logLine(node.dataset.log || node.textContent.trim());
        }

        if (i === 0) {
            logLine(`Inbound file found: ${skillOptions.tech.inboundFile}`, true);
        }

        if (node.dataset.step === "choose-skill") {
            logLine("Waiting for skill selection...");
            selectedSkill = await chooseSkill();
            if (selectedSkillPanel) {
                const value = selectedSkillPanel.querySelector("strong");
                if (value) value.textContent = selectedSkill.label;
                selectedSkillPanel.hidden = false;
            }
            logLine(`Selected skill: ${selectedSkill.file}`, true);
            if (selectedSkill.fileTypeDescription) {
                logLine(`File Type determined as a "${selectedSkill.fileType}" program`, true);
            }
            if (selectedSkill.utility) {
                await runCreateSkillSimulation(selectedSkill);
                node.classList.remove("is-active");
                node.classList.add("is-done");
                break;
            }
        }

        if (node.dataset.step === "template") {
            await sleep(280);
            const templateLabel = selectedSkill?.template || "Matching template";
            if (selectedSkill?.fileTypeDescription) {
                const displayTemplate = templateLabel.replace(/\.md$/i, "");
                logLine(`${displayTemplate} will be used as the File Type matched as ${selectedSkill.fileType}`, true);
            } else {
                logLine(`Matched ${templateLabel}`, true);
            }
        }

        await sleep(650);
        node.classList.remove("is-active");
        node.classList.add("is-done");
    }

    if (pipelineToken) {
        pipelineToken.classList.remove("is-live");
    }

    if (selectedSkill?.utility) {
        logLine("Create skill simulation complete. No inbound file processed.", true);
    } else if (selectedSkill) {
        logLine(`Markdown written to 6 output/${selectedSkill.output}`, true);
    }
    logLine("Run complete. Log written to 2 harness/logs/", true);
    if (consoleDot) consoleDot.classList.remove("is-live");

    runButton.disabled = false;
    runButton.textContent = "Simulate Again";
}

if (runButton) {
    runButton.addEventListener("click", runPipelineSimulation);
}

window.addEventListener("resize", () => {
    const activeNode = pipelineTrack ? pipelineTrack.querySelector(".flow-node.is-active") : null;
    if (activeNode) {
        moveTokenTo(activeNode);
    }
});

/* ---------- library tabs ---------- */

const folderData = {
    inbound: {
        label: "1 inbound/",
        status: "local",
        summary: "Drop zone for source files waiting to be turned into a document. Nothing here is meant to stay long-term.",
        points: [
            "Accepts <code>.txt</code>, <code>.md</code>, <code>.markdown</code>, <code>.csv</code>, <code>.json</code>, <code>.xml</code>, <code>.log</code>.",
            "Files the harness can't read are left in place and noted in the run log.",
            "<code>1 inbound/Done/</code> holds originals after a successful run.",
        ],
    },
    harness: {
        label: "2 harness/",
        status: "shared",
        summary: "The shared library runner that ties source file, skill, references, and template together.",
        points: [
            "<code>run-inbound-skill.ps1</code> is invoked by <code>Run Skill.bat</code>.",
            "After a skill is selected, it loads <code>hard rules/</code> and <code>validation checks/</code>.",
            "Uses <code>codex exec</code>, so the Codex CLI must be installed and authenticated locally.",
            "<code>2 harness/logs/</code> keeps a record of every run. Logs stay local, the script is shared.",
        ],
    },
    skills: {
        label: "3 skills/",
        status: "shared",
        summary: "Shared library instructions describing exactly what kind of document Codex should produce.",
        points: [
            "Ships with <code>TechSpecGen.md</code>, <code>FuncSpecGen.md</code>, and <code>CreateSkill.MD</code>.",
            "Add a new <code>.md</code> file here and it appears in the <code>Run Skill.bat</code> menu on the next run.",
            "Keep instructions focused on the transformation. Push shared context to <code>4 references/</code> instead.",
        ],
    },
    references: {
        label: "4 references/",
        status: "shared",
        summary: "Shared library guidance a skill can pull in automatically: standards, examples, coding practices, review guidance.",
        points: [
            "Matched by name, first heading, or front matter against the selected skill.",
            "Add <code>applies_to</code> to tie a file to one skill, or <code>topics</code> for broader matching.",
            "This is the right place for durable guidance. Keep skills themselves task-focused.",
        ],
    },
    templates: {
        label: "5 templates/",
        status: "shared",
        summary: "Shared library structures the skill cross-checks output against before writing the final document.",
        points: [
            "Holds structures for technical specs, functional specs, and other reusable output types.",
            "The harness picks the closest matching template for the document being generated.",
            "Update a template once and every future run benefits from it.",
        ],
    },
    output: {
        label: "6 output/",
        status: "local",
        summary: "Where finished Markdown documents land after a run, the thing you actually came here for.",
        points: [
            "One generated file per processed source file.",
            "Built from the source file, the chosen skill, matched references, and template guidance.",
            "Not committed to GitHub; treated as local output only.",
        ],
    },
};

const tabButtons = document.querySelectorAll(".tab-btn");
const libraryPanel = document.getElementById("libraryPanel");

function renderFolder(key) {
    const data = folderData[key];
    if (!data || !libraryPanel) return;

    const isShared = data.status === "shared";
    const statusLabel = isShared ? "Shared Library" : "Local only";
    const statusStyle = isShared
        ? "border-color: var(--mint); color: var(--mint); box-shadow: 0 0 0 3px var(--mint-dim);"
        : "";

    libraryPanel.innerHTML = `
        <div class="library-panel-header">
            <h3>${data.label}</h3>
            <span class="status-pill ${data.status}" style="${statusStyle}">${statusLabel}</span>
        </div>
        <p>${data.summary}</p>
        <ul>${data.points.map((point) => `<li>${point}</li>`).join("")}</ul>
    `;
}

tabButtons.forEach((btn) => {
    btn.addEventListener("click", () => {
        tabButtons.forEach((b) => {
            b.classList.remove("is-active");
            b.setAttribute("aria-pressed", "false");
        });
        btn.classList.add("is-active");
        btn.setAttribute("aria-pressed", "true");
        renderFolder(btn.dataset.folder);
    });
});

if (tabButtons.length) {
    renderFolder(tabButtons[0].dataset.folder);
}
