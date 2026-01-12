<#
.SYNOPSIS
Provides sequenced execution of os update, debloat and autobranding 

.DESCRIPTION

.INPUTS

.OUTPUTS

.NOTES

#>

# param(
#    Switches to skip seqence tasks
    # [switch]$UpdateOS,
    # [switch]$DeBloat,
    # [switch]$AutoBrand,
    # [switch]$Verbose,
    # [switch]$W25H2 #true - include 25H2    false - exclude 25H2 update
# )

#Begin {
	#Enhanced Logging function
	invoke-expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/KeithCVMS/CVMS/main/scripts/Log.ps1" -UseBasicParsing).Content  

	#Set TimeZone in case it has been changed
	invoke-expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/KeithCVMS/CVMS/main/scripts/SetTimeZone.ps1" -UseBasicParsing).Content  

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

	if ("$env:PROCESSOR_ARCHITEW6432" -ne "ARM64") {
		if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe") {
			& "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath" -Reboot $Reboot -RebootTimeout $RebootTimeout
			Exit $lastexitcode
		}
	}

	#This uses a "tag" file to determine whether the script has been run previously
	#The "tag" file also provides a quick way to manually or from Intune to check for its presence on a System
	#It can be used in a similar method as the detection mechanism for Win32apps in Intune
	#This section EXITS if the script has been previouly run in a preprov environment 
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
#}

#Process {
<# 	# UpdateOS processing
	if ($UpdateOS) {
		Log ""
		Log "Initiating UpdateOS"

		$OSUpFolder = "$RootFolder\UpdateOS"
		If (!(Test-Path $OSUpFolder)) {
			New-Item -Path "$OSUpFolder" -ItemType Directory
			Log "The folder $OSUpFolder was successfully created."
		}

		$templateFilePath = "$OsUpFolder\UpdateOS.ps1"

		Log "loading UpdateOS"
		Invoke-WebRequest `
		-Uri "https://raw.githubusercontent.com/KeithCVMS/CVMS/main/scripts/UpdateOS.ps1" `
		-OutFile $templateFilePath `
		-UseBasicParsing `
		-Headers @{"Cache-Control"="no-cache"}

		Log "Calling UpdateOS"

		#invoke-expression -Command "C:\ProgramData\CVMMPA\UpdateOS\UpdateOS.ps1"
		if ($Verbose) {
			start-process -FilePath "$PSHOME\powershell.exe" -ArgumentList "-command $templateFilePath" -Wait
		} Else {
			start-process -FilePath "$PSHOME\powershell.exe" -ArgumentList "-command $templateFilePath" -Wait -WindowStyle Hidden
		}

		Log "UpdateOS Complete"
		Log ""
	}

 #>	
 
#DeBloat processing
#if ($DeBloat) {
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
		'"AD2F1837.OMENCommandCenter' +
		'"'
		
	Log "" 
	Log "Arguments:$arguments"

	$ArgList = "-command $templatefilepath $arguments"
	Log "ArgList:$ArgList"
	Log ""

	Add-Content -Path "$PSSTag" -Value "invoke debloat $(get-date) $tz - $CurrProf - $UsrNm"
	Log "Call Debloat and wait for completion"
	
	invoke-expression -Command "$templateFilePath $arguments"
	# if ($Verbose) {
		# Start-Process -FilePath "$PSHOME\powershell.exe" -ArgumentList "$arglist" -Wait
	# } Else {
		Start-Process -FilePath "$PSHOME\powershell.exe" -ArgumentList "$arglist" -Wait -WindowStyle Hidden
	# }
	
	Log ""
	Log "Debloat wait over - Continue processing"
	Add-Content -Path "$PSSTag" -Value "After Debloat $(get-date) $tz - $CurrProf - $UsrNm"
#	}


#AutoPilot UNIBranding processing
#	if ($AutoBrand) {
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
			# start-process -FilePath "$PSHOME\powershell.exe" -Wait -WorkingDirectory "$APUniBrndFldr"
			# Log "finished APUniBranding script verbose"
		# } Else {
			Log "Call APUniBranding script hidden"
			start-process -FilePath "$PSHOME\powershell.exe" -ArgumentList "$ArgList" -Wait -WindowStyle Hidden
			Log "finished APUniBranding script hidden"
		# }

		Log "APUniBranding Complete"
		Log ""
#	}
#}

#End {
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
#}