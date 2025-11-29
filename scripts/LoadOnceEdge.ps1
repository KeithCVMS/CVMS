#The HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce key runs a command once at the next login for that user.
#PowerShell Script
#Powershell# Ensure script runs in user context

# Deployment in Intune:

# Go to Devices → Scripts → Add.
# Upload this PowerShell script.
# Run this script using the logged-on credentials = Yes (important for HKCU).
# Assign to the target user group.

Function Log() {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$false)] [String] $message
	)

	$tz = [Regex]::Replace([System.TimeZoneInfo]::Local.StandardName, '([A-Z])\w+\s*', '$1')
	$ts = get-date -f "yyyy/MM/dd hh:mm:ss tt"
	Write-Output "$ts $tz -  $message"
}

#Create Folder
#Check root first
$PgmFldr = "C:\ProgramData\CVMMPA"
If (!(Test-Path $PgmFldr)) {
    Start-Sleep 2
    New-Item -Path "$PgmFldr" -ItemType Directory
    Log "The folder $PgmFldr was successfully created."
}

#Check app folder to create
$AppFldr = "$PgmFldr\RunOnceEdge"
If (!(Test-Path $AppFldr)) {
    Start-Sleep 2
    New-Item -Path "$AppFldr" -ItemType Directory
    Log "The folder $AppFldr was successfully created."
}

$UsrNm = $Env:UserName
$AppLog = "$AppFldr\$UsrNm-Load.log"

Start-Transcript -Path "$AppLog"
write-host "***********************************************************"
Log        "**********************LoadRunOnceEdge**********************"
write-host "***********************************************************"

#now start the real work

try {
    $scriptPath = "$AppFldr\$UsrNm-Run.ps1"		#C:\ProgramData\MyScript\DoSomething.ps1"

	Log "Load script from Github"
	#Load script from github
	Invoke-WebRequest `
	-Uri "https://raw.githubusercontent.com/KeithCVMS/CVMS/main/scripts/RunOnceEdge.ps1" `
	-OutFile $scriptPath `
	-UseBasicParsing `
	-Headers @{"Cache-Control"="no-cache"}

	Log "Add to RunOnce"
	# Add to RunOnce so it executes once at next login
    	write-host $reg-path
	$regPath = "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    Set-ItemProperty -Path $regPath -Name "MyOneTimeScript" -Value "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""

    Log "RunOnce registry entry created successfully."
}
catch {
    Log "Failed to set RunOnce entry: $_"
	Stop-Transcript
	Exit 99
}

Stop-Transcript
Exit 0