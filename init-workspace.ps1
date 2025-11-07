#!/usr/bin/env pwsh

# Pi-hole Workspace Initialization Script
# This script clones all the necessary Pi-hole repositories and checks them out to the development branch

Write-Host "Initializing Pi-hole workspace..." -ForegroundColor Green

# Define repositories to clone
$repositories = @(
    @{
        Name = "pi-hole"
        Url = "https://github.com/pi-hole/pi-hole.git"
    },
    @{
        Name = "FTL"
        Url = "https://github.com/pi-hole/FTL.git"
    },
    @{
        Name = "web"
        Url = "https://github.com/pi-hole/web.git"
    },
    @{
        Name = "docker-pi-hole"
        Url = "https://github.com/pi-hole/docker-pi-hole.git"
    },
    @{
        Name = "PADD"
        Url = "https://github.com/pi-hole/PADD.git"
    },
    @{
        Name = "docs"
        Url = "https://github.com/pi-hole/docs.git"
    },
    @{
        Name = "docker-base-images"
        Url = "https://github.com/pi-hole/docker-base-images.git"
    }
)

# Function to clone repository and checkout development branch
function Initialize-Repository {
    param(
        [string]$Name,
        [string]$Url
    )
    
    Write-Host "Processing repository: $Name" -ForegroundColor Yellow
    
    if (Test-Path $Name) {
        Write-Host "  Directory $Name already exists, skipping clone..." -ForegroundColor DarkYellow
        Set-Location $Name
    } else {
        Write-Host "  Cloning $Url..." -ForegroundColor Cyan
        git clone $Url $Name
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to clone $Name"
            return $false
        }
        Set-Location $Name
    }
    
    # Check if development branch exists remotely
    $branchExists = git branch -r --list "origin/development" | Where-Object { $_.Trim() -eq "origin/development" }
    
    if ($branchExists) {
        # Check current branch
        $currentBranch = git branch --show-current
        
        if ($currentBranch -eq "development") {
            Write-Host "  Already on development branch" -ForegroundColor Green
            
            # Pull latest changes
            Write-Host "  Pulling latest changes..." -ForegroundColor Cyan
            git pull origin development
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Failed to pull latest changes for $Name"
            }
        } else {
            # Check for unstaged/staged changes
            $gitStatus = git status --porcelain
            
            if ($gitStatus) {
                Write-Warning "Repository $Name has unstaged/staged changes. Skipping checkout to avoid data loss."
                Write-Host "  Current branch: $currentBranch" -ForegroundColor Gray
                Write-Host "  To manually switch: 'git stash && git checkout development && git stash pop'" -ForegroundColor Gray
            } else {
                Write-Host "  Checking out development branch..." -ForegroundColor Cyan
                
                # Check if local development branch exists
                $localDevExists = git branch --list "development" | Where-Object { $_.Trim() -eq "development" -or $_.Trim() -eq "* development" }
                
                if ($localDevExists) {
                    git checkout development
                } else {
                    git checkout -b development origin/development
                }
                
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "Failed to checkout development branch for $Name, staying on current branch"
                } else {
                    # Pull latest changes after successful checkout
                    Write-Host "  Pulling latest changes..." -ForegroundColor Cyan
                    git pull origin development
                    if ($LASTEXITCODE -ne 0) {
                        Write-Warning "Failed to pull latest changes for $Name"
                    }
                }
            }
        }
    } else {
        Write-Warning "Development branch not found for $Name, staying on current branch"
    }
    
    Set-Location ..
    Write-Host "  ✓ Completed $Name" -ForegroundColor Green
    return $true
}

# Check if git is available
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Git is not installed or not in PATH. Please install Git and try again."
    exit 1
}

## Check SSH connection to GitHub
#Write-Host "Testing SSH connection to GitHub..." -ForegroundColor Yellow
#$sshTest = ssh -T git@github.com 2>&1
#if ($LASTEXITCODE -ne 1) {  # SSH to GitHub returns exit code 1 on successful auth
#    Write-Warning "SSH connection to GitHub may not be properly configured."
#    Write-Host "SSH test output: $sshTest" -ForegroundColor Gray
#    Write-Host "Continuing anyway..." -ForegroundColor Yellow
#}

# Clone each repository
$successCount = 0
foreach ($repo in $repositories) {
    if (Initialize-Repository -Name $repo.Name -Url $repo.Url) {
        $successCount++
    }
}

Write-Host "`nWorkspace initialization completed!" -ForegroundColor Green
Write-Host "Successfully processed $successCount out of $($repositories.Count) repositories." -ForegroundColor Green

if ($successCount -eq $repositories.Count) {
    Write-Host "All repositories are ready for development!" -ForegroundColor Green
    exit 0
} else {
    Write-Warning "Some repositories failed to initialize properly. Please check the output above."
    exit 1
}
