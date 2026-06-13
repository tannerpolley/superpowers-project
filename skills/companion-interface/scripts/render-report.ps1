[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path,
    [Parameter(Mandatory = $true)][string]$ReportRoot
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\companion-report.ps1")

function ConvertTo-HtmlText {
    param([AllowNull()][object]$Value)
    ConvertTo-CompanionHtmlText $Value
}

function ConvertTo-ManifestJsonForHtml {
    param([object]$Manifest)
    ($Manifest | ConvertTo-Json -Depth 20 -Compress).Replace("<", "\u003c")
}

function ConvertTo-EventDetailsHtml {
    param([object[]]$Events, [string]$RepoRoot, [string]$ReportRoot)
    if ($Events.Count -eq 0) { return '<p class="empty">No events recorded.</p>' }
    $parts = foreach ($event in $Events) {
        $payload = ConvertTo-HtmlText (($event.payload | ConvertTo-Json -Depth 12) -replace "(\r?\n)+$", "")
        $richHtml = ConvertTo-EventRichHtml -Event $event -RepoRoot $RepoRoot -ReportRoot $ReportRoot
        @"
<details>
  <summary>$(ConvertTo-HtmlText $event.title)</summary>
  <p class="event-type">$(ConvertTo-HtmlText $event.type) · $(ConvertTo-HtmlText $event.timestamp)</p>
  <p class="event-summary">$(ConvertTo-HtmlText $event.summary)</p>
  $richHtml
  <pre>$payload</pre>
</details>
"@
    }
    $parts -join "`n"
}

function ConvertTo-EventRichHtml {
    param([object]$Event, [string]$RepoRoot, [string]$ReportRoot)
    switch ([string]$Event.type) {
        "markdown_rendered" {
            $artifact = Resolve-CompanionArtifactFile -RepoRoot $RepoRoot -ArtifactPath ([string]$Event.artifact_path)
            return (Convert-CompanionMarkdownToHtml -MarkdownPath ([string]$artifact.full_path))
        }
        "table_added" {
            $artifact = Resolve-CompanionArtifactFile -RepoRoot $RepoRoot -ArtifactPath ([string]$Event.artifact_path)
            return (Convert-CompanionTableToHtml -TablePath ([string]$artifact.full_path))
        }
        "plot_added" {
            return (Convert-CompanionArtifactPathToHtml -RepoRoot $RepoRoot -ReportRoot $ReportRoot -ArtifactPath ([string]$Event.artifact_path) -Caption ([string]$Event.summary))
        }
        { $_ -in @("command_result", "validation_result", "test_result") } {
            return (Convert-CompanionValidationToHtml -Payload $Event.payload)
        }
        default {
            return ""
        }
    }
}

function ConvertTo-ArtifactHtml {
    param([object[]]$Events, [string]$RepoRoot, [string]$ReportRoot)
    $artifactEvents = @($Events | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.artifact_path) })
    if ($artifactEvents.Count -eq 0) { return '<p class="empty">No artifacts recorded yet.</p>' }
    $parts = foreach ($event in $artifactEvents) {
        $richHtml = ConvertTo-EventRichHtml -Event $event -RepoRoot $RepoRoot -ReportRoot $ReportRoot
        @"
<details>
  <summary>$(ConvertTo-HtmlText $event.title)</summary>
  <p class="event-type">$(ConvertTo-HtmlText $event.type)</p>
  <p><code>$(ConvertTo-HtmlText $event.artifact_path)</code></p>
  <p class="event-summary">$(ConvertTo-HtmlText $event.summary)</p>
  $richHtml
</details>
"@
    }
    $parts -join "`n"
}

function ConvertTo-SummaryHtml {
    param([object[]]$Events, [object]$Manifest)
    $summaryEvents = @($Events | Where-Object { $_.type -eq "summary_added" -or $_.type -eq "run_completed" })
    if ($summaryEvents.Count -eq 0) {
        return "<p>$(ConvertTo-HtmlText $Manifest.latest_summary)</p>"
    }
    $parts = foreach ($event in $summaryEvents) {
        "<p><strong>$(ConvertTo-HtmlText $event.title):</strong> $(ConvertTo-HtmlText $event.summary)</p>"
    }
    $parts -join "`n"
}

try {
    $root = Resolve-CompanionRepoRoot -RepoRoot $RepoRoot
    $relativeReportRoot = Assert-CompanionReportRoot -RepoRoot $root -ReportRoot $ReportRoot
    $resolvedReportRoot = [IO.Path]::GetFullPath((Join-Path $root $relativeReportRoot))
    $manifestPath = Join-Path $resolvedReportRoot "manifest.json"
    $eventsPath = Join-Path $resolvedReportRoot "events.jsonl"
    $indexPath = Join-Path $resolvedReportRoot "index.html"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "manifest.json is missing: $relativeReportRoot" }
    if (-not (Test-Path -LiteralPath $eventsPath -PathType Leaf)) { throw "events.jsonl is missing: $relativeReportRoot" }

    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $events = @(
        Get-Content -LiteralPath $eventsPath |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { $_ | ConvertFrom-Json }
    )
    $decisionEvents = @($events | Where-Object { $_.type -eq "decision_needed" -or $_.type -eq "decision_recorded" })
    $evidenceEvents = @($events | Where-Object { $_.type -ne "decision_needed" -and $_.type -ne "decision_recorded" })

    $overview = @"
<nav>
  <h2>Run Overview</h2>
  <div class="meta-grid">
    <div><div class="meta-label">Workflow</div><div class="meta-value">$(ConvertTo-HtmlText $manifest.workflow_name)</div></div>
    <div><div class="meta-label">Run ID</div><div class="meta-value">$(ConvertTo-HtmlText $manifest.run_id)</div></div>
    <div><div class="meta-label">Status</div><div class="meta-value">$(ConvertTo-HtmlText $manifest.status)</div></div>
    <div><div class="meta-label">Events</div><div class="meta-value">$(ConvertTo-HtmlText $events.Count)</div></div>
    <div><div class="meta-label">Report Root</div><div class="meta-value"><code>$(ConvertTo-HtmlText $relativeReportRoot)</code></div></div>
  </div>
</nav>
"@

    $body = @"
<div class="sidebar">
  $overview
  <section>
    <h2>Artifact Browser</h2>
    $(ConvertTo-ArtifactHtml -Events $events -RepoRoot $root -ReportRoot $resolvedReportRoot)
  </section>
</div>
<div class="content">
  <section>
    <h2>Workflow Timeline</h2>
    $(ConvertTo-EventDetailsHtml -Events $events -RepoRoot $root -ReportRoot $resolvedReportRoot)
  </section>
  <section>
    <h2>Evidence Feed</h2>
    $(ConvertTo-EventDetailsHtml -Events $evidenceEvents -RepoRoot $root -ReportRoot $resolvedReportRoot)
  </section>
  <section>
    <h2>Decision Dock</h2>
    $(ConvertTo-EventDetailsHtml -Events $decisionEvents -RepoRoot $root -ReportRoot $resolvedReportRoot)
  </section>
  <section>
    <h2>Interpretation Summary</h2>
    $(ConvertTo-SummaryHtml -Events $events -Manifest $manifest)
  </section>
</div>
"@

    $templateRoot = Join-Path (Split-Path -Parent $PSScriptRoot) "templates"
    $template = Get-Content -LiteralPath (Join-Path $templateRoot "report-template.html") -Raw
    $css = Get-Content -LiteralPath (Join-Path $templateRoot "report.css") -Raw
    $js = Get-Content -LiteralPath (Join-Path $templateRoot "report.js") -Raw
    $html = $template.
        Replace("{{TITLE}}", (ConvertTo-HtmlText $manifest.title)).
        Replace("{{STATUS}}", (ConvertTo-HtmlText $manifest.status)).
        Replace("{{CSS}}", $css).
        Replace("{{BODY}}", $body).
        Replace("{{MANIFEST_JSON}}", (ConvertTo-ManifestJsonForHtml -Manifest $manifest)).
        Replace("{{JS}}", $js)

    Set-Content -LiteralPath $indexPath -Encoding utf8NoBOM -Value $html

    [ordered]@{
        ok = $true
        index_path = $indexPath
        event_count = $events.Count
        section_count = 6
    } | ConvertTo-Json -Depth 20
} catch {
    [ordered]@{ ok = $false; phase = "render-report"; reason = $_.Exception.Message } | ConvertTo-Json -Depth 8
    exit 1
}
