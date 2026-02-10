<#
.SYNOPSIS
Provides sequenced execution of os update, debloat and autobranding 
set by default for OOBE-only
and os update is commented out.

.DESCRIPTION

.INPUTS

.OUTPUTS

.NOTES

#>

#param(
   ## Switches to skip sequence tasks
    # [switch]$UpdateOS,
    # [switch]$DeBloat,
    # [switch]$AutoBrand,
    # [switch]$Verbose,
    # [switch]$W25H2 #true - include 25H2    false - exclude 25H2 update
#)

	#Enhanced Logging function
	invoke-expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/KeithCVMS/CVMS/main/scripts/Log.ps1" -UseBasicParsing).Content  
	#Set TimeZone in case it has been changed
	invoke-expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/KeithCVMS/CVMS/main/scripts/SetTimeZone.ps1" -UseBasicParsing).Content  
	#OOBEComplete Function
	invoke-expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/KeithCVMS/CVMS/main/scripts/Test-OOBEComplete.ps1" -UseBasicParsing).Content  

#Check for Root folder
$RootFolder = "$($Env:Programdata)\CVMMPA"
If (!(Test-Path $RootFolder)) {
		New-Item -Path "$RootFolder" -ItemType Directory
}

Start-Transcript -Path "$RootFolder\Platform-Sequence.log" -Append
Log ""
Log "******************************************************************************"
Log "                     Platform Sequence Script"
Log "******************************************************************************"
Log ""
# Log "OSUPdate:  $OSUpdate	- run OS UPdates"
# Log "DeBloat:   $DeBloat	- run Windows Debloat"
# Log "AutoBrand: $AutoBrand	- run AutoBranding"
# Log "Verbose:   $Verbose	- display start-process windows"
# Log "W25H2:     $W25H2          - include 25H2 update"
Log ""
Log "******************************************************************************"
Log ""

# If we are running as a 32-bit process on an x64 system, re-launch as a 64-bit process
if ("$env:PROCESSOR_ARCHITEW6432" -ne "ARM64") {
	if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe") {
		& "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath" 
		Exit $lastexitcode
	}
}

##Elevate to Admin if needed
If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    write-output "You didn't run this script as an Administrator. This script will self elevate to run as an Administrator and continue."
    Start-Sleep 1
    write-output "                                               3"
    Start-Sleep 1
    write-output "                                               2"
    Start-Sleep 1
    write-output "                                               1"
    Start-Sleep 1
    Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`" -WhitelistApps {1}" -f $PSCommandPath, ($WhitelistApps -join ',')) -Verb RunAs
    #Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`" -customwhitelist {1} -TasksToRemove {2}" -f $PSCommandPath, ($customwhitelist -join ','), ($TasksToRemove -join ',')) -Verb RunAs
    $args = @(
		'-NoProfile'
		'-ExecutionPolicy', 'Bypass'
		'-File', $PSCommandPath
		'customwhitelist', ($customwhitelist -join ',')
		'TasksToRemove', ($TasksToRemove -join ',')
    	'custombloatlist', ($custombloatlist -join ','))
    if ($Force) { $args += ' -Force' }
    #ignore params
		$args = @(
		'-NoProfile'
		'-ExecutionPolicy', 'Bypass'
		'-File', $PSCommandPath )
		Start-Process powershell.exe -Verb RunAs -ArgumentList $args
Exit
}

#This uses a "tag" file to determine whether the script has been run previously
#This section causes successful EXIT if the script has been previouly run in an OOBE environment 
$PSSTag = "$RootFolder\PlatformSequence.tag"

If (Test-Path $PSSTag) {
		Log "Script has already been run. Exiting"
		Add-Content -Path "$PSSTag" -Value "Script has already been run- $(get-date) - Exiting"
		Stop-Transcript
		Exit 0
	}
	Else {
		Set-Content -Path "$PSSTag" -Value "Start Script $(get-date)"
	}

#Check that we are in OOBE or Exit
$oobe = Test-OOBEComplete

if ($oobe.Success -and $oobe.IsOOBEComplete) {
    Log "OOBE is completed, bailing out without doing any configuration."
    Add-Content -Path $PSSTag -Value "Script run outside of OOBE - $(Get-Date) - $CurrProf - $UsrNm - Exiting"
    Stop-Transcript
    exit 0
}

#set powershell executable
# Try PowerShell 7 first, fallback to 5.1
if (Test-Path "C:\Program Files\PowerShell\7\pwsh.exe") {
    $PSexe = "C:\Program Files\PowerShell\7\pwsh.exe"
} else {
    $PSexe = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
}

<#
# UpdateOS processing
if ($UpdateOS) {
	Log ""
	Log "Initiating UpdateOS"

	$OSUpFolder = "$RootFolder\UpdateOS"
	If (!(Test-Path $OSUpFolder)) {
		New-Item -Path "$OSUpFolder" -ItemType Directory
		Log "The folder $OSUpFolder was successfully created."
	}

	$templateFilePath = "$OsUpFolder\UpdateOS.ps1"
	$ArgList = "-command $templateFilePath "

	Log "loading UpdateOS"
	Invoke-WebRequest `
	-Uri "https://raw.githubusercontent.com/KeithCVMS/CVMS/main/scripts/UpdateOS.ps1" `
	-OutFile $templateFilePath `
	-UseBasicParsing `
	-Headers @{"Cache-Control"="no-cache"}

	Log "Calling UpdateOS"

	#invoke-expression -Command "C:\ProgramData\CVMMPA\UpdateOS\UpdateOS.ps1"
	$proc1 = Start-Process -FilePath "$PSexe" -ArgumentList "$arglist" -WindowStyle Hidden -Passthru
	if ($proc1.WaitForExit(4500000)) {
	Log "OSUpdate exited within 75 min timeout."
	} else {
	Log "75 min Timeout reached before UpdateOS exited."
	}
	# if ($Verbose) {
		# start-process -FilePath "$PSexe" -ArgumentList "-command $templateFilePath" -Wait
	# } Else {
		# start-process -FilePath "$PSexe" -ArgumentList "-command $templateFilePath" -Wait -WindowStyle Hidden
	# }

	Log "UpdateOS Complete"
	Log ""
}

#>	
 
#DeBloat processing

#Now run debloat script
Log ""
Log "Initiating Debloat"

$DebloatFolder = "$RootFolder\Debloat"
If (!(Test-Path $DebloatFolder)) {
	New-Item -Path "$DebloatFolder" -ItemType Directory
}

Log "loading Debloat script"
$templateFilePath = "$DebloatFolder\RemoveBloat.ps1"
####-Uri "https://raw.githubusercontent.com/KeithCVMS/public/main/De-Bloat/RemoveBloat.ps1" `

Invoke-WebRequest `
-Uri "https://raw.githubusercontent.com/KeithCVMS/public/main/De-Bloat/RemoveBloat_5_3_0KH.ps1" `
-OutFile $templateFilePath `
-UseBasicParsing `
-Headers @{"Cache-Control"="no-cache"}

##Populate between the speechmarks any apps you want to whitelist, comma-separated
$arguments = ' -customwhitelist ' +
	#Microsoft package apps
	'"Microsoft.Getstarted,Microsoft.GetHelp,Microsoft.WindowsSoundRecorder' +
	',Microsoft.WindowsCamera,Microsoft.SecHealthUI,Microsoft.Todos,MicrosoftCorporationII.QuickAssist,clipchamp.clipchamp' +
	#HP package apps
	',AD2F1837.HPSupportAssistant' +
	#ASUS package apps
	',B9ECED6F.ASUSExpertWidget,B9ECED6F.ASUSPCAssistant' +
	',AppUp.IntelGraphicsExperience,AppUp.IntelManagementandSecurityStatus' +
	',DolbyLaboratories.DolbyAccess,DolbyLaboratories.DolbyDigitalPlusDecoderOEM' +
	',DrivewintechTechnologyCo.DiracAudoManager,IntelligoTechnologyInc.541271065CCE8' +
	'"' +
	' -custombloatlist ' +
	'"AD2F1837.OMENCommandCenter,Microsoft.OutlookForWindows,Microsoft.Windows.DevHome,MicrosoftTeams,Microsoft.MicrosoftStickyNotes,Microsoft.M365Companions,MSTeams' +
	'"'
	
Log "" 
Log "Arguments:$arguments"

$ArgList = "-command $templatefilepath $arguments"
Log "ArgList:$ArgList"
Log ""

Add-Content -Path "$PSSTag" -Value "invoke debloat $(get-date) $tz - $CurrProf - $UsrNm"
Log "Call Debloat and wait for completion"

# if ($Verbose) {
	# Start-Process -FilePath "$PSexe" -ArgumentList "$arglist" -Wait
# } Else {
	#Start-Process -FilePath "$PSexe" -ArgumentList "$arglist" -Wait -WindowStyle Hidden
	$proc1 = Start-Process -FilePath "$PSexe" -ArgumentList "$arglist" -WindowStyle Hidden -Passthru
	# Wait up to 15 minutes  (900000 ms) for it to exit
	if ($proc1.WaitForExit(900000)) {
	Log "Debloat exited within 15 min timeout."
	} else {
	Log "15 min Timeout reached before Debloat exited."
	}
# }

Log ""
Log "Debloat wait over - Continue processing"
Add-Content -Path "$PSSTag" -Value "After Debloat $(get-date) $tz - $CurrProf - $UsrNm"


#AutoPilot UNIBranding processing
#Run AutoPilotBranding to finish update config
Log ""
Log "Initiating APUniBranding"

$APUniBrndFldr = "$RootFolder\APUniBrand"
If (!(Test-Path $APUniBrndFldr)) {
	New-Item -Path "$APUniBrndFldr" -ItemType Directory
}

$templateFilePath = "$APUniBrndFldr\APUniBranding.zip"

Log "Load APIUniBranding folder"

Invoke-WebRequest `
	-Uri "https://raw.githubusercontent.com/KeithCVMS/CVMS/main/APUniBranding/APUniBranding.zip" `
	-OutFile $templateFilePath `
	-UseBasicParsing `
	-Headers @{"Cache-Control"="no-cache"}

Expand-Archive $templateFilePath -DestinationPath $APUniBrndFldr -Force

$ProgFilePath = "$APUniBrndFldr\AutoPilotUNIBranding.ps1"
$ArgList = "-command $ProgFilePath "
Log "ProgFilePath: $ProgFilePath"
log "APUniBrndFldr: $APUniBrndFldr"

# if ($Verbose) {
	# Log "Calling APUniBranding script verbose"
	# start-process -FilePath "$PSexe" -Wait -WorkingDirectory "$APUniBrndFldr"
	# Log "finished APUniBranding script verbose"
# } Else {
	Log "Call APUniBranding script hidden"
	#start-process -FilePath "$PSexe" -ArgumentList "$ArgList" -Wait -WindowStyle Hidden
	$proc2 = start-process -FilePath "$PSexe" -ArgumentList "$ArgList" -WindowStyle Hidden -Passthru
	# Wait up to 15 minutes  (900000 ms) for it to exit
	if ($proc2.WaitForExit(900000)) {
	Log "APUniBranding exited within 15 min timeout."
	} else {
	Log "15 min Timeout reached before APUniBranding exited."
	}

Log "finished APUniBranding script hidden"
# }

Log "APUniBranding Complete"
Log ""

Log "****************************************"
Log "PlatformSequence complete"
Log "*****************************************"

Add-Content -Path "$PSSTag" -Value "Platform Sequence Scripts Completed: $(get-date)"

# $PlatformScriptsDone = "$RootFolder\PlatformScriptsDone.tag"

# If (Test-Path $PlatformScriptsDone) {
	# remove-item $PlatformScriptsDone
# }
# set-content -path "$PlatformScriptsDone" -Value "Platform Sequence Scripts Completed: $(get-date)"

Stop-Transcript
