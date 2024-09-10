# Define variables
$serverFolder = "C:\server"
$nodeServerFolder = "C:\server\hbt-moonlight-sunshine-pin-pairing"
$flagFile = "$serverFolder\initial_setup_done.txt"
$logFile = "$serverFolder\setup2.log"

# Function to log messages
function Log-Message {
    param (
        [string]$message
    )
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logMessage = "$timestamp - $message"
    Add-Content -Path $logFile -Value $logMessage
}

# Ensure running as administrator
If (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Log-Message "Script not running as administrator. Restarting with elevated privileges..."
    Start-Process powershell.exe "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# =============================== RUNS ON EVERY STARTUP =======================================

# Define Sunshine folder and executable path
$sunshineFolder = "C:\Program Files\Sunshine"
$sunshineExePath = "$sunshineFolder\sunshine.exe"

# Check if the Sunshine folder exists, and run sunshine.exe once it does
while (-not (Test-Path $sunshineFolder)) {
    Log-Message "Sunshine folder not found. Waiting for installation..."
    Start-Sleep -Seconds 10
}

if (Test-Path $sunshineExePath) {
    Log-Message "Sunshine folder and executable found. Starting Sunshine..."
    try {
        Start-Process -FilePath $sunshineExePath -ArgumentList '/silent /S' -Wait
        Log-Message "Sunshine started successfully."
    } catch {
        Log-Message "Failed to start Sunshine: $_"
    }
} else {
    Log-Message "Sunshine executable not found in $sunshineFolder."
}

# Check if the initial setup is already done
if (Test-Path $flagFile) {
    Log-Message "Initial setup is already done. Running PM2"
    try {
        Set-Location -Path $nodeServerFolder
        npm install pm2 -g 

        pm2 start .\index.js -n Pinsetup
        pm2 save --force
        Log-Message "PM2 Started" 
    }
    catch {
        Log-Message "Failed to Start PM2: $_"
    }


    exit
}

# =============================== THIS WILL RUN ONCE ONLY ===============================================

# Bypass SSL certificate validation
Add-Type @"
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;

public class BypassCertificateValidation
{
    public static void Bypass()
    {
        ServicePointManager.ServerCertificateValidationCallback = delegate (
            object sender, X509Certificate certificate, X509Chain chain, SslPolicyErrors sslPolicyErrors)
        {
            return true; // Bypass all SSL certificate errors
        };
    }
}
"@

[BypassCertificateValidation]::Bypass()

# Specify the URL for the POST request
$url = "https://localhost:47990/api/password"

# Define the JSON payload
$payload = @{
    newUsername = "sunshine"
    newPassword = "123"
    confirmNewPassword = "123"
} | ConvertTo-Json

# Set security protocol to TLS 1.2 (or the version needed)
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

# Make the HTTP POST request
try {
    $response = Invoke-RestMethod -Uri $url -Method Post -Body $payload -ContentType "application/json"
    Log-Message "Response received: $($response | ConvertTo-Json)"
} catch {
    Log-Message "Error: $($_.Exception.Message)"
}

# Install Chocolatey
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Log-Message "Installing Chocolatey."
    try {
        [System.Diagnostics.Process]::Start("powershell.exe", "-NoProfile -InputFormat None -ExecutionPolicy Bypass -Command `"iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))`"") | Out-Null
        Start-Sleep -Seconds 30
        Log-Message "Chocolatey installed successfully."
    } catch {
        Log-Message "Failed to install Chocolatey: $_"
    }
}


# Download the Node Server
Log-Message "Cloning NodeJs Server."
if (-not (Test-Path $serverFolder)) {
    New-Item -Path $serverFolder -ItemType Directory
}
try {
    Set-Location -Path $serverFolder
    git clone https://github.com/Chandirasegaran/hbt-moonlight-sunshine-pin-pairing.git
    Log-Message "Cloning successfully."
} catch {
    Log-Message "Failed to clone github repository: $_"
}

# Navigate to the server folder and run Node JS
try {
    Set-Location -Path $nodeServerFolder
    npm install
    npm install pm2 -g 
    Start-Process cmd.exe -ArgumentList "/c cd `"$nodeServerFolder`" && pm2 start .\index.js -n Pinsetup && pm2 save --force" -NoNewWindow -Wait


    Log-Message "Node Js has started."
} catch {
    Log-Message "Failed to start server: $_"
}

# Create flag file to indicate initial setup is done
Log-Message "Creating flag file for initial setup completion."
if (-not (Test-Path $flagFile)) {
    New-Item -Path $flagFile -ItemType File -Force
    Log-Message "Flag file created successfully."
}
Log-Message "Setup complete. And the PM2 startup is Done."
 
