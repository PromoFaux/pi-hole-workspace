#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Top-level helper that invokes docker-pi-hole/build.ps1 if present.

.DESCRIPTION
    If `docker-pi-hole/build.ps1` exists relative to the repository root,
    this script forwards all arguments to it. If the `-l` or `--local`
    switch is present, the script will first build FTL by invoking
    `build-ftl.ps1` in the repository root, then continue to the docker
    build.
#>

# Determine the per-directory wrapper
$wrapper = Join-Path $PSScriptRoot 'docker-pi-hole' | Join-Path -ChildPath 'build.ps1'

# Check for -l/--local in the arguments
$hasLocal = $false
foreach ($a in $args) {
    if ($a -eq '-l' -or $a -eq '--local') { $hasLocal = $true; break }
}

# If requested, run the FTL build first
if ($hasLocal) {
    $ftlScript = Join-Path $PSScriptRoot 'build-ftl.ps1'
    if (-not (Test-Path $ftlScript)) {
        Write-Host "Requested local FTL build but could not find $ftlScript"
        exit 2
    }

    Write-Host "Building FTL first via $ftlScript ..."
    # Pass an internal flag to suppress the 'You can now build...' hint
    & $ftlScript --no-hint
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FTL build failed with exit code $LASTEXITCODE. Aborting docker build."
        exit $LASTEXITCODE
    }
    Write-Host "FTL build completed successfully. Continuing to docker build."
}

if (Test-Path $wrapper) {
    Write-Host "Invoking $wrapper"
    & $wrapper @args
    exit $LASTEXITCODE
} else {
    Write-Host "Could not find docker-pi-hole/build.ps1."
    Write-Host "Please run the script from the repository root or ensure docker-pi-hole/build.ps1 exists."
    exit 2
}
