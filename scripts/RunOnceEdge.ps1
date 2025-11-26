Here’s a safe, working method to make a script run once at user login using Microsoft Intune.
Intune’s built‑in PowerShell script deployment runs once per user/device by default, but if you specifically want RunOnce at login, you can leverage the Windows RunOnce registry key or a first‑run flag file.

Approach 1 – Using the RunOnce Registry Key
The HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce key runs a command once at the next login for that user.
PowerShell Script
Powershell# Ensure script runs in user context
try {
    $scriptPath = "C:\ProgramData\MyScript\DoSomething.ps1"

    # Create folder and sample script if not exists
    if (-not (Test-Path "C:\ProgramData\MyScript")) {
        New-Item -Path "C:\ProgramData\MyScript" -ItemType Directory -Force | Out-Null
    }

    # Example payload script
    @'
Write-Output "Hello, this ran once at login!"
# Your actual commands go here
'@ | Set-Content -Path $scriptPath -Encoding UTF8

    # Add to RunOnce so it executes once at next login
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    Set-ItemProperty -Path $regPath -Name "MyOneTimeScript" -Value "powershell.exe -ExecutionPolicy Bypass -File `"$scriptPath`""

    Write-Output "RunOnce registry entry created successfully."
}
catch {
    Write-Error "Failed to set RunOnce entry: $_"
}

Deployment in Intune:

Go to Devices → Scripts → Add.
Upload this PowerShell script.
Run this script using the logged-on credentials = Yes (important for HKCU).
Assign to the target user group.


Approach 2 – Using a First‑Run Flag File
If you want the script to run at every login until it succeeds once, you can check for a marker file.
Powershell$flagFile = "$env:LOCALAPPDATA\MyScriptRan.flag"

if (-not (Test-Path $flagFile)) {
    try {
        # Your one-time commands here
        Write-Output "Running one-time setup..."

        # Create flag so it won't run again
        New-Item -Path $flagFile -ItemType File -Force | Out-Null
    }
    catch {
        Write-Error "Error running one-time script: $_"
    }
}

Deploy this as a logon script via Intune (e.g., using a scheduled task or Win32 app wrapper) so it checks each login but only runs once.

Key Notes

RunOnce is per-user; if multiple users log in, it will run once for each.
If you need per-device once, store the flag in a system-wide location like C:\ProgramData.
Intune’s native PowerShell script deployment already runs once unless you wrap it in a scheduled task for recurring execution.
For recurring at login but still only once per user, combine a logon trigger with a flag file.


If you want, I can give you a ready-to-import Intune Win32 package that sets up a RunOnce entry for your script so it’s fully automated.
Do you want me to prepare that?
