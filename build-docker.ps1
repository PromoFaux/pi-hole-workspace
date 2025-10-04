#!/usr/bin/env pwsh
<#
.SYNOPSIS
    PowerShell wrapper for build.sh to build Pi-hole Docker images on Windows.

.DESCRIPTION
    Executes build.sh in a Docker container from the docker-pi-hole directory.
    If the `-l` or `--local` switch is present, the script will first build FTL 
    by invoking `build-ftl.ps1` in the repository root, then continue to the 
    docker build.

.NOTES
    Run .\build-docker.ps1 --help for full usage details.
#>


# Check Docker is available
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Docker is required. Install from https://www.docker.com/products/docker-desktop"
    exit 1
}

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


# Set the docker-pi-hole directory as the working directory
$dockerPiHoleDir = Join-Path $PSScriptRoot 'docker-pi-hole'
if (-not (Test-Path $dockerPiHoleDir)) {
    Write-Host "Could not find docker-pi-hole directory."
    Write-Host "Please run the script from the repository root or ensure docker-pi-hole directory exists."
    exit 2
}

# Convert Windows path to Unix-style for Docker volume mount
$workDir = $dockerPiHoleDir -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'

# Build command with escaped arguments
$bashCommand = "bash build.sh " + ($args | ForEach-Object { if ($_ -match '\s') { "'$_'" } else { $_ } }) -join ' '

Write-Host "Executing: $bashCommand"

# Run build.sh in docker:cli container
docker run --rm `
    -v "${dockerPiHoleDir}:${workDir}" `
    -v /var/run/docker.sock:/var/run/docker.sock `
    -w "${workDir}" `
    docker:cli `
    sh -c "apk add -q bash dos2unix curl && dos2unix build.sh 2>/dev/null; $bashCommand"

exit $LASTEXITCODE
