#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Manage Pi-hole Docker container using docker-compose.

.DESCRIPTION
    Convenient wrapper for docker-compose commands in the docker-manual-testing directory.
    Supports running containers interactively or in detached mode, viewing logs, and stopping containers.

.PARAMETER Detach
    Run containers in detached (background) mode instead of attaching to output.
    Shorthand: -d

.PARAMETER Logs
    Follow and display logs from running containers.
    Use -Logs without other parameters to view logs of existing containers.
    Shorthand: -l

.PARAMETER Stop
    Stop and remove running containers.
    Shorthand: -s

.PARAMETER Help
    Display this help information.

.EXAMPLE
    .\run-docker.ps1
    Start containers in interactive mode (press Ctrl+C to stop)

.EXAMPLE
    .\run-docker.ps1 -Detach
    Start containers in background mode

.EXAMPLE
    .\run-docker.ps1 -Logs
    Follow logs from running containers

.EXAMPLE
    .\run-docker.ps1 -Stop
    Stop and remove running containers

.EXAMPLE
    .\run-docker.ps1 -Help
    Display this help information
#>

param(
    [Alias('d')]
    [switch]$Detach,
    
    [Alias('l')]
    [switch]$Logs,
    
    [Alias('s')]
    [switch]$Stop,
    
    [switch]$Help
)

# Display help if requested
if ($Help -or $args -contains '--help' -or $args -contains '-h') {
    Get-Help $MyInvocation.MyCommand.Path -Full
    exit 0
}

Write-Host "Pi-hole Docker Manager" -ForegroundColor Green
Write-Host "======================" -ForegroundColor Green

# Change to the docker-manual-testing directory
$dockerDir = Join-Path $PSScriptRoot "docker-manual-testing"

if (-not (Test-Path $dockerDir)) {
    Write-Error "Docker manual testing directory not found at: $dockerDir"
    exit 1
}

if (-not (Test-Path (Join-Path $dockerDir "docker-compose.yml"))) {
    Write-Error "docker-compose.yml not found in: $dockerDir"
    exit 1
}

# Check if Docker is available
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "Docker is not installed or not in PATH. Please install Docker and try again."
    exit 1
}

# Check if docker-compose is available
if (-not (Get-Command docker-compose -ErrorAction SilentlyContinue)) {
    Write-Error "docker-compose is not installed or not in PATH. Please install docker-compose and try again."
    exit 1
}

Write-Host "Docker directory: $dockerDir" -ForegroundColor Cyan
Write-Host ""

# Store the original location
$originalLocation = Get-Location

try {
    Set-Location $dockerDir
    
    # Handle stop command
    if ($Stop) {
        Write-Host "Stopping Docker containers..." -ForegroundColor Yellow
        Write-Host ""
        docker-compose down
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "✓ Containers stopped and removed" -ForegroundColor Green
        } else {
            Write-Error "Failed to stop containers"
            exit $LASTEXITCODE
        }
        exit 0
    }
    
    # Handle logs command
    if ($Logs) {
        Write-Host "Following container logs (press Ctrl+C to stop)..." -ForegroundColor Cyan
        Write-Host ""
        docker-compose logs -f
        exit $LASTEXITCODE
    }
    
    # Handle up command (default or with -Detach)
    if ($Detach) {
        Write-Host "Starting containers in detached mode..." -ForegroundColor Cyan
        Write-Host ""
        docker-compose up -d
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "✓ Containers started in background" -ForegroundColor Green
            Write-Host ""
            Write-Host "Useful commands:" -ForegroundColor Green
            Write-Host "  .\run-docker.ps1 -Logs      Show container logs" -ForegroundColor Cyan
            Write-Host "  .\run-docker.ps1 -Stop      Stop containers" -ForegroundColor Cyan
            docker-compose ps
        } else {
            Write-Error "Failed to start containers"
            exit $LASTEXITCODE
        }
    } else {
        Write-Host "Starting containers in interactive mode..." -ForegroundColor Cyan
        Write-Host "Press Ctrl+C to stop the containers" -ForegroundColor Gray
        Write-Host ""
        docker-compose up
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Docker-compose exited with error code $LASTEXITCODE"
        } else {
            Write-Host ""
            Write-Host "✓ Containers stopped" -ForegroundColor Green
        }
        exit $LASTEXITCODE
    }
}
finally {
    # Always return to original directory, even if Ctrl+C is pressed
    Set-Location $originalLocation
}