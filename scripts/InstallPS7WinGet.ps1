#requires -RunAsAdministrator


$ErrorActionPreference = 'Stop'

# If we are running as a 32-bit process on an x64 system, re-launch as a 64-bit process
if ("$env:PROCESSOR_ARCHITEW6432" -ne "ARM64") {
	if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe") {
		& "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath" -Reboot $Reboot -RebootTimeout $RebootTimeout
		Exit $lastexitcode
	}
}

#Set TimeZone in case it has been changed
invoke-expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/KeithCVMS/CVMS/main/scripts/SetTimeZone.ps1" -UseBasicParsing).Content  
#Enhanced Logging function
invoke-expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/KeithCVMS/CVMS/main/scripts/Log.ps1" -UseBasicParsing).Content  

$installFolder = "$PSScriptRoot\"
Log "Install folder: $installFolder"
Set-Location -LiteralPath $PSScriptRoot

#Check for Root folder
$RootFolder = "$($Env:Programdata)\CVMMPA"
If (!(Test-Path $RootFolder)) {
		New-Item -Path "$RootFolder" -ItemType Directory
	Log "The folder $RootFolder was successfully created."
}

Start-Transcript -Path "$RootFolder\InstallPS7.log" -Append
Log ""
Log "******************************************************************************"
Log "                     InstallPS7 "
Log "******************************************************************************"
Log ""
Log ""
Log "******************************************************************************"
Log ""

$RunTag = "$RootFolder\InstallPS7.tag"

If (Test-Path $RunTag) {
	Log "InstallPS7WinGet Script has already been run. Exiting"
	Exit 0
}
Else {
	Set-Content -Path "$RunTag" -Value "Start InstallPS7WinGet.ps1 Script $(get-date -f ""yyyy/MM/dd hh:mm:ss tt"") $($(Get-TimeZone).Id)"
}

$startUtc = [datetime]::UtcNow

function Check-NuGetProvider {
	[CmdletBinding()]
	param (
		[version]$MinimumVersion = [version]'2.8.5.201'
	)
	$provider = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue |
	Sort-Object Version -Descending |
	Select-Object -First 1

	if (-not $provider) {
		Log 'NuGet Provider Package not detected, installing...'
		Install-PackageProvider -Name NuGet -Force | Out-Null
	} elseif ($provider.Version -lt $MinimumVersion) {
		Log "NuGet provider v$($provider.Version) is less than required v$MinimumVersion; updating."
		Install-PackageProvider -Name NuGet -Force | Out-Null
        
	} else {
		Log "NuGet provider meets min requirements (v:$($provider.Version))."
	}
    
}

Log "Initiating PowerShell install"
Log ""

Check-NuGetProvider 

#Log 'Installing WinGet.Client module'
Install-Module -Name Microsoft.WinGet.Client -Force -Scope AllUsers -Repository PSGallery | Out-Null
Log 'Installing Lastest Winget package and dependencies'
Repair-WinGetPackageManager -Force -Latest | Out-Null  #-Allusers not supported in System Context so was removed.
		
#Permalink for latest supported x64 version of vc_redist.x64
$VCppRedistributable_Url = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
#set temporary install file path
$VCppRedistributable_Path = Join-Path $env:TEMP 'vc_redist.x64.exe'

Invoke-WebRequest -uri $VCppRedistributable_Url -outfile $VCppRedistributable_Path -UseBasicParsing
Start-Process -FilePath $VCppRedistributable_Path -ArgumentList "/install", "/quiet", "/norestart" -Wait

#Look for Winget.exe in the C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_* Folder
$WinGetResolve = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*__8wekyb3d8bbwe\winget.exe"
Log "WinGetResolve: $WinGetResolve"
$WinGetExe = $WinGetResolve[-1].Path
Log "WinGetExe: $WinGetExe"
$WinGetVer = & "$WinGetExe" --version
Log "WinGetVer: $WingetVer"
Log "Winget version is: $WinGetVer"

Log "Using WinGet at: $WinGetExe"
		
#Cleanup VCredistrib setup file
Remove-Item $VCppRedistributable_Path -Force

$PwshPath = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
Log "PwshPath: $PwshPath"

# Install PS7 (machine scope, silent)
Log "Installing PowerShell 7..."
& "$WinGetExe" install Microsoft.PowerShell --scope machine --source winget --accept-package-agreements --accept-source-agreements --silent

Log "Sleep 5 seconds"
Start-Sleep -Seconds 5

if (-not (Test-Path $PwshPath)) {
  throw "PowerShell 7 did not install to expected path: $PwshPath"
}
Log "Installed pwsh: $PwshPath"

# 1) Set OpenSSH default shell (machine-wide)
# This makes SSH sessions default to pwsh.
Log "Setting OpenSSH DefaultShell to pwsh..."
New-Item -Path 'HKLM:\SOFTWARE\OpenSSH' -Force | Out-Null
New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name 'DefaultShell' -Value $PwshPath -PropertyType String -Force | Out-Null
# Optional: define a default option string for the shell
New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name 'DefaultShellCommandOption' -Value '-NoLogo' -PropertyType String -Force | Out-Null

# 2) Set Windows Terminal default profile (per-user)
# We create a logon scheduled task that runs in user context and edits WT settings.json if present.
$TaskName = 'Set-WindowsTerminal-DefaultShell-to-Pwsh'
$TaskScript = Join-Path $RootFolder "PS7-Intune\set-default-terminal.ps1"

Log "Staging per-user Windows Terminal default-shell script..."
New-Item -Path (Split-Path $TaskScript) -ItemType Directory -Force | Out-Null
Log "TaskScript: $Taskscript"
$ScriptUrl = "https://raw.githubusercontent.com/KeithCVMS/CVMS/main/scripts/set-default-terminal.ps1"
Log "ScriptUrl: $ScriptUrl"
Invoke-WebRequest -uri $ScriptUrl -outfile $TaskScript -UseBasicParsing

#Copy-Item -Path (Join-Path $PSScriptRoot 'set-default-terminal.ps1') -Destination $TaskScript -Force

Log "Creating scheduled task: $TaskName"
$Action  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$TaskScript`""
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Principal = New-ScheduledTaskPrincipal -GroupId 'BUILTIN\Users' -RunLevel Limited

# Replace if exists
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal | Out-Null

# Calculate the total run time
$stopUtc = [datetime]::UtcNow
$runTime = $stopUTC - $startUTC
# Format the runtime with hours, minutes, and seconds
$runTimeFormatted = 'Duration: {0:hh} hr {0:mm} min {0:ss} sec' -f $runTime

Log "*************************************************************"
Log "* PowerShell Install + default-shell configuration complete"
Log "*   Total Script Time: $($runTimeFormatted)"
Log "*************************************************************"

Add-Content -Path "$Runtag" -Value "Complete Install $(get-date -f ""yyyy/MM/dd hh:mm:ss tt"") $($(Get-TimeZone).Id)"

Stop-Transcript

exit 0
