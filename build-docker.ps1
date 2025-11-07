#!/usr/bin/env pwsh
<#
.SYNOPSIS
    PowerShell wrapper for build.sh to build Pi-hole Docker images on Windows.

.DESCRIPTION
    Executes build.sh in a Docker container from the docker-pi-hole directory.
    Supports building FTL locally before the docker build if requested.

.PARAMETER BuildFTL
    Build FTL locally first before building the Docker image.

.PARAMETER Help
    Display help information about build.sh options.

.EXAMPLE
    .\build-docker.ps1
    Build Docker image with default settings

.EXAMPLE
    .\build-docker.ps1 -l
    Build Docker image using existing local FTL binary

.EXAMPLE
    .\build-docker.ps1 -BuildFTL
    Build FTL locally first, then build Docker image with local FTL

.EXAMPLE
    .\build-docker.ps1 -Help
    Show build.sh help information

.EXAMPLE
    .\build-docker.ps1 --help
    Show build.sh help information (git-style)
#>

param(
    [switch]$BuildFTL,
    
    [switch]$Help
)

# Check Docker is available
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "Docker is required. Install from https://www.docker.com/products/docker-desktop"
    exit 1
}

# Check for legacy -l/--local arguments and convert to parameter
if ($args -contains '-l' -or $args -contains '--local') {
    $useLocal = $true
    # Don't remove from args - pass it through to build.sh
}

# Handle help request
if ($Help -or $args -contains '--help' -or $args -contains '-h') {
    Write-Host "Displaying build.sh help..." -ForegroundColor Cyan
    Write-Host ""
    
    $dockerPiHoleDir = Join-Path $PSScriptRoot 'docker-pi-hole'
    if (-not (Test-Path $dockerPiHoleDir)) {
        Write-Error "Could not find docker-pi-hole directory."
        exit 1
    }
    
    $workDir = $dockerPiHoleDir -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'
    
    docker run --rm `
        -v "${dockerPiHoleDir}:${workDir}" `
        -v /var/run/docker.sock:/var/run/docker.sock `
        -w "${workDir}" `
        docker:cli `
        sh -c "apk add -q bash dos2unix && dos2unix build.sh 2>/dev/null; bash build.sh --help"
    
    exit $LASTEXITCODE
}

# If requested, run the FTL build first
if ($BuildFTL) {
    $ftlScript = Join-Path $PSScriptRoot 'build-ftl.ps1'
    if (-not (Test-Path $ftlScript)) {
        Write-Error "Requested FTL build but could not find $ftlScript"
        exit 2
    }

    Write-Host "Building FTL first via $ftlScript ..." -ForegroundColor Cyan
    # Pass an internal flag to suppress the 'You can now build...' hint
    & $ftlScript --no-hint
    if ($LASTEXITCODE -ne 0) {
        Write-Error "FTL build failed with exit code $LASTEXITCODE. Aborting docker build."
        exit $LASTEXITCODE
    }
    Write-Host "FTL build completed successfully. Continuing to docker build." -ForegroundColor Green
}

# Set the docker-pi-hole directory as the working directory
$dockerPiHoleDir = Join-Path $PSScriptRoot 'docker-pi-hole'
if (-not (Test-Path $dockerPiHoleDir)) {
    Write-Error "Could not find docker-pi-hole directory."
    Write-Error "Please run the script from the repository root or ensure docker-pi-hole directory exists."
    exit 2
}

# Convert Windows path to Unix-style for Docker volume mount
$workDir = $dockerPiHoleDir -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'

# Build command with escaped arguments
$bashCommand = "bash build.sh " + ($args | ForEach-Object { if ($_ -match '\s') { "'$_'" } else { $_ } }) -join ' '

Write-Host "Executing: $bashCommand" -ForegroundColor Cyan
Write-Host ""

# Run build.sh in docker:cli container
docker run --rm `
    -v "${dockerPiHoleDir}:${workDir}" `
    -v /var/run/docker.sock:/var/run/docker.sock `
    -w "${workDir}" `
    docker:cli `
    sh -c "apk add -q bash dos2unix curl && dos2unix build.sh 2>/dev/null; $bashCommand"

exit $LASTEXITCODE
