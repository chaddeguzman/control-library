param(
    [string]$SkillPath,
    [ValidateSet("md", "doc")]
    [string]$OutputFormat,
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
$TemplateExtensions = @(".md", ".markdown", ".doc")
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

function Write-StepLog {
    param(
        [string]$Step,
        [string]$Message
    )

    Write-Log "$Step - $Message"
}

function Get-SafeOutputPath {
    param(
        [string]$SourceFile,
        [string]$OutputExtension = ".md"
    )

    $stem = [System.IO.Path]::GetFileNameWithoutExtension($SourceFile)
    if (-not $OutputExtension.StartsWith(".")) {
        $OutputExtension = ".$OutputExtension"
    }
    $invalidPattern = "[{0}]" -f [Regex]::Escape((-join [System.IO.Path]::GetInvalidFileNameChars()))
    $stem = [Regex]::Replace($stem, $invalidPattern, "_")

    if ([string]::IsNullOrWhiteSpace($stem)) {
        $stem = "output"
    }

    $candidate = Join-Path $OutboundDir "$stem$OutputExtension"
    if (-not (Test-Path -LiteralPath $candidate)) {
        return $candidate
    }

    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    return (Join-Path $OutboundDir "$stem-$stamp$OutputExtension")
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
        [string]$SourceText,
        [string]$OutputFormat = "md"
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

    $allowedTemplateExtensions = @(".md", ".markdown")
    if ($OutputFormat -eq "doc") {
        $allowedTemplateExtensions = @(".doc")
    }

    $templates = @(
        Get-ChildItem -LiteralPath $SearchDir -Recurse -File |
            Where-Object {
                -not $_.Name.StartsWith(".") -and
                $_.Name -ne "README.md" -and
                $TemplateExtensions -contains $_.Extension.ToLowerInvariant() -and
                $allowedTemplateExtensions -contains $_.Extension.ToLowerInvariant()
            } |
            Sort-Object FullName
    )

    $scoredMatches = @()
    foreach ($template in $templates) {
        $isBinaryTemplate = $template.Extension.ToLowerInvariant() -eq ".doc"
        if ($isBinaryTemplate) {
            $templateText = @(
                "Binary Word template selected. Use this file as the baseline document format: $(Get-ProjectRelativePath -Path $template.FullName)"
                ""
                "The binary .doc file cannot be read as plain text by this harness."
                "The required document structure, headings, tables, labels, and placeholders must therefore be taken from the companion Markdown template below when it exists."
            ) -join [Environment]::NewLine

            $companionMarkdownPath = Join-Path $template.DirectoryName "$($template.BaseName).md"
            if (Test-Path -LiteralPath $companionMarkdownPath) {
                $companionText = Get-Content -LiteralPath $companionMarkdownPath -Raw -Encoding UTF8
                $templateText = @(
                    $templateText
                    ""
                    "Companion structural template: $(Get-ProjectRelativePath -Path $companionMarkdownPath)"
                    '```markdown'
                    $companionText
                    '```'
                ) -join [Environment]::NewLine
            }
        }
        else {
            $templateText = Get-Content -LiteralPath $template.FullName -Raw -Encoding UTF8
        }
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

function Select-OutputFormat {
    param(
        [System.IO.FileInfo]$Skill
    )

    if ($Skill.BaseName -ne "TechSpecGen") {
        return "md"
    }

    Write-Host ""
    Write-Host "Available output formats for TechSpecGen:"
    Write-Host "  1. Markdown (.md)"
    Write-Host "  2. Word document (.doc)"

    do {
        $choice = Read-Host "Select an output format number"
        $parsed = 0
        $valid = [int]::TryParse($choice, [ref]$parsed) -and $parsed -ge 1 -and $parsed -le 2
        if (-not $valid) {
            Write-Host "Enter 1 for Markdown or 2 for Word document."
        }
    } until ($valid)

    if ($parsed -eq 2) {
        return "doc"
    }

    return "md"
}

function Get-OutputExtension {
    param(
        [string]$Format
    )

    if ($Format -eq "doc") {
        return ".doc"
    }

    return ".md"
}

function Confirm-CreateOutput {
    param(
        [string]$SourceName,
        [string]$OutputPath
    )

    $relativeOutput = Get-ProjectRelativePath -Path $OutputPath
    do {
        $answer = Read-Host "Validation passed for '$SourceName'. Would you like to create the document output now at '$relativeOutput'? (Y/N)"
        $normalized = $answer.Trim().ToLowerInvariant()
        if ($normalized -in @("y", "yes")) {
            return $true
        }
        if ($normalized -in @("n", "no")) {
            return $false
        }
        Write-Host "Enter Y for yes or N for no."
    } until ($false)
}

function ConvertTo-RtfText {
    param(
        [string]$Text
    )

    $escaped = $Text.Replace("\", "\\").Replace("{", "\{").Replace("}", "\}")
    $escaped = $escaped -replace "`r`n|`n|`r", "\par`r`n"

    return "{\rtf1\ansi`r`n$escaped`r`n}"
}

function Invoke-CodexExecWithProgress {
    param(
        [string]$Prompt,
        [array]$CodexArgs,
        [string]$Activity = "Generating output file"
    )

    $job = Start-Job -ScriptBlock {
        param(
            [string]$PromptText,
            [object[]]$ArgsList
        )

        $commandOutput = $PromptText | & codex @ArgsList 2>&1
        [PSCustomObject]@{
            ExitCode = $LASTEXITCODE
            Output = ($commandOutput | Out-String)
        }
    } -ArgumentList $Prompt, $CodexArgs

    $percent = 5
    while ($job.State -eq "Running") {
        if ($percent -lt 95) {
            $percent = [Math]::Min(95, $percent + 3)
        }

        Write-Progress -Activity $Activity -Status "Codex is generating the output... $percent%" -PercentComplete $percent
        Start-Sleep -Milliseconds 800
    }

    Write-Progress -Activity $Activity -Status "Finalizing output file... 100%" -PercentComplete 100
    $result = Receive-Job -Job $job
    Remove-Job -Job $job -Force
    Write-Progress -Activity $Activity -Completed

    return $result
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
        [array]$Sources = @(),
        [string]$OutputFormat = "md",
        [string]$OutputExtension = ".md"
    )

    $hardRules = @(Get-AlwaysOnFiles -SearchDir $HardRulesDir)
    $validationChecks = @(Get-AlwaysOnFiles -SearchDir $ValidationChecksDir)
    $matchingReferences = @(Get-MatchingReferences -Skill $Skill -SkillText $SkillText -SearchDir $ReferenceDir)

    Write-StepLog "Step 1" "Harness loaded selected skill: $($Skill.Name)"
    Write-StepLog "Step 2" "Hard rules loaded: $($hardRules.Count)"
    foreach ($rule in $hardRules) {
        Write-StepLog "Step 2" "Hard rule used: $($rule.RelativePath)"
    }

    Write-StepLog "Step 3" "Validation checks loaded: $($validationChecks.Count)"
    foreach ($check in $validationChecks) {
        Write-StepLog "Step 3" "Validation check used: $($check.RelativePath)"
    }

    if ($matchingReferences.Count -eq 0) {
        Write-StepLog "Step 4" "No matching reference files found for skill: $($Skill.BaseName)"
    }
    else {
        foreach ($reference in $matchingReferences) {
            Write-StepLog "Step 4" "Reference used for $($Skill.BaseName): $($reference.RelativePath)"
        }
    }

    foreach ($source in $Sources) {
        $sourceText = Get-Content -LiteralPath $source.FullName -Raw -Encoding UTF8
        $matchingTemplates = @(Get-MatchingTemplates -Skill $Skill -SkillText $SkillText -SearchDir $TemplateDir -Source $source -SourceText $sourceText -OutputFormat $OutputFormat)
        if ($matchingTemplates.Count -eq 0) {
            Write-StepLog "Step 5" "No matching template files found for source: $($source.Name)"
        }
        else {
            foreach ($template in $matchingTemplates) {
                Write-StepLog "Step 5" "Template used for $($source.Name): $($template.RelativePath)"
            }
        }
        $previewOutputPath = Get-SafeOutputPath -SourceFile $source.Name -OutputExtension $OutputExtension
        Write-StepLog "Step 6" "Output destination: $(Get-ProjectRelativePath -Path $previewOutputPath)"
    }
}

function Invoke-CodexTransform {
    param(
        [System.IO.FileInfo]$Source,
        [string]$SelectedSkill,
        [string]$OutputPath,
        [string]$OutputFormat = "md"
    )

    $skillText = Get-Content -LiteralPath $SelectedSkill -Raw -Encoding UTF8
    $skillItem = Get-Item -LiteralPath $SelectedSkill
    $hardRules = @(Get-AlwaysOnFiles -SearchDir $HardRulesDir)
    $validationChecks = @(Get-AlwaysOnFiles -SearchDir $ValidationChecksDir)
    $matchingReferences = @(Get-MatchingReferences -Skill $skillItem -SkillText $skillText -SearchDir $ReferenceDir)
    $sourceText = Get-Content -LiteralPath $Source.FullName -Raw -Encoding UTF8
    $relativeSource = Get-ProjectRelativePath -Path $Source.FullName
    $relativeOutput = Get-ProjectRelativePath -Path $OutputPath
    $matchingTemplates = @(Get-MatchingTemplates -Skill $skillItem -SkillText $skillText -SearchDir $TemplateDir -Source $Source -SourceText $sourceText -OutputFormat $OutputFormat)
    Write-StepLog "Step 1" "Harness loaded selected skill: $($skillItem.Name)"
    foreach ($rule in $hardRules) {
        Write-StepLog "Step 2" "Hard rule used: $($rule.RelativePath)"
    }
    if ($hardRules.Count -eq 0) {
        Write-StepLog "Step 2" "Hard rules loaded: 0"
    }
    foreach ($check in $validationChecks) {
        Write-StepLog "Step 3" "Validation check used: $($check.RelativePath)"
    }
    if ($validationChecks.Count -eq 0) {
        Write-StepLog "Step 3" "Validation checks loaded: 0"
    }
    if ($matchingReferences.Count -eq 0) {
        Write-StepLog "Step 4" "No matching reference files found for skill: $($skillItem.BaseName)"
    }
    else {
        foreach ($reference in $matchingReferences) {
            Write-StepLog "Step 4" "Reference used for $($skillItem.BaseName): $($reference.RelativePath)"
        }
    }
    if ($matchingTemplates.Count -eq 0) {
        Write-StepLog "Step 5" "No matching template files found for source: $($Source.Name)"
    }
    else {
        foreach ($template in $matchingTemplates) {
            Write-StepLog "Step 5" "Template used for $($Source.Name): $($template.RelativePath)"
        }
    }
    Write-StepLog "Step 6" "Output destination: $relativeOutput"
    $hardRulesContext = Format-AlwaysOnContext -Files $hardRules -Label "Hard rule file"
    $validationChecksContext = Format-AlwaysOnContext -Files $validationChecks -Label "Validation check file"
    $referenceContext = Format-ReferenceContext -References $matchingReferences -Label "Reference file"
    $templateContext = Format-ReferenceContext -References $matchingTemplates -Label "Template file"

    $formatInstruction = "Return only the final Markdown document. Do not wrap it in code fences. Do not describe the process."
    $validationInstruction = "Before writing the final Markdown document, internally validate the output against these checks."
    if ($OutputFormat -eq "doc") {
        $formatInstruction = "Return only valid Rich Text Format content for a Word-compatible .doc file. Start the response with {\rtf1. Do not wrap it in code fences. Do not describe the process."
        $validationInstruction = "Before writing the final DOC-compatible content, internally validate the output against these checks."
    }

    $prompt = @(
        "You are running a local document workflow."
        ""
        "Apply the selected skill to the source file content below."
        "NON-NEGOTIABLE TEMPLATE RULES:"
        "1. If template context is present, it is mandatory and must be followed without fail."
        "2. Preserve the matched template design, title pattern, heading hierarchy, section order, table structures, column names, field labels, placeholders, and required attributes."
        "3. Do not replace the template with your own structure. Do not use the selected skill's fallback structure when a template is present."
        "4. Use the source content only to fill the template. If a template field cannot be completed from the source, keep the field and mark it as TBD or use the template's placeholder guidance."
        "5. Do not invent unsupported business facts; place uncertainty in the closest matching template section."
        ""
        $formatInstruction
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
        $validationInstruction
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
        "--sandbox", "workspace-write",
        "-C", $ProjectRoot,
        "-o", $OutputPath,
        "-"
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        Write-Log "Generation started for $(Get-ProjectRelativePath -Path $OutputPath)"
        $codexResult = Invoke-CodexExecWithProgress -Prompt $prompt -CodexArgs $codexArgs -Activity "Generating $([System.IO.Path]::GetFileName($OutputPath))"
        $codexExitCode = $codexResult.ExitCode
        $codexConsoleOutput = $codexResult.Output
        Write-Log "Generation finished with exit code $codexExitCode"
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($codexExitCode -ne 0 -and $codexConsoleOutput) {
        Add-Content -LiteralPath $script:LogPath -Value "Codex console output:" -Encoding UTF8
        $codexConsoleOutput | Add-Content -LiteralPath $script:LogPath -Encoding UTF8
    }

    if ($codexExitCode -eq 0 -and -not (Test-Path -LiteralPath $OutputPath)) {
        $fallbackOutput = ($codexConsoleOutput | Out-String).Trim()
        if (-not [string]::IsNullOrWhiteSpace($fallbackOutput)) {
            if ($OutputFormat -eq "doc" -and -not $fallbackOutput.TrimStart().StartsWith("{\rtf1")) {
                $fallbackOutput = ConvertTo-RtfText -Text $fallbackOutput
            }

            Set-Content -LiteralPath $OutputPath -Value $fallbackOutput -Encoding UTF8
            Write-Log "Codex did not create the output file directly; wrote captured response to $(Get-ProjectRelativePath -Path $OutputPath)"
        }
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

    if ([string]::IsNullOrWhiteSpace($OutputFormat)) {
        $OutputFormat = Select-OutputFormat -Skill $skillItem
    }
    elseif ($skillItem.BaseName -ne "TechSpecGen" -and $OutputFormat -eq "doc") {
        Write-Log "DOC output is only available for TechSpecGen. Falling back to Markdown output." "WARN"
        $OutputFormat = "md"
    }

    $outputExtension = Get-OutputExtension -Format $OutputFormat

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
    Write-Log "Selected output format: $OutputFormat"
    Write-Log "Inbound folder: $InboundDir"
    Write-Log "Output folder: $OutboundDir"

    if ($pendingFiles.Count -eq 0) {
        Write-Log "No inbound file found. Put a supported source file in '1 inbound/' and run again."
        exit 0
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
        Write-SelectedContextLog -Skill $skillItem -SkillText $skillText -Sources $pendingFiles -OutputFormat $OutputFormat -OutputExtension $outputExtension
        Write-Log "Dry run enabled. Codex CLI is not required, no files will be generated, and inbound files will not be moved."
        Write-Log "Pending supported files: $($pendingFiles.Count)"
        foreach ($file in $pendingFiles) {
            $previewOutputPath = Get-SafeOutputPath -SourceFile $file.Name -OutputExtension $outputExtension
            Write-Log "Would process: $($file.Name) -> $([System.IO.Path]::GetFileName($previewOutputPath))"
        }
        Write-Log "Dry run complete."
        exit 0
    }

    if (-not (Test-CodexCli)) {
        throw "Codex CLI was not found. Install and authenticate Codex CLI to generate output, or run 'Run Skill.bat -DryRun' to validate the workflow without Codex."
    }

    foreach ($file in $pendingFiles) {
        $outputPath = Get-SafeOutputPath -SourceFile $file.Name -OutputExtension $outputExtension
        Write-Log "Inbound file found: $($file.Name)"
        Write-Log "Processing with output format: $OutputFormat"

        try {
            $skillText = Get-Content -LiteralPath $skillItem.FullName -Raw -Encoding UTF8
            Write-SelectedContextLog -Skill $skillItem -SkillText $skillText -Sources @($file) -OutputFormat $OutputFormat -OutputExtension $outputExtension
            Write-Log "Validation checks completed before generation."

            if (-not (Confirm-CreateOutput -SourceName $file.Name -OutputPath $outputPath)) {
                Write-Log "User chose not to create output for $($file.Name). Source file was left in place."
                continue
            }

            $exitCode = Invoke-CodexTransform -Source $file -SelectedSkill $skillItem.FullName -OutputPath $outputPath -OutputFormat $OutputFormat
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
