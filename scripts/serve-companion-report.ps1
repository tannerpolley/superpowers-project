[CmdletBinding()]
param(
    [string]$ReportsRoot = (Join-Path (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path ".superpowers\reports"),
    [string]$ReportRoot,
    [ValidateRange(1, 65535)][int]$Port = 57219,
    [ValidateSet("127.0.0.1", "localhost")][string]$HostName = "127.0.0.1",
    [switch]$Check
)

$ErrorActionPreference = "Stop"

function Resolve-CompanionReportRoot {
    param(
        [string]$ReportsRootPath,
        [string]$ReportRootPath
    )

    if ($ReportRootPath) {
        $resolvedReport = (Resolve-Path -LiteralPath $ReportRootPath).Path
        $indexPath = Join-Path $resolvedReport "index.html"
        if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) {
            throw "Report root does not contain index.html: $resolvedReport"
        }
        return $resolvedReport
    }

    $resolvedReports = (Resolve-Path -LiteralPath $ReportsRootPath).Path
    $indexFiles = @(
        Get-ChildItem -LiteralPath $resolvedReports -Filter "index.html" -File -Recurse |
            Sort-Object LastWriteTimeUtc, FullName -Descending
    )
    if ($indexFiles.Count -eq 0) {
        throw "No companion report index.html files found under $resolvedReports"
    }

    Split-Path -Parent $indexFiles[0].FullName
}

function Resolve-ListenAddress {
    param([string]$Name)

    if ($Name -eq "localhost") {
        return [System.Net.IPAddress]::Loopback
    }
    [System.Net.IPAddress]::Parse($Name)
}

function Get-ContentType {
    param([string]$Path)

    switch ([IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        ".css" { "text/css; charset=utf-8"; break }
        ".gif" { "image/gif"; break }
        ".htm" { "text/html; charset=utf-8"; break }
        ".html" { "text/html; charset=utf-8"; break }
        ".ico" { "image/x-icon"; break }
        ".jpg" { "image/jpeg"; break }
        ".jpeg" { "image/jpeg"; break }
        ".js" { "application/javascript; charset=utf-8"; break }
        ".json" { "application/json; charset=utf-8"; break }
        ".md" { "text/markdown; charset=utf-8"; break }
        ".png" { "image/png"; break }
        ".svg" { "image/svg+xml; charset=utf-8"; break }
        ".txt" { "text/plain; charset=utf-8"; break }
        default { "application/octet-stream" }
    }
}

function Write-HttpResponse {
    param(
        [System.IO.Stream]$Stream,
        [int]$StatusCode,
        [string]$ReasonPhrase,
        [byte[]]$Body,
        [string]$ContentType,
        [bool]$HeadOnly
    )

    $headers = @(
        "HTTP/1.1 $StatusCode $ReasonPhrase",
        "Content-Length: $($Body.Length)",
        "Content-Type: $ContentType",
        "Cache-Control: no-cache",
        "Connection: close",
        "",
        ""
    ) -join "`r`n"
    $headerBytes = [Text.Encoding]::ASCII.GetBytes($headers)
    $Stream.Write($headerBytes, 0, $headerBytes.Length)
    if (-not $HeadOnly -and $Body.Length -gt 0) {
        $Stream.Write($Body, 0, $Body.Length)
    }
}

function Write-ErrorResponse {
    param(
        [System.IO.Stream]$Stream,
        [int]$StatusCode,
        [string]$ReasonPhrase,
        [string]$Message,
        [bool]$HeadOnly
    )

    $body = [Text.Encoding]::UTF8.GetBytes("$StatusCode $ReasonPhrase`n$Message`n")
    Write-HttpResponse -Stream $Stream -StatusCode $StatusCode -ReasonPhrase $ReasonPhrase -Body $body -ContentType "text/plain; charset=utf-8" -HeadOnly $HeadOnly
}

function Resolve-RequestFile {
    param(
        [string]$Root,
        [string]$RequestPath
    )

    $pathOnly = ($RequestPath -split "\?", 2)[0]
    if ([string]::IsNullOrWhiteSpace($pathOnly) -or $pathOnly -eq "/") {
        $pathOnly = "/index.html"
    }

    $decodedPath = [Uri]::UnescapeDataString($pathOnly).Replace("/", [IO.Path]::DirectorySeparatorChar)
    $relativePath = $decodedPath.TrimStart([IO.Path]::DirectorySeparatorChar)
    $targetPath = [IO.Path]::GetFullPath((Join-Path $Root $relativePath))
    $normalizedRoot = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar)
    $rootPrefix = $normalizedRoot + [IO.Path]::DirectorySeparatorChar

    if (-not $targetPath.Equals($normalizedRoot, [StringComparison]::OrdinalIgnoreCase) -and
        -not $targetPath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw [System.UnauthorizedAccessException]::new("Request path escapes report root: $RequestPath")
    }

    if (Test-Path -LiteralPath $targetPath -PathType Container) {
        $targetPath = Join-Path $targetPath "index.html"
    }
    $targetPath
}

function Invoke-ClientRequest {
    param(
        [System.Net.Sockets.TcpClient]$Client,
        [string]$Root
    )

    $stream = $Client.GetStream()
    $reader = [System.IO.StreamReader]::new($stream, [Text.Encoding]::ASCII, $false, 1024, $true)
    $requestLine = $reader.ReadLine()
    if ([string]::IsNullOrWhiteSpace($requestLine)) { return }

    while ($true) {
        $line = $reader.ReadLine()
        if ($null -eq $line -or $line.Length -eq 0) { break }
    }

    $parts = $requestLine.Split(" ")
    if ($parts.Count -lt 2) {
        Write-ErrorResponse -Stream $stream -StatusCode 400 -ReasonPhrase "Bad Request" -Message "Malformed request line." -HeadOnly $false
        return
    }

    $method = $parts[0].ToUpperInvariant()
    $headOnly = $method -eq "HEAD"
    if ($method -notin @("GET", "HEAD")) {
        Write-ErrorResponse -Stream $stream -StatusCode 405 -ReasonPhrase "Method Not Allowed" -Message "Only GET and HEAD are supported." -HeadOnly $headOnly
        return
    }

    try {
        $filePath = Resolve-RequestFile -Root $Root -RequestPath $parts[1]
    } catch [System.UnauthorizedAccessException] {
        Write-ErrorResponse -Stream $stream -StatusCode 403 -ReasonPhrase "Forbidden" -Message $_.Exception.Message -HeadOnly $headOnly
        return
    }

    if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
        Write-ErrorResponse -Stream $stream -StatusCode 404 -ReasonPhrase "Not Found" -Message "No file exists for $($parts[1])." -HeadOnly $headOnly
        return
    }

    $body = [IO.File]::ReadAllBytes($filePath)
    Write-HttpResponse -Stream $stream -StatusCode 200 -ReasonPhrase "OK" -Body $body -ContentType (Get-ContentType -Path $filePath) -HeadOnly $headOnly
}

$root = Resolve-CompanionReportRoot -ReportsRootPath $ReportsRoot -ReportRootPath $ReportRoot
$listenAddress = Resolve-ListenAddress -Name $HostName
$listener = [System.Net.Sockets.TcpListener]::new($listenAddress, $Port)

try {
    $listener.Start()
    $url = "http://${HostName}:${Port}/index.html"

    if ($Check) {
        [pscustomobject]@{
            ok = $true
            url = $url
            report_root = $root
        } | ConvertTo-Json -Depth 4
        exit 0
    }

    Write-Host "Companion report preview: $url"
    Write-Host "Report root: $root"
    Write-Host "Stop this IntelliJ Services run configuration to stop the preview server."

    while ($true) {
        $client = $listener.AcceptTcpClient()
        try {
            Invoke-ClientRequest -Client $client -Root $root
        } catch {
            $stream = $client.GetStream()
            Write-ErrorResponse -Stream $stream -StatusCode 500 -ReasonPhrase "Internal Server Error" -Message $_.Exception.Message -HeadOnly $false
        } finally {
            $client.Close()
        }
    }
} finally {
    $listener.Stop()
}
