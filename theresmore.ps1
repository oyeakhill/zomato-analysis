# Define variables
$serverFolder = "C:\server"
$flagFile = "$serverFolder\initial_setup_done.txt"
$scriptPath = "C:\setup2.ps1" # Path for the second script
$logFile = "$serverFolder\setup2.log"
$pythonFileUrl = "https://raw.githubusercontent.com/oyeakhill/zomato-analysis/main/Pub_Mongo.py"
$pythonFilePath = "$serverFolder\Pub_Mongo.py"

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
    Log-Message "Initial setup is already done. Running FastAPI server and ngrok setup."
    # Ensure everything is installed using Pip


    Log-Message "Ensure everything is installed using Pip"
    try {
        Start-Process cmd.exe -ArgumentList "/k", "pip install fastapi uvicorn httpx requests pymongo & exit"
        Log-Message "Python and packages installation started in a new CMD window."
    } catch {
        Log-Message "Failed to install Python or packages: $_"
    }

    # Navigate to the server folder and run FastAPI server in a new CMD prompt
    Set-Location -Path $serverFolder
    try {
        Start-Process cmd.exe -ArgumentList "/k", "python -m uvicorn app:app --host 0.0.0.0 --port 8000"
        Log-Message "FastAPI server started in a new CMD window."
    } catch {
        Log-Message "Failed to start FastAPI server: $_"
    }

    # Configure and start ngrok in a new CMD prompt
    try {
        Start-Process cmd.exe -ArgumentList "/k", "ngrok config add-authtoken 2djRUHMH4eXkGdIDSFEt15N6Hzf_Mq8hmS4Hp98gncgV77D & ngrok http http://localhost:8000"
        Log-Message "ngrok configured and started in a new CMD window."
    } catch {
        Log-Message "Failed to configure or start ngrok: $_"
    }

    # Download and run the Python script
    Log-Message "Downloading Python script from $pythonFileUrl."
    try {
        Invoke-WebRequest -Uri $pythonFileUrl -OutFile $pythonFilePath
        Log-Message "Python script downloaded successfully."
        
        Log-Message "Running Python script."
        try {
            python $pythonFilePath
            Log-Message "Python script executed successfully."
        } catch {
            Log-Message "Failed to execute Python script: $_"
        }
    } catch {
        Log-Message "Failed to download Python script: $_"
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

# Install Python and packages
Log-Message "Installing Python and Python packages."
try {
    choco install -y python
    Start-Process cmd.exe -ArgumentList "/k", "python -m pip install fastapi uvicorn httpx requests pymongo & exit"
    Log-Message "Python and packages installed successfully."
} catch {
    Log-Message "Failed to install Python or packages: $_"
}

# Download the Python file
Log-Message "Downloading Python file."
if (-not (Test-Path $serverFolder)) {
    New-Item -Path $serverFolder -ItemType Directory
}
try {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/oyeakhill/zomato-analysis/main/app.py" -OutFile "$serverFolder\app.py"
    Log-Message "Python file downloaded successfully."
} catch {
    Log-Message "Failed to download Python file: $_"
}

# Navigate to the server folder and run FastAPI server in a new CMD prompt
Set-Location -Path $serverFolder
try {
    Start-Process cmd.exe -ArgumentList "/k", "python -m pip install fastapi uvicorn httpx requests pymongo & python -m uvicorn app:app --host 0.0.0.0 --port 8000"
    Log-Message "FastAPI server started in a new CMD window."
} catch {
    Log-Message "Failed to start FastAPI server: $_"
}

# Install ngrok
Log-Message "Installing ngrok."
try {
    choco install -y ngrok
    Log-Message "ngrok installed successfully."
} catch {
    Log-Message "Failed to install ngrok: $_"
}

# Configure and start ngrok in a new CMD prompt
try {
    Start-Process cmd.exe -ArgumentList "/k", "ngrok config add-authtoken 2djRUHMH4eXkGdIDSFEt15N6Hzf_Mq8hmS4Hp98gncgV77D & ngrok http http://localhost:8000"
    Log-Message "ngrok configured and started in a new CMD window."
} catch {
    Log-Message "Failed to configure or start ngrok: $_"
}

# Download and run the Python script
Log-Message "Downloading Python script from $pythonFileUrl."
try {
    Invoke-WebRequest -Uri $pythonFileUrl -OutFile $pythonFilePath
    Log-Message "Python script downloaded successfully."
    
    Log-Message "Running Python script in a new CMD window."
    try {
        # Open a new CMD window and run the Python script
        Start-Process cmd.exe -ArgumentList "/k", "python $pythonFilePath & exit"
        Log-Message "Python script executed successfully in a new CMD window."
    } catch {
        Log-Message "Failed to execute Python script in a new CMD window: $_"
    }
} catch {
    Log-Message "Failed to download Python script: $_"
}


# Create flag file to indicate initial setup is done
Log-Message "Creating flag file for initial setup completion."
if (-not (Test-Path $flagFile)) {
    New-Item -Path $flagFile -ItemType File -Force
    Log-Message "Flag file created successfully."
}

Log-Message "Setup complete. The script has been added to startup."
