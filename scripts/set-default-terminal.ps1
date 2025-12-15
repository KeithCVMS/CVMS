$ErrorActionPreference = 'Stop'

# If we are running as a 32-bit process on an x64 system, re-launch as a 64-bit process
if ("$env:PROCESSOR_ARCHITEW6432" -ne "ARM64") {
	if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe") {
		& "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath" -Reboot $Reboot -RebootTimeout $RebootTimeout
		Exit $lastexitcode
	}
}

#Enhanced Logging function
invoke-expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/KeithCVMS/CVMS/main/scripts/Log.ps1" -UseBasicParsing).Content  

#Check for Root folder
$RootFolder = "$($Env:Programdata)\CVMMPA\DefaultPS7"
If (!(Test-Path $RootFolder)) {
		New-Item -Path "$RootFolder" -ItemType Directory
	Log "The folder $RootFolder was successfully created."
}

$startUtc = [datetime]::UtcNow

Start-Transcript -Path "$RootFolder\$UserNameSetPS7.log" -Append
Log ""
Log "******************************************************************************"
Log "                     Default PS7 "
Log "******************************************************************************"
Log ""

Log "Initiating PowerShell default"


function Try-LoadJson($path) {
  if (-not (Test-Path $path)) { return $null }
  $raw = Get-Content -Path $path -Raw -Encoding UTF8
  if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
  return $raw | ConvertFrom-Json
}

$PwshPath = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
if (-not (Test-Path $PwshPath)) { return }

# Windows Terminal settings location (Store install)
$SettingsPath = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
$settings = Try-LoadJson $SettingsPath
if (-not $settings) { return }

# Find a profile that launches pwsh
$profiles = $settings.profiles.list
if (-not $profiles) { return }

$pwshProfile = $profiles | Where-Object {
  $_.commandline -and ($_.commandline -match '\\PowerShell\\7\\pwsh\.exe')
} | Select-Object -First 1

if (-not $pwshProfile) { return }

# Set defaultProfile to pwsh profile GUID
$settings.defaultProfile = $pwshProfile.guid

# Save back
$settings | ConvertTo-Json -Depth 50 | Set-Content -Path $SettingsPath -Encoding UTF8

# Calculate the total run time
$stopUtc = [datetime]::UtcNow
$runTime = $stopUTC - $startUTC
# Format the runtime with hours, minutes, and seconds
$runTimeFormatted = 'Duration: {0:hh} hr {0:mm} min {0:ss} sec' -f $runTime

Log "*************************************************************"
Log "*     PowerShell default shell complete"
Log "*   Total Script Time: $($runTimeFormatted)"
Log "*************************************************************"

Stop-Transcript