# Pi-hole Development Workspace

A simple workspace setup for Pi-hole development with all the necessary repositories and Docker testing environment.

## Quick Start

### Prerequisites
- **Git** with SSH access to GitHub
- **Docker** and **docker-compose**
- **PowerShell** (Tested on Windows but may also work on Linux/macOS)

### Setup
1. Clone this workspace repository
2. Run the initialization script:
   ```powershell
   .\init-workspace.ps1
   ```

This will clone all Pi-hole repositories and check them out to the `development` branch:
- `pi-hole/pi-hole` - Core Pi-hole scripts
- `pi-hole/FTL` - Pi-hole FTL (DNS engine)  
- `pi-hole/web` - Web admin interface
- `pi-hole/docker-pi-hole` - Docker container
- `pi-hole/PADD` - Pi-hole dashboard

### Development Testing

#### Build and Run
```powershell
# Build the Docker image
.\build-docker.ps1

# Start the test container
.\run-docker.ps1
```

#### Build FTL for inclusion in the image
```powershell
# Build FTL before docker and include the binary in the image
.\build-docker.ps1 -l

# Start the test container
.\run-docker.ps1
```

The test container will be available at:
- **Web Interface**: http://localhost
- **DNS**: localhost:53

#### Configuration
- **Web Interface**: Automatically mounted from `./web/` directory
- **Live Editing**: Changes to web files are immediately reflected in the container

#### Stopping
Press `Ctrl+C` to stop the container and return to your original directory.


## Notes
- The init script safely handles existing repositories and won't overwrite uncommitted changes
- Each repository can be developed independently
- Docker setup includes volume mounts for live development

Happy Pi-hole hacking! 🕳️