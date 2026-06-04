[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

function Add-Check {
    param(
        [System.Collections.Generic.List[object]]$Checks,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][bool]$Ok,
        [string]$Reason = "passed"
    )
    $Checks.Add([pscustomobject]@{
        name = $Name
        ok = $Ok
        reason = if ($Ok) { "passed" } else { $Reason }
    })
}

function Convert-PolylinePoints {
    param([string]$Points)

    @($Points.Trim() -split "\s+" | ForEach-Object {
        $parts = $_ -split ","
        [pscustomobject]@{
            x = [int]$parts[0]
            y = [int]$parts[1]
        }
    })
}

function Get-RectTopCenterPoint {
    param([object]$Rect)

    [pscustomobject]@{
        x = [int]$Rect.x + ([int]$Rect.width / 2)
        y = [int]$Rect.y
    }
}

function Format-Point {
    param([object]$Point)

    return "$($Point.x),$($Point.y)"
}

function Test-SegmentIntersectsRectInterior {
    param(
        [object]$Start,
        [object]$End,
        [object]$Rect
    )

    $left = [int]$Rect.x
    $right = [int]$Rect.x + [int]$Rect.width
    $top = [int]$Rect.y
    $bottom = [int]$Rect.y + [int]$Rect.height

    if ($Start.x -eq $End.x) {
        $x = $Start.x
        $minY = [Math]::Min($Start.y, $End.y)
        $maxY = [Math]::Max($Start.y, $End.y)
        return ($x -gt $left -and $x -lt $right -and $maxY -gt $top -and $minY -lt $bottom)
    }

    if ($Start.y -eq $End.y) {
        $y = $Start.y
        $minX = [Math]::Min($Start.x, $End.x)
        $maxX = [Math]::Max($Start.x, $End.x)
        return ($y -gt $top -and $y -lt $bottom -and $maxX -gt $left -and $minX -lt $right)
    }

    return $true
}

function Test-RectsOverlap {
    param(
        [object]$A,
        [object]$B
    )

    $aLeft = [int]$A.x
    $aRight = [int]$A.x + [int]$A.width
    $aTop = [int]$A.y
    $aBottom = [int]$A.y + [int]$A.height
    $bLeft = [int]$B.x
    $bRight = [int]$B.x + [int]$B.width
    $bTop = [int]$B.y
    $bBottom = [int]$B.y + [int]$B.height

    return ($aLeft -lt $bRight -and $aRight -gt $bLeft -and $aTop -lt $bBottom -and $aBottom -gt $bTop)
}

$checks = [System.Collections.Generic.List[object]]::new()
$readmePath = Join-Path $RepoRoot "README.md"
$svgRelativePath = "docs/assets/native-qa-main-flow.svg"
$svgPath = Join-Path $RepoRoot $svgRelativePath

$readme = Get-Content -LiteralPath $readmePath -Raw
Add-Check $checks "README references SVG" ($readme.Contains("![Native Q&A main workflow flowchart]($svgRelativePath)")) "README must embed $svgRelativePath"
Add-Check $checks "README archived Mermaid removed" (-not $readme.Contains("Archived full setup, Doctor, and router flow")) "README must not keep the archived full Mermaid flowchart"
Add-Check $checks "README lists implement-plan skill" ($readme.Contains('$project:implement-plan')) "README must list the non-issue implement route"
Add-Check $checks "SVG exists" (Test-Path -LiteralPath $svgPath -PathType Leaf) "missing SVG: $svgPath"

if (Test-Path -LiteralPath $svgPath -PathType Leaf) {
    [xml]$svg = Get-Content -LiteralPath $svgPath -Raw
    $svgText = Get-Content -LiteralPath $svgPath -Raw
    Add-Check $checks "SVG uses expanded canvas" ([int]$svg.svg.width -eq 3000 -and [int]$svg.svg.height -eq 5340) "SVG must use the expanded 3000x5340 layout"

    foreach ($needle in @("--bg", "--line", "--label", "@media (prefers-color-scheme: dark)", ".canvas", ".arrow-head")) {
        Add-Check $checks "SVG contains $needle" ($svgText.Contains($needle)) "SVG must contain theme contract token: $needle"
    }

    foreach ($needle in @(
        "Initiate Workflow",
        "Setup Project",
        "Brainstorm Spec",
        "Write Plan",
        "Create Issues",
        "Implement Plan",
        "Resolve Issue",
        "Orchestrate Issues",
        "Merge Changes",
        "Audit Project",
        "Setup project",
        "Review route",
        "Stop here",
        "Healthy can finish at Done",
        "Healthy -> Done",
        "Decline merge"
    )) {
        Add-Check $checks "SVG contains label $needle" ($svgText.Contains($needle)) "SVG must show workflow label: $needle"
    }

    foreach ($forbiddenLabel in @(
        "Down: progress",
        "Down: merge branch",
        "Left: review",
        "Left: repair",
        "Right: Stop / Done",
        "Final down: Done"
    )) {
        Add-Check $checks "SVG omits old directional label $forbiddenLabel" (-not $svgText.Contains($forbiddenLabel)) "SVG must use decision labels instead of directional shorthand: $forbiddenLabel"
    }

    $curvedPathValues = @($svg.SelectNodes("//*[local-name()='path']") | Where-Object { [string]$_.d -match "[CQ]" })
    $curvedPolylineValues = @($svg.SelectNodes("//*[local-name()='polyline']") | Where-Object { [string]$_.points -match "[CQ]" })
    Add-Check $checks "SVG avoids curved connectors" ($curvedPathValues.Count -eq 0 -and $curvedPolylineValues.Count -eq 0) "flowchart connectors must be straight or right-angled, not curved"

    $rects = @($svg.svg.rect)
    $skillRects = @($rects | Where-Object { [string]$_.class -match "(^|\s)skill(\s|$)" })
    $mainSkillRects = @($rects | Where-Object { [string]$_.class -match "(^|\s)main-skill(\s|$)" })
    $peerSkillRects = @($rects | Where-Object { [string]$_.class -match "(^|\s)peer-skill(\s|$)" })
    $sideRects = @($rects | Where-Object { $_.class -eq "side" })
    $stopRects = @($rects | Where-Object { $_.class -eq "stop" })

    Add-Check $checks "skill boxes exist" ($skillRects.Count -ge 9) "SVG must contain workflow skill boxes"
    $mainSkillXValues = @($mainSkillRects | ForEach-Object { [int]$_.x } | Sort-Object -Unique)
    $mainSkillWidthValues = @($mainSkillRects | ForEach-Object { [int]$_.width } | Sort-Object -Unique)
    Add-Check $checks "main skill boxes share centered rail" ($mainSkillXValues.Count -eq 1 -and $mainSkillXValues[0] -eq 1240 -and $mainSkillWidthValues.Count -eq 1 -and $mainSkillWidthValues[0] -eq 520) "main skill boxes must stay on the centered rail"
    $topRailYs = @("skill-initiate", "skill-setup", "skill-brainstorm", "skill-plan") | ForEach-Object {
        [int]$svg.SelectSingleNode("//*[@id='$_']").y
    }
    $topRailDiffs = @()
    for ($i = 0; $i -lt ($topRailYs.Count - 1); $i++) {
        $topRailDiffs += ($topRailYs[$i + 1] - $topRailYs[$i])
    }
    $uniqueTopRailDiffs = @($topRailDiffs | Sort-Object -Unique)
    Add-Check $checks "top rail uses uniform breathing room" ($uniqueTopRailDiffs.Count -eq 1 -and $uniqueTopRailDiffs[0] -ge 450) "Initiate, Setup, Brainstorm Spec, and Write Plan must use uniform vertical spacing"
    Add-Check $checks "peer skill boxes exist" ($peerSkillRects.Count -eq 4) "Implement/Create and Resolve/Orchestrate must be peer skill boxes"
    Add-Check $checks "implement and create issues share row" ([int]$svg.SelectSingleNode("//*[@id='skill-implement']").y -eq [int]$svg.SelectSingleNode("//*[@id='skill-create-issues']").y) "Implement Plan and Create Issues must sit on the same horizontal level"
    Add-Check $checks "resolve and orchestrate share row" ([int]$svg.SelectSingleNode("//*[@id='skill-resolve']").y -eq [int]$svg.SelectSingleNode("//*[@id='skill-orchestrate']").y) "Resolve Issue and Orchestrate Issues must sit on the same horizontal level"
    Add-Check $checks "resolve stays under create issues" ([int]$svg.SelectSingleNode("//*[@id='skill-resolve']").x -eq [int]$svg.SelectSingleNode("//*[@id='skill-create-issues']").x) "Resolve Issue must sit under Create Issues as the default classic workflow"
    Add-Check $checks "orchestrate is left worker peer" ([int]$svg.SelectSingleNode("//*[@id='skill-orchestrate']").x -eq [int]$svg.SelectSingleNode("//*[@id='skill-implement']").x -and [int]$svg.SelectSingleNode("//*[@id='skill-orchestrate']").x -lt [int]$svg.SelectSingleNode("//*[@id='skill-resolve']").x) "Orchestrate Issues must be the left worker peer after Create Issues"
    Add-Check $checks "stop nodes stay on right side of decisions" (@($stopRects | Where-Object { [int]$_.x -lt 580 }).Count -eq 0) "stop nodes must be right-side break nodes"
    $stopSideOverlap = $false
    foreach ($stopRect in $stopRects) {
        foreach ($sideRect in $sideRects) {
            if (Test-RectsOverlap -A $stopRect -B $sideRect) {
                $stopSideOverlap = $true
            }
        }
    }
    Add-Check $checks "stop nodes do not overlap review boxes" (-not $stopSideOverlap) "stop nodes must not overlap gray review boxes"

    $decisionPolygons = @($svg.svg.polygon | Where-Object { $_.class -eq "decision" })
    Add-Check $checks "decision diamonds exist" ($decisionPolygons.Count -ge 6) "SVG must include continuation decision diamonds"
    foreach ($polygon in $decisionPolygons) {
        $points = @(([string]$polygon.points).Trim() -split "\s+")
        $top = $points[0] -split ","
        $right = $points[1] -split ","
        $bottom = $points[2] -split ","
        $left = $points[3] -split ","
        $topX = [int]$top[0]
        $rightX = [int]$right[0]
        $bottomX = [int]$bottom[0]
        $leftX = [int]$left[0]
            $isCenteredDiamond = $points.Count -eq 4 -and
            $bottomX -eq $topX -and
            $rightX -eq ($topX + 150) -and
            $leftX -eq ($topX - 150)
        Add-Check $checks "decision diamond geometry $($polygon.id)" $isCenteredDiamond "decision diamonds must use top/right/bottom/left points around one center"
    }

    $reviseReturnRoutes = @($svg.SelectNodes("//*[local-name()='polyline' and contains(concat(' ', normalize-space(@class), ' '), ' revise-return ')]"))
    Add-Check $checks "revise return routes exist" ($reviseReturnRoutes.Count -ge 8) "SVG must include gray-box return arrows"
    foreach ($route in $reviseReturnRoutes) {
        $suffix = ([string]$route.id).Replace("return-", "")
        $side = $svg.SelectSingleNode("//*[@id='side-$suffix']")
        $sideExists = $null -ne $side
        Add-Check $checks "revise return has side box $($route.id)" $sideExists "revise return route must map to a side box"
        if ($sideExists) {
            $centerX = [int]$side.x + ([int]$side.width / 2)
            $topY = [int]$side.y
            Add-Check $checks "revise return starts at gray top center $($route.id)" ([string]$route.points -match "^$centerX,$topY") "gray return arrows must start from the center top of the gray box"
        }
    }

    $choiceRoutes = @($svg.SelectNodes("//*[local-name()='polyline' and starts-with(@id, 'choice-')]"))
    Add-Check $checks "choice routes exist" ($choiceRoutes.Count -ge 8) "SVG must include decision-to-gray review arrows"
    foreach ($route in $choiceRoutes) {
        $suffix = ([string]$route.id).Replace("choice-", "")
        $side = $svg.SelectSingleNode("//*[@id='side-$suffix']")
        $sideExists = $null -ne $side
        Add-Check $checks "choice route has side box $($route.id)" $sideExists "choice route must map to a side box"
        if ($sideExists) {
            $rightX = [int]$side.x + [int]$side.width
            $centerY = [int]$side.y + ([int]$side.height / 2)
            $lastPoint = @(([string]$route.points).Trim() -split "\s+")[-1]
            Add-Check $checks "choice route ends at gray right center $($route.id)" ($lastPoint -eq "$rightX,$centerY") "gray review arrows must enter the right-center of the gray box"
        }
    }

    $stopRoutes = @($svg.SelectNodes("//*[local-name()='polyline' and contains(concat(' ', normalize-space(@class), ' '), ' stop-route ')]"))
    Add-Check $checks "stop routes exist" ($stopRoutes.Count -ge 5) "SVG must mark stop routes with class stop-route"
    $rightPoints = @($decisionPolygons | ForEach-Object {
        @(([string]$_.points).Trim() -split "\s+")[1]
    })
    foreach ($route in $stopRoutes) {
        $firstPoint = @(([string]$route.points).Trim() -split "\s+")[0]
        Add-Check $checks "stop route starts at right diamond point $($route.id)" ($rightPoints -contains $firstPoint) "stop routes must stem from a right point of a decision diamond"
    }

    $downRoutes = @($svg.SelectNodes("//*[contains(concat(' ', normalize-space(@class), ' '), ' down-route ')]"))
    Add-Check $checks "down routes exist" ($downRoutes.Count -ge 8) "SVG must mark default progress routes with class down-route"
    Add-Check $checks "plan splits to implement peer" ($svgText.Contains('id="route-plan-implement"')) "Plan route must split to Implement Plan"
    Add-Check $checks "plan splits to create issues peer" ($svgText.Contains('id="route-plan-create"')) "Plan route must split to Create Issues"
    Add-Check $checks "create issues splits to resolve peer" ($svgText.Contains('id="route-create-resolve"')) "Create Issues route must split to Resolve Issue"
    Add-Check $checks "create issues splits to orchestrate peer" ($svgText.Contains('id="route-create-orchestrate"')) "Create Issues route must split to Orchestrate Issues"
    $createResolveRoute = $svg.SelectSingleNode("//*[@id='route-create-resolve']")
    if ($null -ne $createResolveRoute) {
        $resolveTopCenter = Format-Point (Get-RectTopCenterPoint $svg.SelectSingleNode("//*[@id='skill-resolve']"))
        $orchestrateTopCenter = Format-Point (Get-RectTopCenterPoint $svg.SelectSingleNode("//*[@id='skill-orchestrate']"))
        $createResolveRouteText = [string]$createResolveRoute.points
        Add-Check $checks "create resolve route enters resolve top center" ($createResolveRouteText.Trim().EndsWith($resolveTopCenter)) "Create Issues -> Resolve Issue route must enter the top center of Resolve Issue"
        Add-Check $checks "create resolve route stays in classic right column" (-not $createResolveRouteText.Contains($orchestrateTopCenter)) "Create Issues -> Resolve Issue route must stay in the classic right column"
        $createResolvePoints = Convert-PolylinePoints -Points ([string]$createResolveRoute.points)
        $createResolveCrossesStop = $false
        for ($i = 0; $i -lt ($createResolvePoints.Count - 1); $i++) {
            foreach ($stopRect in $stopRects) {
                if (Test-SegmentIntersectsRectInterior -Start $createResolvePoints[$i] -End $createResolvePoints[$i + 1] -Rect $stopRect) {
                    $createResolveCrossesStop = $true
                }
            }
        }
        Add-Check $checks "create resolve route avoids stop nodes" (-not $createResolveCrossesStop) "Create Issues -> Resolve Issue route must not pass through Stop / Done nodes"
    }
    $implementRoute = $svg.SelectSingleNode("//*[@id='route-implement-merge']")
    Add-Check $checks "implement bypasses issue execution" ($svgText.Contains('id="route-implement-merge"') -and $svgText.Contains('direct-merge-route')) "Implement Plan must route directly to Merge Changes"
    if ($null -ne $implementRoute) {
        $resolveTopCenter = Format-Point (Get-RectTopCenterPoint $svg.SelectSingleNode("//*[@id='skill-resolve']"))
        $orchestrateTopCenter = Format-Point (Get-RectTopCenterPoint $svg.SelectSingleNode("//*[@id='skill-orchestrate']"))
        $implementRouteText = [string]$implementRoute.points
        Add-Check $checks "implement route leaves center before issue row" (-not $implementRouteText.Contains($resolveTopCenter) -and -not $implementRouteText.Contains($orchestrateTopCenter)) "Implement Plan direct route must not visually continue into Resolve Issue or Orchestrate Issues"
        $implementRoutePoints = Convert-PolylinePoints -Points ([string]$implementRoute.points)
        $usesLeftBypassGutter = $false
        for ($i = 0; $i -lt ($implementRoutePoints.Count - 1); $i++) {
            if ($implementRoutePoints[$i].x -eq 80 -and $implementRoutePoints[$i + 1].x -eq 80 -and [Math]::Abs($implementRoutePoints[$i + 1].y - $implementRoutePoints[$i].y) -ge 500) {
                $usesLeftBypassGutter = $true
            }
        }
        Add-Check $checks "implement route uses left bypass gutter" $usesLeftBypassGutter "Implement Plan direct route must use the left bypass gutter into Merge Changes"
        $issueExecutionRects = @(
            $svg.SelectSingleNode("//*[@id='skill-resolve']"),
            $svg.SelectSingleNode("//*[@id='skill-orchestrate']")
        )
        $crossesIssueExecution = $false
        for ($i = 0; $i -lt ($implementRoutePoints.Count - 1); $i++) {
            foreach ($issueRect in $issueExecutionRects) {
                if (Test-SegmentIntersectsRectInterior -Start $implementRoutePoints[$i] -End $implementRoutePoints[$i + 1] -Rect $issueRect) {
                    $crossesIssueExecution = $true
                }
            }
        }
        Add-Check $checks "implement direct route avoids issue execution boxes" (-not $crossesIssueExecution) "Implement Plan direct route must not pass through Resolve Issue or Orchestrate Issues"
    }
    Add-Check $checks "final down done route exists" ($svgText.Contains('id="down-d10-done"') -and $svgText.Contains('final-done-route')) "Only the final health gate should have the explicit down-to-Done route"
}

$failed = @($checks | Where-Object { -not $_.ok })
$result = [pscustomobject]@{
    ok = ($failed.Count -eq 0)
    phase = "native-qa-svg-contract"
    checks = $checks
}

$result | ConvertTo-Json -Depth 8
if ($failed.Count -gt 0) {
    exit 1
}
