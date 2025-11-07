#!/usr/bin/env pwsh

# Pi-hole Docker Compose Runner
# This script runs docker-compose from the docker-manual-testing directory

Write-Host "Starting Pi-hole Docker container..." -ForegroundColor Green

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

Write-Host "Changing to directory: $dockerDir" -ForegroundColor Yellow

# Store the original location
$originalLocation = Get-Location

try {
    Set-Location $dockerDir
    
    Write-Host "Running docker-compose up..." -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to stop the container" -ForegroundColor Gray
    
    # Run docker-compose up
    docker-compose up
}
finally {
    # Always return to original directory, even if Ctrl+C is pressed
    Write-Host "Returning to original directory..." -ForegroundColor Yellow
    Set-Location $originalLocation
}