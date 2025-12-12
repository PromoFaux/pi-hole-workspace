#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generate FTL configuration documentation from pihole.toml.

.DESCRIPTION
    Converts the pihole.toml configuration file to Markdown documentation
    and updates docs/docs/ftldns/configfile.md.

    This is useful for updating documentation without rebuilding FTL.
    If you need to rebuild FTL, use build-ftl.ps1 instead.

.PARAMETER Help
    Display this help information.

.EXAMPLE
    .\build-docs.ps1
    Generate documentation from the existing pihole.toml

.EXAMPLE
    .\build-docs.ps1 -Help
    Show this help information

.NOTES
    Requires an existing FTL/pihole.toml file.
    If the file doesn't exist, run .\build-ftl.ps1 first.
#>

param(
    [switch]$Help
)

# Handle help request
if ($Help -or $args -contains '--help' -or $args -contains '-h' -or $args -contains 'help') {
    Get-Help $MyInvocation.MyCommand.Path -Full
    exit 0
}

# Search upward for the FTL directory (repo root/FTL)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$maxLevels = 8
$current = $scriptDir
$ftlDir = $null
for ($i = 0; $i -lt $maxLevels; $i++) {
    $candidate = Join-Path $current 'FTL'
    if (Test-Path $candidate) { $ftlDir = $candidate; break }
    $parent = Split-Path $current -Parent
    if ($parent -eq $current) { break }
    $current = $parent
}

if (-not $ftlDir) {
    Write-Error "FTL directory not found."
    exit 1
}

$configFile = Join-Path $ftlDir 'pihole.toml'
if (-not (Test-Path $configFile)) {
    Write-Error "Configuration file not found: $configFile"
    Write-Host "Please run .\build-ftl.ps1 first to generate pihole.toml" -ForegroundColor Cyan
    exit 1
}

Write-Host "Building FTL configuration documentation..." -ForegroundColor Green
Write-Host ""

# Determine repository root (parent of FTL)
$repoRoot = Split-Path $ftlDir -Parent
$toolsDir = Join-Path $ftlDir 'tools'
$docsDir = Join-Path $repoRoot 'docs'
$docsConfigFile = Join-Path (Join-Path $docsDir 'docs') 'ftldns' | Join-Path -ChildPath 'configfile.md'

# Verify tools directory and Python script exist
if (-not (Test-Path $toolsDir)) {
    Write-Error "Tools directory not found: $toolsDir"
    exit 1
}

$pythonScript = Join-Path $toolsDir 'pihole_toml_to_markdown.py'
if (-not (Test-Path $pythonScript)) {
    Write-Error "Python script not found: $pythonScript"
    exit 1
}

# Verify docs directory exists
if (-not (Test-Path $docsDir)) {
    Write-Error "Docs directory not found: $docsDir"
    exit 1
}

Write-Host "Input:  $configFile" -ForegroundColor Cyan
Write-Host "Output: $docsConfigFile" -ForegroundColor Cyan
Write-Host ""

# Run the Python script
$result = & python $pythonScript $configFile $docsConfigFile 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Documentation generated successfully" -ForegroundColor Green
    Write-Host ""
    Write-Host $result
} else {
    Write-Error "Failed to generate documentation"
    Write-Host $result
    exit 1
}

exit 0
