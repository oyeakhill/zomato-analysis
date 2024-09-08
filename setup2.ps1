# Define installation directory and log file path
$InstallDir = "C:\CloudRigSetup"
$LogFilePath = "C:\Program Files\setup-log.txt"
$RestartFlagPath = "$InstallDir\restart-flag.txt"
#$CounterFilePath = "$InstallDir\instance-counter.txt"  # File to keep track of instance numbers
$SetupCompleteFlagPath = "$InstallDir\setup-complete-flag.txt"  # Flag to indicate if setup is already complete
$instanceId = (Invoke-RestMethod -Uri http://169.254.169.254/latest/meta-data/instance-id)

# Function to log messages
function Log-Message {
    param (
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"
    $logEntry | Out-File -FilePath $LogFilePath -Append
}

# Log starting the script
Log-Message "Script started."

# Check if setup is already complete
if (Test-Path -Path $SetupCompleteFlagPath) {
    Log-Message "Setup is already complete. Skipping to password change."
    
    # Generate a random 10-character password
    function Generate-RandomPassword {
        $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_-+=<>?'
        $password = -join ((65..90) + (97..122) + (48..57) + (33..47) | Get-Random -Count 10 | ForEach-Object {[char]$_})
        return $password
    }

    # Generate the password and store it in $GamerPassword
    $GamerPassword = Generate-RandomPassword

    # Define the API endpoint and JSON payload
    $endpoint = "https://password-store-aws.onrender.com/store-data"
    $body = @{
        instanceId = $instanceId  # Use dynamically generated instance name
        password = $GamerPassword
    }
    $jsonBody = $body | ConvertTo-Json
    $headers = @{
        "Content-Type" = "application/json"
    }

    # Send the POST request to store the password and instance name
    try {
        $response = Invoke-RestMethod -Uri $endpoint -Method Post -Body $jsonBody -Headers $headers
        Log-Message "Password posted successfully for instance ${instanceId}. Setting Gamer password now."
        Log-Message $instanceId
        Log-Message "Gamer Password $GamerPassword"
        # Set the password for the Gamer account
        $securePassword = ConvertTo-SecureString $GamerPassword -AsPlainText -Force
        Set-LocalUser -Name "Gamer" -Password $securePassword
        Log-Message "Password set for Gamer account."
    } catch {
        Log-Message "An error occurred while posting the data for instance ${instanceId}: $_.Exception.Message"
        Pause
    }

    # Log script completion
    Log-Message "Password change complete for instance ${instanceId}."

    # Exit the script
    exit 0
}

# Check if the script has been restarted already
if (Test-Path -Path $RestartFlagPath) {
    Log-Message "Restart flag detected. Continuing script after restart."
    Remove-Item -Path $RestartFlagPath -Force
} else {
    # Ensure the script is running as administrator
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Log-Message "The script is not running as Administrator. Restarting with elevated privileges..."
        
        # Create a restart flag
        New-Item -Path $RestartFlagPath -ItemType File -Force | Out-Null
        
        Start-Process powershell "-File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
}

# Create setup directory
try {
    New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
    Log-Message "Setup directory created at $InstallDir."
} catch {
    Log-Message "Failed to create setup directory. Error: $_"
    exit 1
}

# Initialize or read instance number
#if (-not (Test-Path -Path $CounterFilePath)) {
    # If the file does not exist, create it and set the initial instance number to 1
#    1 | Out-File -FilePath $CounterFilePath
 #   $instanceNumber = 1
 #   Log-Message "Counter file not found. Starting with instance number $instanceNumber."
#} else {
   # Read the last instance number from the file
 #   $instanceNumber = Get-Content -Path $CounterFilePath
 #   $instanceNumber = [int]$instanceNumber + 1
 #   Log-Message "Read last instance number from counter file. Incrementing to $instanceNumber."
#}

# Save the new instance number back to the file
#$instanceNumber | Out-File -FilePath $CounterFilePath -Force

# Define the instance name using the incremented number
#$instanceId = "hb_gaming_$instanceNumber"  # Unique instance name based on the incremented number

# Install Chocolatey if not installed
if (-not (Get-Command choco.exe -ErrorAction SilentlyContinue)) {
    try {
        Log-Message "Chocolatey not found. Installing Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force;
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
        iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
        Log-Message "Chocolatey installed."
    } catch {
        Log-Message "Chocolatey installation failed. Error: $_"
        exit 1
    }
}

# Install necessary software using Chocolatey
try {
    Log-Message "Installing Node.js, AWS CLI, Git, and Nginx using Chocolatey..."
    choco install -y nodejs awscli git nginx | Out-Null
    Log-Message "Node.js, AWS CLI, Git, and Nginx installed."
} catch {
    Log-Message "Failed to install one or more applications via Chocolatey. Error: $_"
}

$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::Machine)

# Install Steam
try {
    Log-Message "Installing Steam..."
    Invoke-WebRequest -Uri "https://cdn.cloudflare.steamstatic.com/client/installer/SteamSetup.exe" -OutFile "$InstallDir\SteamSetup.exe"
    Start-Process "$InstallDir\SteamSetup.exe" -ArgumentList "/silent /install /S" -Wait
    Log-Message "Steam installed successfully."
} catch {
    Log-Message "Steam installation failed. Error: $_"
}

# Install Sunshine
try {
    Log-Message "Installing Sunshine..."
    Invoke-WebRequest -Uri "https://github.com/LizardByte/Sunshine/releases/download/v0.23.1/sunshine-windows-installer.exe" -OutFile "$InstallDir\sunshine-installer.exe"
    Start-Process "$InstallDir\sunshine-installer.exe" -ArgumentList '/SILENT /install /S' -Wait
    Log-Message "Sunshine installed successfully."
} catch {
    Log-Message "Sunshine installation failed. Error: $_"
}

# Configure Sunshine settings for Moonlight compatibility
try {
    Log-Message "Configuring Sunshine settings for Moonlight compatibility..."
    $sunshineConfigPath = "C:\Program Files\Sunshine\config\sunshine.conf"
    $sunshineConfig = Get-Content $sunshineConfigPath
    $sunshineConfig = $sunshineConfig -replace "^video = \{\s*$", "video = {`r`n  hevc_mode = 1`r`n  hevc_level = 4`r`n  hevc_tier = high"
    $sunshineConfig = $sunshineConfig -replace "^nvenc = \{\s*$", "nvenc = {`r`n  rc = vbr_hq`r`n  preset = slow"
    Set-Content -Path $sunshineConfigPath -Value $sunshineConfig
    Log-Message "Sunshine settings configured for Moonlight compatibility."
} catch {
    Log-Message "Failed to configure Sunshine settings for Moonlight compatibility. Error: $_"
}

# Download NVIDIA drivers using a manual method
try {
    Log-Message "Downloading NVIDIA drivers..."
    $request = [System.Net.WebRequest]::Create("https://github.com/Chandirasegaran/node-react-learn/releases/download/n2.0/NVIDIA.zip")
    $response = $request.GetResponse()
    $stream = $response.GetResponseStream()
    $outputFile = "$InstallDir\nvidia-drivers.zip"
    $file = New-Object System.IO.FileStream($outputFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
    
    $buffer = New-Object byte[] 4096
    while (($bytesRead = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $file.Write($buffer, 0, $bytesRead)
    }

    $file.Close()
    $stream.Close()
    $response.Close()
    Log-Message "NVIDIA drivers downloaded."

    Log-Message "Installing NVIDIA drivers silently..."
    Expand-Archive -Path "$InstallDir\nvidia-drivers.zip" -DestinationPath "$InstallDir\nvidia-drivers"
    Log-Message "Nvidia drivers Extracted and Installation Started."
    Start-Process "$InstallDir\nvidia-drivers\setup.exe" -ArgumentList '-s -n' -Wait
    Log-Message "Nvidia drivers installed."
} catch {
    Log-Message "NVIDIA drivers installation failed. Error: $_"
}

# Server Setup
try {
    Log-Message "Setting up server..."
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::Machine)

    # Download the server zip file from the specified URL
    Invoke-WebRequest -Uri "https://github.com/Chandirasegaran/node-react-learn/releases/download/server1.0/server.zip" -OutFile "$InstallDir\server.zip"

    # Extract the server.zip file to the specified directory
    Expand-Archive -Path "$InstallDir\server.zip" -DestinationPath "$InstallDir\server" -Force

    # Change directory to the server folder
    Set-Location -Path "$InstallDir\server"

    # Install npm dependencies
    npm install | Out-Null
    Log-Message "Server setup completed successfully."
} catch {
    Log-Message "Server setup failed. Error: $_"
}

# Install AWS CDK
try {
    Log-Message "Installing AWS CDK..."
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::Machine)

    npm install -g aws-cdk | Out-Null
    Log-Message "AWS CDK installed successfully."
} catch {
    Log-Message "AWS CDK installation failed. Error: $_"
}

# Configure Windows Firewall rules for Sunshine
try {
    Log-Message "Configuring Windows Firewall rules for Sunshine..."
    New-NetFirewallRule -DisplayName "Sunshine TCP Inbound" -Direction Inbound -Protocol TCP -LocalPort 47984 -Action Allow
    New-NetFirewallRule -DisplayName "Sunshine UDP Inbound" -Direction Inbound -Protocol UDP -LocalPort 47998 -Action Allow
    New-NetFirewallRule -DisplayName "Sunshine TCP Outbound" -Direction Outbound -Protocol TCP -LocalPort 47984 -Action Allow
    New-NetFirewallRule -DisplayName "Sunshine UDP Outbound" -Direction Outbound -Protocol UDP -LocalPort 47998 -Action Allow
    New-NetFirewallRule -DisplayName "Sunshine Outbound Ports" -Direction Outbound -Protocol TCP -LocalPort 45000-50000 -Action Allow
    Log-Message "Windows Firewall rules configured for Sunshine."
} catch {
    Log-Message "Failed to configure Windows Firewall rules. Error: $_"
}

# Install and start Node.js server using PM2
try {
    Log-Message "Installing and starting Node.js server using PM2..."

    $env:Path += ";C:\Program Files\nodejs;C:\Users\Administrator\AppData\Roaming\npm"

    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::Machine)

    npm install pm2 -g | Out-Null

    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::Machine)

    pm2 start C:\CloudRigSetup\server\server.js
    pm2 save  # Save PM2 process list and re-deploy on startup
    Log-Message "Node.js server started using PM2."
} catch {
    Log-Message "Node.js server setup failed. Error: $_"
}

# Configure Nginx as reverse proxy
try {
    Log-Message "Configuring Nginx as reverse proxy..."
    Stop-Process -Name nginx -Force -ErrorAction SilentlyContinue
    Start-Process "C:\tools\nginx-1.27.1\nginx.exe"
    Log-Message "Nginx configured as reverse proxy."
} catch {
    Log-Message "Nginx configuration failed. Error: $_"
}

# Create a new user account named "Gamer"
try {
    Log-Message "Creating Gamer user account..."
    $gamerPassword = ConvertTo-SecureString "Password@123" -AsPlainText -Force
    New-LocalUser -Name "Gamer" -Password $gamerPassword -FullName "Gamer Account" -Description "Account for gaming purposes"
    Add-LocalGroupMember -Group "Administrators" -Member "Gamer"
    Log-Message "Gamer user account created successfully."
} catch {
    Log-Message "Failed to create Gamer user account. Error: $_"
}

# Generate a random 10-character password
function Generate-RandomPassword {
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_-+=<>?'
    $password = -join ((65..90) + (97..122) + (48..57) + (33..47) | Get-Random -Count 10 | ForEach-Object {[char]$_})
    return $password
}

# Generate the password and store it in $GamerPassword
$GamerPassword = Generate-RandomPassword

# Define the API endpoint and JSON payload
$endpoint = "https://password-store-aws.onrender.com/store-passkey"
$body = @{
    instanceId = $instanceID  # Use dynamically generated instance name
    password = $GamerPassword
}
 
$jsonBody = $body | ConvertTo-Json
$headers = @{
    "Content-Type" = "application/json"
}

# Send the POST request to store the password and instance name
try {
    $response = Invoke-RestMethod -Uri $endpoint -Method Post -Body $jsonBody -Headers $headers
    Log-Message "Password posted successfully for instance ${instanceId}. Setting Gamer password now."
    Log-Message $instanceId
    Log-Message "Gamer Password $GamerPassword"
    # Set the password for the Gamer account
    $securePassword = ConvertTo-SecureString $GamerPassword -AsPlainText -Force
    Set-LocalUser -Name "Gamer" -Password $securePassword
    Log-Message "Password set for Gamer account."
} catch {
    Log-Message "An error occurred while posting the data for instance ${instanceId}: $_.Exception.Message"
    Pause
}

# Disabling the Microsoft Basic Display Adapter and Removing the Ctrl + Alt + Del to unlock in Moonlight
try {
    Get-PnpDevice -FriendlyName "Microsoft Basic Display Adapter" | Disable-PnpDevice -Confirm:$false
    Log-Message "display disabled successfully. chandirasegaran was here"
} catch {
    Log-Message "not disabled. Error: $_"
}

# Log script completion
Log-Message "Setup complete for instance ${instanceId}. The instance is fully configured and ready."

# Create a setup complete flag
New-Item -Path $SetupCompleteFlagPath -ItemType File -Force | Out-Null
Log-Message "Setup complete flag created."

try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DisableCAD" -Value 1
    log-Message "registry updated"
} catch {
    Log-Message "registry not updated. Error: $_"
}

# Function to create a scheduled task to run the script at startup
function Set-TaskScheduler {
    param (
        [string]$ScriptPath
    )

    # Command to create the task in Task Scheduler
    $taskName = "RunScriptOnStartup"
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$ScriptPath`""
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopOnIdleEnd -StartWhenAvailable
    
    try {
        Register-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -TaskName $taskName -Settings $settings
        Log-Message "Scheduled task created to run script on startup."
    } catch {
        Log-Message "Failed to create scheduled task. Error: $_"
    }
}

# Path to this script (make sure the path is correct)
$ScriptPath = "C:\setup.ps1"  
Log-Message "Password changed."

# Call the function to create the scheduled task
Set-TaskScheduler $ScriptPath
Restart-EC2Instance -InstanceId $instanceId

