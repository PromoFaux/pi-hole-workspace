#!/usr/bin/env pwsh

# Pi-hole Workspace Initialization Script
# This script clones all the necessary Pi-hole repositories and checks them out to the appropriate branch

param(
    [switch]$Force,
    [switch]$Quiet,
    [switch]$Help
)

# Display help if requested
if ($Help -or $args -contains '--help' -or $args -contains '-h') {
    Write-Host "Pi-hole Workspace Initialization" -ForegroundColor Green
    Write-Host ""
    Write-Host "Usage: .\init-workspace.ps1 [OPTIONS]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Green
    Write-Host "  -Force      Reset existing repos to their default branch, discarding all changes" -ForegroundColor Cyan
    Write-Host "  -Quiet      Suppress verbose output, only show final summary" -ForegroundColor Cyan
    Write-Host "  -Help       Display this help information" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Green
    Write-Host "  .\init-workspace.ps1                    Clone all repos" -ForegroundColor Gray
    Write-Host "  .\init-workspace.ps1 -Force             Reset all existing repos" -ForegroundColor Gray
    Write-Host "  .\init-workspace.ps1 -Quiet -Force      Reset all repos quietly" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Note: The script will automatically fall back to HTTPS if SSH cloning fails." -ForegroundColor Gray
    exit 0
}

if (-not $Quiet) {
    Write-Host "Initializing Pi-hole workspace..." -ForegroundColor Green
    if ($Force) {
        Write-Host "Force mode enabled: Will reset existing repos and discard changes" -ForegroundColor Yellow
    }
}

# Define repositories to clone
$repositories = @(
    @{
        Name = "pi-hole"
        SshUrl = "git@github.com:pi-hole/pi-hole.git"
        HttpsUrl = "https://github.com/pi-hole/pi-hole.git"
    },
    @{
        Name = "FTL"
        SshUrl = "git@github.com:pi-hole/FTL.git"
        HttpsUrl = "https://github.com/pi-hole/FTL.git"
    },
    @{
        Name = "web"
        SshUrl = "git@github.com:pi-hole/web.git"
        HttpsUrl = "https://github.com/pi-hole/web.git"
    },
    @{
        Name = "docker-pi-hole"
        SshUrl = "git@github.com:pi-hole/docker-pi-hole.git"
        HttpsUrl = "https://github.com/pi-hole/docker-pi-hole.git"
    },
    @{
        Name = "PADD"
        SshUrl = "git@github.com:pi-hole/PADD.git"
        HttpsUrl = "https://github.com/pi-hole/PADD.git"
    },
    @{
        Name = "docs"
        SshUrl = "git@github.com:pi-hole/docs.git"
        HttpsUrl = "https://github.com/pi-hole/docs.git"
    },
    @{
        Name = "docker-base-images"
        SshUrl = "git@github.com:pi-hole/docker-base-images.git"
        HttpsUrl = "https://github.com/pi-hole/docker-base-images.git"
    }
)

# Function to clone repository and checkout development branch
function Initialize-Repository {
    param(
        [string]$Name,
        [string]$SshUrl,
        [string]$HttpsUrl,
        [bool]$Force,
        [bool]$Quiet
    )
    
    if (-not $Quiet) {
        Write-Host "Processing repository: $Name" -ForegroundColor Yellow
    }
    
    if (Test-Path $Name) {
        if (-not $Quiet) {
            Write-Host "  Directory $Name already exists, skipping clone..." -ForegroundColor DarkYellow
        }
        Set-Location $Name
    } else {
        if (-not $Quiet) {
            Write-Host "  Cloning from $SshUrl..." -ForegroundColor Cyan
        }
        
        # Try SSH first
        git clone $SshUrl $Name 2>$null
        if ($LASTEXITCODE -ne 0) {
            if (-not $Quiet) {
                Write-Host "  SSH clone failed, falling back to HTTPS..." -ForegroundColor Yellow
            }
            git clone $HttpsUrl $Name
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to clone $Name using both SSH and HTTPS"
                return $false
            }
        }
        Set-Location $Name
    }
    
    # Check if development branch exists remotely
    $branchExists = git branch -r --list "origin/development" | Where-Object { $_.Trim() -eq "origin/development" }
    
    # If development doesn't exist, try master
    $targetBranch = "development"
    if (-not $branchExists) {
        $branchExists = git branch -r --list "origin/master" | Where-Object { $_.Trim() -eq "origin/master" }
        if ($branchExists) {
            $targetBranch = "master"
            if (-not $Quiet) {
                Write-Host "  Development branch not found, using master instead" -ForegroundColor DarkYellow
            }
        }
    }
    
    if ($branchExists) {
        # Check current branch
        $currentBranch = git branch --show-current
        
        if ($currentBranch -eq $targetBranch) {
            if (-not $Quiet) {
                Write-Host "  Already on $targetBranch branch" -ForegroundColor Green
            }
            
            # If Force is enabled, reset even if on target branch
            if ($Force) {
                $gitStatus = git status --porcelain
                if ($gitStatus) {
                    if (-not $Quiet) {
                        Write-Host "  Discarding local changes..." -ForegroundColor Yellow
                    }
                    
                    # Discard all changes
                    git checkout -f HEAD
                    if ($LASTEXITCODE -ne 0) {
                        Write-Error "Failed to discard changes in $Name"
                        return $false
                    }
                    
                    # Clean untracked files
                    git clean -fd
                    if ($LASTEXITCODE -ne 0) {
                        Write-Error "Failed to clean untracked files in $Name"
                        return $false
                    }
                }
            }
            
            # Pull latest changes
            if (-not $Quiet) {
                Write-Host "  Pulling latest changes..." -ForegroundColor Cyan
            }
            git pull origin $targetBranch
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Failed to pull latest changes for $Name"
            }
        } else {
            # Check for unstaged/staged changes
            $gitStatus = git status --porcelain
            
            if ($gitStatus) {
                if ($Force) {
                    if (-not $Quiet) {
                        Write-Host "  Discarding changes and checking out $targetBranch branch..." -ForegroundColor Yellow
                    }
                    
                    # Discard all changes
                    git checkout -f HEAD
                    if ($LASTEXITCODE -ne 0) {
                        Write-Error "Failed to discard changes in $Name"
                        return $false
                    }
                    
                    # Clean untracked files
                    git clean -fd
                    if ($LASTEXITCODE -ne 0) {
                        Write-Error "Failed to clean untracked files in $Name"
                        return $false
                    }
                    
                    # Now checkout target branch
                    $localBranchExists = git branch --list $targetBranch | Where-Object { $_.Trim() -eq $targetBranch -or $_.Trim() -eq "* $targetBranch" }
                    
                    if ($localBranchExists) {
                        git checkout $targetBranch
                    } else {
                        git checkout -b $targetBranch origin/$targetBranch
                    }
                    
                    if ($LASTEXITCODE -ne 0) {
                        Write-Error "Failed to checkout $targetBranch branch for $Name"
                        return $false
                    }
                    
                    # Pull latest changes
                    if (-not $Quiet) {
                        Write-Host "  Pulling latest changes..." -ForegroundColor Cyan
                    }
                    git pull origin $targetBranch
                    if ($LASTEXITCODE -ne 0) {
                        Write-Warning "Failed to pull latest changes for $Name"
                    }
                } else {
                    Write-Warning "Repository $Name has unstaged/staged changes. Skipping checkout to avoid data loss."
                    if (-not $Quiet) {
                        Write-Host "  Current branch: $currentBranch" -ForegroundColor Gray
                        Write-Host "  To manually switch: 'git stash && git checkout $targetBranch && git stash pop'" -ForegroundColor Gray
                    }
                }
            } else {
                if (-not $Quiet) {
                    Write-Host "  Checking out $targetBranch branch..." -ForegroundColor Cyan
                }
                
                # Check if local target branch exists
                $localBranchExists = git branch --list $targetBranch | Where-Object { $_.Trim() -eq $targetBranch -or $_.Trim() -eq "* $targetBranch" }
                
                if ($localBranchExists) {
                    git checkout $targetBranch
                } else {
                    git checkout -b $targetBranch origin/$targetBranch
                }
                
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "Failed to checkout $targetBranch branch for $Name, staying on current branch"
                } else {
                    # Pull latest changes after successful checkout
                    if (-not $Quiet) {
                        Write-Host "  Pulling latest changes..." -ForegroundColor Cyan
                    }
                    git pull origin $targetBranch
                    if ($LASTEXITCODE -ne 0) {
                        Write-Warning "Failed to pull latest changes for $Name"
                    }
                }
            }
        }
    } else {
        Write-Warning "Neither development nor master branch found for $Name, staying on current branch"
    }
    
    Set-Location ..
    if (-not $Quiet) {
        Write-Host "  ✓ Completed $Name" -ForegroundColor Green
    }
    return $true
}

# Check if git is available
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Git is not installed or not in PATH. Please install Git and try again."
    exit 1
}

# Check SSH connection to GitHub
Write-Host "Testing SSH connection to GitHub..." -ForegroundColor Yellow
$sshTest = ssh -T git@github.com 2>&1
if ($LASTEXITCODE -ne 1) {  # SSH to GitHub returns exit code 1 on successful auth
    Write-Warning "SSH connection to GitHub may not be properly configured."
    Write-Host "SSH test output: $sshTest" -ForegroundColor Gray
    Write-Host "Continuing anyway..." -ForegroundColor Yellow
}

# Clone each repository
$successCount = 0
foreach ($repo in $repositories) {
    if (Initialize-Repository -Name $repo.Name -SshUrl $repo.SshUrl -HttpsUrl $repo.HttpsUrl -Force $Force -Quiet $Quiet) {
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