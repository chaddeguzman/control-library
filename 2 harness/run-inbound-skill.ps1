param(
    [string]$SkillPath,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$InboundDir = Join-Path $ProjectRoot "1 inbound"
$DoneDir = Join-Path $InboundDir "Done"
$OutboundDir = Join-Path $ProjectRoot "6 output"
$ReferenceDir = Join-Path $ProjectRoot "4 references"
$TemplateDir = Join-Path $ProjectRoot "5 templates"
$SkillsDir = Join-Path $ProjectRoot "3 skills"
$HardRulesDir = Join-Path $PSScriptRoot "hard rules"
$ValidationChecksDir = Join-Path $PSScriptRoot "validation checks"
$LogDir = Join-Path $PSScriptRoot "logs"
$SupportedExtensions = @(".txt", ".md", ".markdown", ".csv", ".json", ".xml", ".log")
$ReferenceExtensions = @(".md", ".markdown")
$AlwaysOnExtensions = @(".md", ".markdown", ".txt")
$StopWords = @(
    "a", "an", "and", "are", "as", "be", "below", "by", "codex", "content", "create",
    "document", "file", "final", "for", "from", "generate", "how", "if", "in", "into",
    "is", "it", "local", "markdown", "of", "on", "only", "or", "return", "selected",
    "should", "skill", "source", "text", "that", "the", "this", "to", "use", "with",
    "workflow", "you"
)

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    Add-Content -LiteralPath $script:LogPath -Value $line -Encoding UTF8
    Write-Host $line
}

function Get-SafeOutputPath {
    param(
        [string]$SourceFile
    )

    $stem = [System.IO.Path]::GetFileNameWithoutExtension($SourceFile)
    $invalidPattern = "[{0}]" -f [Regex]::Escape((-join [System.IO.Path]::GetInvalidFileNameChars()))
    $stem = [Regex]::Replace($stem, $invalidPattern, "_")

    if ([string]::IsNullOrWhiteSpace($stem)) {
        $stem = "output"
    }

    $candidate = Join-Path $OutboundDir "$stem.md"
    if (-not (Test-Path -LiteralPath $candidate)) {
        return $candidate
    }

    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    return (Join-Path $OutboundDir "$stem-$stamp.md")
}

function Get-ProjectRelativePath {
    param(
        [string]$Path
    )

    $rootPath = (Resolve-Path -LiteralPath $ProjectRoot).ProviderPath.TrimEnd("\")

    try {
        $fullPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    }
    catch {
        $fullPath = [System.IO.Path]::GetFullPath($Path)
    }

    if ($fullPath.StartsWith($rootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        $relativePath = $fullPath.Substring($rootPath.Length).TrimStart("\")
        if ($relativePath) {
            return ".\$relativePath"
        }
    }

    return $fullPath
}

function ConvertTo-ReferenceKeywords {
    param(
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }

    $expanded = [Regex]::Replace($Text, "([a-z0-9])([A-Z])", '$1 $2')
    $expanded = [Regex]::Replace($expanded, "[^A-Za-z0-9]+", " ").ToLowerInvariant()

    return @(
        $expanded -split "\s+" |
            Where-Object {
                $_.Length -gt 1 -and
                -not ($StopWords -contains $_)
            } |
            ForEach-Object {
                $_
                if ($_.EndsWith("s") -and $_.Length -gt 3) {
                    $_.Substring(0, $_.Length - 1)
                }
            } |
            Sort-Object -Unique
    )
}

function ConvertTo-ReferenceKey {
    param(
        [string]$Text
    )

    $keywords = @(ConvertTo-ReferenceKeywords -Text $Text)
    return ($keywords -join "")
}

function Get-FrontMatter {
    param(
        [string]$Text
    )

    $metadata = @{}
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $metadata
    }

    $match = [Regex]::Match($Text, "(?s)^---\r?\n(.*?)\r?\n---")
    if (-not $match.Success) {
        return $metadata
    }

    foreach ($line in ($match.Groups[1].Value -split "\r?\n")) {
        $parts = $line -split ":", 2
        if ($parts.Count -eq 2) {
            $key = $parts[0].Trim().ToLowerInvariant()
            $value = $parts[1].Trim()
            if ($key) {
                $metadata[$key] = $value
            }
        }
    }

    return $metadata
}

function Get-FirstMarkdownHeading {
    param(
        [string]$Text
    )

    $match = [Regex]::Match($Text, "(?m)^#\s+(.+)$")
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }

    return ""
}

function Split-ReferenceMetadataList {
    param(
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }

    return @(
        $Text -split "," |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ }
    )
}

function Get-MatchingReferences {
    param(
        [System.IO.FileInfo]$Skill,
        [string]$SkillText,
        [string]$SearchDir
    )

    if (-not (Test-Path -LiteralPath $SearchDir)) {
        return @()
    }

    $skillHeading = Get-FirstMarkdownHeading -Text $SkillText
    $skillKeywords = @(
        ConvertTo-ReferenceKeywords -Text $Skill.BaseName
        ConvertTo-ReferenceKeywords -Text $skillHeading
        ConvertTo-ReferenceKeywords -Text $SkillText
    ) | Sort-Object -Unique
    $skillKeys = @(
        ConvertTo-ReferenceKey -Text $Skill.BaseName
        ConvertTo-ReferenceKey -Text $skillHeading
    ) | Where-Object { $_ }

    $references = @(
        Get-ChildItem -LiteralPath $SearchDir -Recurse -File |
            Where-Object {
                -not $_.Name.StartsWith(".") -and
                $ReferenceExtensions -contains $_.Extension.ToLowerInvariant()
            } |
            Sort-Object FullName
    )

    $matches = @()
    foreach ($reference in $references) {
        $referenceText = Get-Content -LiteralPath $reference.FullName -Raw -Encoding UTF8
        $metadata = Get-FrontMatter -Text $referenceText
        $referenceHeading = Get-FirstMarkdownHeading -Text $referenceText
        $relativeReference = Get-ProjectRelativePath -Path $reference.FullName

        $appliesTo = ""
        if ($metadata.ContainsKey("applies_to")) {
            $appliesTo = $metadata["applies_to"]
        }

        $topicText = ""
        if ($metadata.ContainsKey("topics")) {
            $topicText = $metadata["topics"]
        }

        $referenceKeywords = @(
            ConvertTo-ReferenceKeywords -Text $reference.BaseName
            ConvertTo-ReferenceKeywords -Text $relativeReference
            ConvertTo-ReferenceKeywords -Text $referenceHeading
            ConvertTo-ReferenceKeywords -Text $topicText
            ConvertTo-ReferenceKeywords -Text $appliesTo
        ) | Sort-Object -Unique

        $appliesToKeys = @(
            Split-ReferenceMetadataList -Text $appliesTo |
                ForEach-Object { ConvertTo-ReferenceKey -Text $_ }
        )

        $referenceKeys = @(
            ConvertTo-ReferenceKey -Text $reference.BaseName
            ConvertTo-ReferenceKey -Text $referenceHeading
            $appliesToKeys
        ) | Where-Object { $_ }

        $explicitMatch = $false
        foreach ($skillKey in $skillKeys) {
            if ($referenceKeys -contains $skillKey) {
                $explicitMatch = $true
                break
            }
        }

        $overlap = @($referenceKeywords | Where-Object { $skillKeywords -contains $_ })
        if ($explicitMatch -or $overlap.Count -gt 0) {
            $matches += [PSCustomObject]@{
                File = $reference
                RelativePath = $relativeReference
                Text = $referenceText
            }
        }
    }

    return $matches
}

function Get-MatchingTemplates {
    param(
        [System.IO.FileInfo]$Skill,
        [string]$SkillText,
        [string]$SearchDir,
        [System.IO.FileInfo]$Source,
        [string]$SourceText
    )

    if (-not (Test-Path -LiteralPath $SearchDir)) {
        return @()
    }

    $skillHeading = Get-FirstMarkdownHeading -Text $SkillText
    $skillKeywords = @(
        ConvertTo-ReferenceKeywords -Text $Skill.BaseName
        ConvertTo-ReferenceKeywords -Text $skillHeading
        ConvertTo-ReferenceKeywords -Text $SkillText
    ) | Sort-Object -Unique
    $skillKeys = @(
        ConvertTo-ReferenceKey -Text $Skill.BaseName
        ConvertTo-ReferenceKey -Text $skillHeading
    ) | Where-Object { $_ }

    $sourceKeywords = @(
        ConvertTo-ReferenceKeywords -Text $Source.BaseName
        ConvertTo-ReferenceKeywords -Text $Source.Name
        ConvertTo-ReferenceKeywords -Text $SourceText
    ) | Sort-Object -Unique
    $sourceKeys = @(
        ConvertTo-ReferenceKey -Text $Source.BaseName
        ConvertTo-ReferenceKey -Text $Source.Name
    ) | Where-Object { $_ }

    $templates = @(
        Get-ChildItem -LiteralPath $SearchDir -Recurse -File |
            Where-Object {
                -not $_.Name.StartsWith(".") -and
                $_.Name -ne "README.md" -and
                $ReferenceExtensions -contains $_.Extension.ToLowerInvariant()
            } |
            Sort-Object FullName
    )

    $scoredMatches = @()
    foreach ($template in $templates) {
        $templateText = Get-Content -LiteralPath $template.FullName -Raw -Encoding UTF8
        $metadata = Get-FrontMatter -Text $templateText
        $templateHeading = Get-FirstMarkdownHeading -Text $templateText
        $relativeTemplate = Get-ProjectRelativePath -Path $template.FullName

        $appliesTo = ""
        if ($metadata.ContainsKey("applies_to")) {
            $appliesTo = $metadata["applies_to"]
        }

        $topicText = ""
        if ($metadata.ContainsKey("topics")) {
            $topicText = $metadata["topics"]
        }

        $templateKeywords = @(
            ConvertTo-ReferenceKeywords -Text $template.BaseName
            ConvertTo-ReferenceKeywords -Text $relativeTemplate
            ConvertTo-ReferenceKeywords -Text $templateHeading
            ConvertTo-ReferenceKeywords -Text $topicText
            ConvertTo-ReferenceKeywords -Text $appliesTo
        ) | Sort-Object -Unique

        $appliesToKeys = @(
            Split-ReferenceMetadataList -Text $appliesTo |
                ForEach-Object { ConvertTo-ReferenceKey -Text $_ }
        )

        $templateKeys = @(
            ConvertTo-ReferenceKey -Text $template.BaseName
            ConvertTo-ReferenceKey -Text $templateHeading
            $appliesToKeys
        ) | Where-Object { $_ }

        $sourceOverlap = @($templateKeywords | Where-Object { $sourceKeywords -contains $_ })
        $skillOverlap = @($templateKeywords | Where-Object { $skillKeywords -contains $_ })
        $explicitSourceMatch = $false
        foreach ($sourceKey in $sourceKeys) {
            if ($templateKeys -contains $sourceKey) {
                $explicitSourceMatch = $true
                break
            }
        }

        $explicitSkillMatch = $false
        foreach ($skillKey in $skillKeys) {
            if ($templateKeys -contains $skillKey) {
                $explicitSkillMatch = $true
                break
            }
        }

        $score = ($sourceOverlap.Count * 10) + ($skillOverlap.Count * 2)
        if ($explicitSourceMatch) {
            $score += 50
        }
        if ($explicitSkillMatch) {
            $score += 10
        }

        if ($score -gt 0) {
            $scoredMatches += [PSCustomObject]@{
                File = $template
                RelativePath = $relativeTemplate
                Text = $templateText
                Score = $score
                SourceMatch = ($explicitSourceMatch -or $sourceOverlap.Count -gt 0)
            }
        }
    }

    $sourceMatches = @($scoredMatches | Where-Object { $_.SourceMatch })
    if ($sourceMatches.Count -gt 0) {
        return @($sourceMatches | Sort-Object @{ Expression = "Score"; Descending = $true }, RelativePath | Select-Object -First 3)
    }

    return @($scoredMatches | Sort-Object @{ Expression = "Score"; Descending = $true }, RelativePath | Select-Object -First 3)
}

function Format-ReferenceContext {
    param(
        [array]$References,
        [string]$Label = "Reference file"
    )

    if ($References.Count -eq 0) {
        return "No matching files were found."
    }

    $blocks = @()
    foreach ($reference in $References) {
        $blocks += @(
            "${Label}: $($reference.RelativePath)"
            '```markdown'
            $reference.Text
            '```'
        ) -join [Environment]::NewLine
    }

    return ($blocks -join ([Environment]::NewLine * 2))
}

function Get-AlwaysOnFiles {
    param(
        [string]$SearchDir
    )

    if (-not (Test-Path -LiteralPath $SearchDir)) {
        return @()
    }

    return @(
        Get-ChildItem -LiteralPath $SearchDir -Recurse -File |
            Where-Object {
                -not $_.Name.StartsWith(".") -and
                $_.Name -ne "README.md" -and
                $AlwaysOnExtensions -contains $_.Extension.ToLowerInvariant()
            } |
            Sort-Object FullName |
            ForEach-Object {
                [PSCustomObject]@{
                    File = $_
                    RelativePath = Get-ProjectRelativePath -Path $_.FullName
                    Text = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
                }
            }
    )
}

function Format-AlwaysOnContext {
    param(
        [array]$Files,
        [string]$Label
    )

    if ($Files.Count -eq 0) {
        return "No $Label files were found."
    }

    $blocks = @()
    foreach ($file in $Files) {
        $blocks += @(
            "${Label}: $($file.RelativePath)"
            '```markdown'
            $file.Text
            '```'
        ) -join [Environment]::NewLine
    }

    return ($blocks -join ([Environment]::NewLine * 2))
}

function Select-Skill {
    $skills = @(Get-ChildItem -LiteralPath $SkillsDir -Filter "*.md" -File | Sort-Object Name)
    if ($skills.Count -eq 0) {
        throw "No .md skill files found in '$SkillsDir'. Add a Markdown skill file, then run again."
    }

    Write-Host ""
    Write-Host "Available skills:"
    for ($i = 0; $i -lt $skills.Count; $i++) {
        Write-Host ("  {0}. {1}" -f ($i + 1), $skills[$i].BaseName)
    }

    do {
        $choice = Read-Host "Select a skill number"
        $parsed = 0
        $valid = [int]::TryParse($choice, [ref]$parsed) -and $parsed -ge 1 -and $parsed -le $skills.Count
        if (-not $valid) {
            Write-Host "Enter a number from 1 to $($skills.Count)."
        }
    } until ($valid)

    return $skills[$parsed - 1].FullName
}

function Test-CodexCli {
    $command = Get-Command codex -ErrorAction SilentlyContinue
    return $null -ne $command
}

function Read-RequiredInput {
    param(
        [string]$Prompt
    )

    do {
        $value = Read-Host $Prompt
        if ([string]::IsNullOrWhiteSpace($value)) {
            Write-Host "Please enter a value."
        }
    } until (-not [string]::IsNullOrWhiteSpace($value))

    return $value.Trim()
}

function ConvertTo-SafeSkillFileName {
    param(
        [string]$Name
    )

    $safeName = [Regex]::Replace($Name.Trim(), "[^A-Za-z0-9]+", "")
    if ([string]::IsNullOrWhiteSpace($safeName)) {
        $safeName = "NewSkill"
    }

    if (-not $safeName.EndsWith("Skill", [System.StringComparison]::OrdinalIgnoreCase) -and
        -not $safeName.EndsWith("Gen", [System.StringComparison]::OrdinalIgnoreCase)) {
        $safeName = "${safeName}Skill"
    }

    return $safeName
}

function New-SkillFile {
    Write-Host ""
    Write-Host "Create New Skill"
    Write-Host "Answer the prompts below. The harness will create a new .md file in 3 skills/."
    Write-Host ""

    $displayName = Read-RequiredInput -Prompt "New skill name"
    $goal = Read-RequiredInput -Prompt "What should this skill help create or transform?"
    $audience = Read-RequiredInput -Prompt "Who is the intended audience or user?"
    $inputExpectation = Read-RequiredInput -Prompt "What source/input should this skill expect?"
    $outputStructure = Read-RequiredInput -Prompt "What output structure or sections should it produce?"
    $hardRules = Read-RequiredInput -Prompt "What hard rules should it always follow?"
    $validationChecks = Read-RequiredInput -Prompt "What validation checks or acceptance criteria should it use?"
    $topics = Read-RequiredInput -Prompt "Keywords/topics for matching references and templates"

    $safeName = ConvertTo-SafeSkillFileName -Name $displayName
    $targetPath = Join-Path $SkillsDir "$safeName.md"
    if (Test-Path -LiteralPath $targetPath) {
        $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $targetPath = Join-Path $SkillsDir "$safeName-$stamp.md"
    }

    $content = @(
        "---"
        "topics: $topics"
        "applies_to: $safeName"
        "---"
        ""
        "# $safeName"
        ""
        "## Purpose"
        ""
        $goal
        ""
        "## Intended Audience"
        ""
        $audience
        ""
        "## Expected Input"
        ""
        $inputExpectation
        ""
        "## Output Structure"
        ""
        $outputStructure
        ""
        "## Hard Rules"
        ""
        $hardRules
        ""
        "## Validation Checks"
        ""
        $validationChecks
        ""
        "## Reference and Template Matching"
        ""
        "Use matching reference and template files related to: $topics"
        ""
        "## Final Response Requirement"
        ""
        "Return only the completed Markdown document. Do not wrap the final answer in code fences. Do not describe the process unless the requested output explicitly asks for process notes."
    ) -join [Environment]::NewLine

    Set-Content -LiteralPath $targetPath -Value $content -Encoding UTF8
    Write-Log "Created new skill: $(Get-ProjectRelativePath -Path $targetPath)"
    Write-Host ""
    Write-Host "Created skill:"
    Write-Host (Get-ProjectRelativePath -Path $targetPath)
}

function Write-SelectedContextLog {
    param(
        [System.IO.FileInfo]$Skill,
        [string]$SkillText,
        [array]$Sources = @()
    )

    $hardRules = @(Get-AlwaysOnFiles -SearchDir $HardRulesDir)
    $validationChecks = @(Get-AlwaysOnFiles -SearchDir $ValidationChecksDir)
    $matchingReferences = @(Get-MatchingReferences -Skill $Skill -SkillText $SkillText -SearchDir $ReferenceDir)

    Write-Log "Hard rule files loaded: $($hardRules.Count)"
    foreach ($rule in $hardRules) {
        Write-Log "Included hard rule: $($rule.RelativePath)"
    }

    Write-Log "Validation check files loaded: $($validationChecks.Count)"
    foreach ($check in $validationChecks) {
        Write-Log "Included validation check: $($check.RelativePath)"
    }

    if ($matchingReferences.Count -eq 0) {
        Write-Log "No matching reference files found for skill: $($Skill.BaseName)"
    }
    else {
        foreach ($reference in $matchingReferences) {
            Write-Log "Included reference for $($Skill.BaseName): $($reference.RelativePath)"
        }
    }

    if ($Sources.Count -eq 0) {
        Write-Log "No pending source files available for source-specific template matching."
    }
    else {
        foreach ($source in $Sources) {
            $sourceText = Get-Content -LiteralPath $source.FullName -Raw -Encoding UTF8
            $matchingTemplates = @(Get-MatchingTemplates -Skill $Skill -SkillText $SkillText -SearchDir $TemplateDir -Source $source -SourceText $sourceText)
            if ($matchingTemplates.Count -eq 0) {
                Write-Log "No matching template files found for source: $($source.Name)"
            }
            else {
                foreach ($template in $matchingTemplates) {
                    Write-Log "Included template for $($source.Name): $($template.RelativePath)"
                }
            }
        }
    }
}

function Invoke-CodexTransform {
    param(
        [System.IO.FileInfo]$Source,
        [string]$SelectedSkill,
        [string]$OutputPath
    )

    $skillText = Get-Content -LiteralPath $SelectedSkill -Raw -Encoding UTF8
    $skillItem = Get-Item -LiteralPath $SelectedSkill
    $hardRules = @(Get-AlwaysOnFiles -SearchDir $HardRulesDir)
    $validationChecks = @(Get-AlwaysOnFiles -SearchDir $ValidationChecksDir)
    $matchingReferences = @(Get-MatchingReferences -Skill $skillItem -SkillText $skillText -SearchDir $ReferenceDir)
    $sourceText = Get-Content -LiteralPath $Source.FullName -Raw -Encoding UTF8
    $relativeSource = Get-ProjectRelativePath -Path $Source.FullName
    $relativeOutput = Get-ProjectRelativePath -Path $OutputPath
    $matchingTemplates = @(Get-MatchingTemplates -Skill $skillItem -SkillText $skillText -SearchDir $TemplateDir -Source $Source -SourceText $sourceText)
    foreach ($rule in $hardRules) {
        Write-Log "Included hard rule: $($rule.RelativePath)"
    }
    foreach ($check in $validationChecks) {
        Write-Log "Included validation check: $($check.RelativePath)"
    }
    if ($matchingReferences.Count -eq 0) {
        Write-Log "No matching reference files found for skill: $($skillItem.BaseName)"
    }
    else {
        foreach ($reference in $matchingReferences) {
            Write-Log "Included reference for $($skillItem.BaseName): $($reference.RelativePath)"
        }
    }
    if ($matchingTemplates.Count -eq 0) {
        Write-Log "No matching template files found for source: $($Source.Name)"
    }
    else {
        foreach ($template in $matchingTemplates) {
            Write-Log "Included template for $($Source.Name): $($template.RelativePath)"
        }
    }
    $hardRulesContext = Format-AlwaysOnContext -Files $hardRules -Label "Hard rule file"
    $validationChecksContext = Format-AlwaysOnContext -Files $validationChecks -Label "Validation check file"
    $referenceContext = Format-ReferenceContext -References $matchingReferences -Label "Reference file"
    $templateContext = Format-ReferenceContext -References $matchingTemplates -Label "Template file"

    $prompt = @(
        "You are running a local document workflow."
        ""
        "Apply the selected skill to the source file content below."
        "The template context, when present, is the gold-standard baseline for the output structure."
        "Follow the matched template headings, section order, and required fields unless the selected skill or hard rules require a stricter format."
        "Use the source content to fill the template. Do not invent unsupported business facts; place unknowns in an appropriate open questions or assumptions section."
        ""
        "Return only the final Markdown document. Do not wrap it in code fences. Do not describe the process."
        ""
        "Selected skill file:"
        $SelectedSkill
        ""
        "Selected skill instructions:"
        $skillText
        ""
        "Hard rules:"
        "Follow these instructions unless they directly conflict with system or developer instructions."
        $hardRulesContext
        ""
        "Validation checks:"
        "Before writing the final Markdown document, internally validate the output against these checks."
        $validationChecksContext
        ""
        "Reference context:"
        $referenceContext
        ""
        "Template context:"
        $templateContext
        ""
        "Source file:"
        $relativeSource
        ""
        "Destination file:"
        $relativeOutput
        ""
        "Source content:"
        '```text'
        $sourceText
        '```'
    ) -join [Environment]::NewLine

    $codexArgs = @(
        "exec",
        "--skip-git-repo-check",
        "--ephemeral",
        "--color", "never",
        "-C", $ProjectRoot,
        "-o", $OutputPath,
        "-"
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $codexConsoleOutput = $prompt | & codex @codexArgs 2>&1
        $codexExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($codexExitCode -ne 0 -and $codexConsoleOutput) {
        Add-Content -LiteralPath $script:LogPath -Value "Codex console output:" -Encoding UTF8
        $codexConsoleOutput | Add-Content -LiteralPath $script:LogPath -Encoding UTF8
    }

    return $codexExitCode
}

New-Item -ItemType Directory -Force -Path $DoneDir, $OutboundDir, $LogDir | Out-Null
$script:LogPath = Join-Path $LogDir ("run-{0}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss"))

try {
    if (-not (Test-Path -LiteralPath $InboundDir)) {
        throw "Inbound folder not found: $InboundDir"
    }
    if (-not (Test-Path -LiteralPath $SkillsDir)) {
        throw "Skills folder not found: $SkillsDir"
    }

    if ([string]::IsNullOrWhiteSpace($SkillPath)) {
        $SkillPath = Select-Skill
    }

    $skillItem = Get-Item -LiteralPath $SkillPath
    if ($skillItem.Extension -ne ".md") {
        throw "Skill must be a .md file: $SkillPath"
    }

    if ($skillItem.BaseName -eq "CreateSkill") {
        Write-Log "Selected utility skill: $($skillItem.FullName)"
        New-SkillFile
        exit 0
    }

    $pendingFiles = @(
        Get-ChildItem -LiteralPath $InboundDir -File |
            Where-Object {
                -not $_.Name.StartsWith(".") -and
                $_.Name -ne "README.md" -and
                $SupportedExtensions -contains $_.Extension.ToLowerInvariant()
            } |
            Sort-Object Name
    )

    Write-Log "Selected skill: $($skillItem.FullName)"
    Write-Log "Inbound folder: $InboundDir"
    Write-Log "Output folder: $OutboundDir"

    if ($pendingFiles.Count -eq 0) {
        Write-Log "No pending supported files found."
        if (-not $DryRun) {
            exit 0
        }
    }

    $successCount = 0
    $failureCount = 0
    $skippedFiles = @(
        Get-ChildItem -LiteralPath $InboundDir -File |
            Where-Object {
                -not $_.Name.StartsWith(".") -and
                $_.Name -ne "README.md" -and
                -not ($SupportedExtensions -contains $_.Extension.ToLowerInvariant())
            } |
            Sort-Object Name
    )

    foreach ($skipped in $skippedFiles) {
        Write-Log "Skipping unsupported file type: $($skipped.Name)" "WARN"
    }

    if ($DryRun) {
        $skillText = Get-Content -LiteralPath $skillItem.FullName -Raw -Encoding UTF8
        Write-SelectedContextLog -Skill $skillItem -SkillText $skillText -Sources $pendingFiles
        Write-Log "Dry run enabled. Codex CLI is not required, no files will be generated, and inbound files will not be moved."
        Write-Log "Pending supported files: $($pendingFiles.Count)"
        foreach ($file in $pendingFiles) {
            $previewOutputPath = Get-SafeOutputPath -SourceFile $file.Name
            Write-Log "Would process: $($file.Name) -> $([System.IO.Path]::GetFileName($previewOutputPath))"
        }
        Write-Log "Dry run complete."
        exit 0
    }

    if (-not (Test-CodexCli)) {
        throw "Codex CLI was not found. Install and authenticate Codex CLI to generate output, or run 'Run Skill.bat -DryRun' to validate the workflow without Codex."
    }

    foreach ($file in $pendingFiles) {
        $outputPath = Get-SafeOutputPath -SourceFile $file.Name
        Write-Log "Processing: $($file.Name)"

        try {
            $exitCode = Invoke-CodexTransform -Source $file -SelectedSkill $skillItem.FullName -OutputPath $outputPath
            if ($exitCode -ne 0) {
                throw "Codex exited with code $exitCode"
            }
            if (-not (Test-Path -LiteralPath $outputPath)) {
                throw "Expected output was not created: $outputPath"
            }

            $donePath = Join-Path $DoneDir $file.Name
            if (Test-Path -LiteralPath $donePath) {
                $doneStem = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                $doneExt = [System.IO.Path]::GetExtension($file.Name)
                $doneStamp = Get-Date -Format "yyyyMMdd-HHmmss"
                $donePath = Join-Path $DoneDir "$doneStem-$doneStamp$doneExt"
            }

            Move-Item -LiteralPath $file.FullName -Destination $donePath
            Write-Log "Success: $($file.Name) -> $([System.IO.Path]::GetFileName($outputPath))"
            $successCount++
        }
        catch {
            Write-Log "Failed: $($file.Name): $($_.Exception.Message)" "ERROR"
            if (Test-Path -LiteralPath $outputPath) {
                Remove-Item -LiteralPath $outputPath -Force
            }
            $failureCount++
        }
    }

    Write-Log "Run complete. Successes: $successCount. Failures: $failureCount."
    if ($failureCount -gt 0) {
        exit 1
    }
    exit 0
}
catch {
    Write-Log $_.Exception.Message "ERROR"
    exit 1
}
