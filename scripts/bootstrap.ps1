# bootstrap.ps1
# This script sets up the development environment by checking and installing necessary dependencies.

# get environment variables for easier access
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
# get env DEBUG for logging and dev stuff
# $DEBUG = [System.Environment]::GetEnvironmentVariable("DEBUG", "User")
$DEBUG = "true" # set to true for testing purposes, lazy way

#Options

## Dependencies Versions for mvp - Only x64 supported for now.
# x86 will never be supported for WSL2. So no need to add it here.

# WT = Windows Terminal v1.23.12811.0
# Source: https://github.com/microsoft/terminal/releases/tag/v1.23.12811.0
# direct_source_x64 = https://github.com/microsoft/terminal/releases/download/v1.23.12811.0/Microsoft.WindowsTerminal_1.23.12811.0_x64.zip
# direct_source_arm64 = https://github.com/microsoft/terminal/releases/download/v1.23.12811.0/Microsoft.WindowsTerminal_1.23.12811.0_arm64.zip
# WSL2 = WSL2 2.6.1 - github release
# Source: https://github.com/microsoft/WSL/releases/tag/2.6.1
# direct_source_x64 = https://github.com/microsoft/WSL/releases/download/2.6.1/wsl.2.6.1.0.x64.msi
# direct_source_arm64 = https://github.com/microsoft/WSL/releases/download/2.6.1/wsl.2.6.1.0.arm64.msi
# Git = Git for Windows v2.51.0.windows.1
# direct_source_x64: https://github.com/git-for-windows/git/releases/tag/v2.51.0 https://github.com/git-for-windows/git/releases/download/v2.51.0.windows.1/Git-2.51.0-64-bit.exe
# direct_source_arm64 = https://github.com/git-for-windows/git/releases/download/v2.51.0.windows.1/Git-2.51.0-arm64.exe

# TODO: add more dependencies as needed | TODO: add winget and stuff later
$dependencies = @{
    wsl = {
        name = "Windows Subsystem for Linux"
        install_instructions = "Follow instructions at https://docs.microsoft.com/en-us/windows/wsl/install-manual"
        Version_Command = "wsl --version",
        install_sources = {
            github_release_x64 = "https://github.com/microsoft/WSL/releases/download/2.6.1/wsl.2.6.1.0.x64.msi"
            github_release_arm64 = "https://github.com/microsoft/WSL/releases/download/2.6.1/wsl.2.6.1.0.arm64.msi"
        }
    }
    wt = {
        name = "Windows Terminal"
        install_instructions = "Install from Microsoft Store: https://aka.ms/terminal"
        Version_Command = "wt --version"
        install_sources = {
            github_release_x64 = "https://github.com/microsoft/terminal/releases/download/v1.23.12811.0/Microsoft.WindowsTerminal_1.23.12811.0_x64.zip"
            github_release_arm64 = "https://github.com/microsoft/terminal/releases/download/v1.23.12811.0/Microsoft.WindowsTerminal_1.23.12811.0_arm64.zip"
        }
    }
    git = {
        name = "Git"
        install_instructions = "Download and install from https://git-scm.com/download/win"
        Version_Command = "git --version"
        install_sources = {
            github_release_x64 = "https://github.com/git-for-windows/git/releases/download/v2.51.0.windows.1/Git-2.51.0-64-bit.exe"
            github_release_arm64 = "https://github.com/git-for-windows/git/releases/download/v2.51.0.windows.1/Git-2.51.0-arm64.exe"
        }
    }
    # Add more dependencies as needed
}

#setup logging
function Log {
    param (
        [string]$message,
        [string]$level = "INFO"
    )
    # Log level Debug
    if ($DEBUG -eq "true" -and $level -eq "DEBUG") {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$timestamp] [$level] $message" -ForegroundColor Red
    } elseif ($level -ne "WARN") {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$timestamp] [$level] $message" -ForegroundColor Yellow
    } else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$timestamp] [$level] $message" -ForegroundColor Green
    }
}

# Get osVersion and architecture. Get additional machine details for debug purposes later.
function Get-MachineDetails {
    $osVersion = [System.Environment]::OSVersion.Version
    $architecture = (Get-CimInstance Win32_OperatingSystem).OSArchitecture
    # Get CPU info, RAM, Disk space and GPU later for debug purposes - anonymously used later for faster debugging.
    $cpuInfo = (Get-CimInstance Win32_Processor).Name
    $ram = [Math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
    $diskSpace = [Math]::Round((Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'").Size / 1GB, 2)
    $gpuInfo = (Get-CimInstance Win32_VideoController).Name
    return @{
        OSVersion = $osVersion
        Architecture = $architecture
        Detailed = {
            CPU = $cpuInfo
            RAM_GB = $ram
            DiskSpace_GB = $diskSpace
            GPU = $gpuInfo
        }
    }
}

Log "Machine Details:" "INFO"
Log (Get-MachineDetails) "INFO"

# Calls for admin rights if not running as admin
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Log "Script is not running as Administrator. Please run the script with elevated privileges." "ERROR"
    Log "Asking for Administrator privileges..." "DEBUG"
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit 1
} else {
    Log "Script is running with Administrator privileges." "INFO"
}

## Check if Hyper-V is enabled for WSL2. Later add prompting to auto enable it.
function CheckHyperV {
    $hyperVFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
    if ($hyperVFeature.State -ne "Enabled") {
        Log "Hyper-V is not enabled. Please enable it to use WSL2." "WARN"
        Log "You can enable it by running: Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All" "INFO"
        return "Disabled"
    } else {
        Log "Hyper-V is enabled." "INFO"
        return "Enabled"
    }
}

## If Hyper-V not installed, try to enable it. Check windows version first and available at hosts version.
function Enable-HyperV {
    $osVersion = [System.Environment]::OSVersion.Version
    if ($osVersion.Major -ge 10) {
        Log "Enabling Hyper-V..." "INFO"
        # Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart # Mocked for testing purposes
        Log "Hyper-V has been enabled. Please restart your computer to apply the changes." "INFO"
    } else {
        Log "Hyper-V cannot be enabled. Windows version is not supported." "ERROR"
        exit 1
    }
    
}

if (CheckHyperV -ne "Enabled") {
    Enable-HyperV
}

# Initialize variable for dependency check
$availableDependencies = @()
$unavailableDependencies = @()

# Function to check if a command exists
function Get-CommandInfo {
    param (
        [string]$command,
        [string]$version_command
    )
    $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
    try {
        $versionOutput = & $version_command 2>&1
        if ($versionOutput) {
            return $versionOutput.Trim()
        } else {
            return "Version information not available"
        }
    } catch {
        return "Error retrieving version"
    }
}
# Check for wsl, terminal(wt), and git
foreach ($dep in $dependencies) {
    if (-not (Get-CommandInfo $dep)) {
        Log "$dep is not installed. Please install it before proceeding." "WARN"
        $unavailableDependencies += $dep
        exit 1
    } else {
        Log "$dep is installed." "INFO"
        $availableDependencies += $dep
    }
}

# Log versions of available dependencies and saves then to a object 
$dependencyVersions = @{}
foreach ($dep in $availableDependencies) {
    $dependencyVersions[$dep] = Get-CommandVersion $dep
}

Log "Available Dependencies and their versions:" "INFO"
foreach ($dep in $dependencyVersions.Keys) {
    Log "$dep : $($dependencyVersions[$dep])" "INFO"
}

function Install-WSL {
    param (
        [string]$install_instructions,  
        [string]$direct_source = "" # Fallback to manual install if empty
    )
    if ($direct_source -ne "") {
        Invoke-WebRequest -Uri $direct_source -OutFile "$env:TEMP\WSLInstaller.msi"
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$env:TEMP\WSLInstaller.msi`" /quiet /norestart" -Wait
        Log "WSL has been installed successfully." "INFO"
        return "Success"
    } else {
        Log "Please install WSL manually from: $install_instructions" "INFO"
        return "Failed"
    }
}

function Install-Git {
    param (
        [string]$install_instructions,  
        [string]$direct_source = "" # Fallback to manual install if empty
    )
    if ($direct_source -ne "") {
        Invoke-WebRequest -Uri $direct_source -OutFile "$env:TEMP\GitInstaller.exe"
        Start-Process -FilePath "$env:TEMP\GitInstaller.exe" -ArgumentList "/SILENT" -Wait
        Log "Git has been installed successfully." "INFO"
        return "Success"
    } else {
        Log "Please install Git manually from: $install_instructions" "INFO"
        return "Failed"
    }
}

function Install-Terminal {
    param (
        [string]$install_instructions,  
        [string]$direct_source = "" # Fallback to manual install if empty
    )
    if ($direct_source -ne "") {
        Invoke-WebRequest -Uri $direct_source -OutFile "$env:TEMP\WindowsTerminal.zip"
        # Extract and install logic here
    } else {
        Log "Please install Windows Terminal manually from: $install_instructions" "INFO"
        return "Failed"
    }
}

function Start-PackageInstall {
    # Switch case to use arm64 or x64 sources based on machine architecture
    $machineDetails = Get-MachineDetails
    $architecture = $machineDetails.Architecture

    Log "Starting installation of unavailable dependencies... for $architecture" "INFO"

    # get dependency details from $dependencies
    foreach ($dep in $unavailableDependencies) {
        $depDetails = $dependencies[$dep]
        $source = if ($architecture -eq "ARM64") { $depDetails.install_sources.github_release_arm64 } else { $depDetails.install_sources.github_release_x64 }
        switch ($dep) {
            "wsl" {
                Install-WSL -install_instructions $depDetails.install_instructions -direct_source $source
            }
            "git" {
                Install-Git -install_instructions $depDetails.install_instructions -direct_source $source
            }
            "wt" {
                Install-Terminal -install_instructions $depDetails.install_instructions -direct_source $source
            }
            default {
                Log "No installation method defined for $dep" "ERROR"
            }
        }
    }
}