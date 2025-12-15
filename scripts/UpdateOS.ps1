<#PSScriptInfo

.VERSION 2.1

.GUID 07e4ef9f-8341-4dc4-bc73-fc277eb6b4e6

.AUTHOR Michael Niehaus

.COMPANYNAME Microsoft

.COPYRIGHT

.TAGS Windows AutoPilot Update OS

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES
Version 2.1:  Added -Append for Start-Transcript.  Added logic to filter out feature updates.
Version 2.0:  Restructured download and install logic
Version 1.10: Fixed AcceptEula logic.
Version 1.9:  Added -ExcludeUpdates switch.
Version 1.8:  Added logic to pass the -ExcludeDrivers switch when relaunching as 64-bit.
Version 1.7:  Switched to Windows Update COM objects.
Version 1.6:  Default to soft reboot.
Version 1.5:  Improved logging, reboot logic.
Version 1.4:  Fixed reboot logic.
Version 1.3:  Force use of Microsoft Update/WU.
Version 1.2:  Updated to work on ARM64.
Version 1.1:  Cleaned up output.
Version 1.0:  Original published version.

KH changes	added Log function
added executionpolicy to begin blok
added switch to include feature updates

#>

<#
.SYNOPSIS
Installs the latest Windows 10/11 quality updates.
.DESCRIPTION
This script uses the Windows Update COM objects to install the latest cumulative updates for Windows 10/11.
.EXAMPLE
.\UpdateOS.ps1
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $False)] [ValidateSet('Soft', 'Hard', 'None', 'Delayed')] [String] $Reboot = 'Soft',
    [Parameter(Mandatory = $False)] [Int32]  $RebootTimeout = 120,
    [Parameter(Mandatory = $False)] [switch] $ExcludeDrivers,
    [Parameter(Mandatory = $False)] [switch] $ExcludeUpdates,
    [Parameter(Mandatory = $False)] [switch] $IncludeFeatures
	
)

Process {

    # If we are running as a 32-bit process on an x64 system, re-launch as a 64-bit process
    $UOSSwitch = ""
	if ("$env:PROCESSOR_ARCHITEW6432" -ne "ARM64") {
        if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe") {
            if ($ExcludeDrivers) {
                $UOSSwitch += " -ExcludeDrivers"
			}
            if ($ExcludeUpdate) {
                $UOSSwitch += " -ExcludeUpdates"
			}
            if ($IncludeFeatures) {
                $UOSSwitch += " -IncludeFeatures"
			}
            & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath" -Reboot $Reboot -RebootTimeout $RebootTimeout "$UOSSwitch"
            # if ($ExcludeDrivers) {
				# & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath" -Reboot $Reboot -RebootTimeout $RebootTimeout -ExcludeDrivers
            # } elseif ($ExcludeUpdates) {
                # & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath" -Reboot $Reboot -RebootTimeout $RebootTimeout -ExcludeUpdates
            # } else {
                # & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath" -Reboot $Reboot -RebootTimeout $RebootTimeout
            # }
            Exit $lastexitcode
        }
    }

#Custom CVM Code
		#Set TimeZone in case it has been changed
		invoke-expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/KeithCVMS/CVMS/main/scripts/SetTimeZone.ps1" -UseBasicParsing).Content  
		#Enhanced Logging function
		invoke-expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/KeithCVMS/CVMS/main/scripts/Log.ps1" -UseBasicParsing).Content  

		# Create output folder
		
		# Get the Current start time in UTC format, so that Time Zone Changes don't affect total runtime calculation
		$startUtc = [datetime]::UtcNow

		$InstallRoot = "$($env:ProgramData)\CVMMPA"
		if (-not (Test-Path "$InstallRoot")) {
			Mkdir "$InstallRoot" -Force
		}
		
		# Start logging
		Start-Transcript "$InstallRoot\UpdateOS.log" -Append
		Log ""
		Log "*****************************************************"
		Log "********    UpdateOS 2.1 CVM.ps1					  *"
		Log "********    Rebooot:		  $Reboot       		  *"
		Log "********    RebootTimeout:   $RebootTimeout       	  *"
		Log "********    ExcludeDrivers:  $ExcludeDrivers     	  *"
		Log "********    ExcludeUpdates:  $ExcludeUpdates         *"
		Log "********    IncludeFeatures: $IncludeFeatures        *"
		Log "*****************************************************"
		Log ""
				
		#start-sleep -seconds 300

		# Creating tag file
		    $scriptstart = "Started Install $(get-date -f ""yyyy/MM/dd hh:mm:ss tt"") $($(Get-TimeZone).Id)"

		Log "***************************************"
		Log "Capture local configuration and OS information"
		#Capture organization from GrpTag.xml so that script can make CVM/MPA decisions
		[xml]$GrpTag = Get-Content "$InstallRoot\GrpTag.xml" 
		Log "DevDomain:$($GrpTag.grpTag.DevDomain)"
		Log "DevGvmt:$($GrpTag.grpTag.DevGvmt)"
		Log "DevRole:$($GrpTag.grptag.DevRole)"
		Log "DomRole:$($GrpTag.grpTag.DevDomain)$($GrpTag.grpTag.DevRole)"
		$UserDomain = $($GrpTag.grpTag.DevDomain)
		$UserRole = $($GrpTag.grptag.DevRole)
		$UserDomRole = $userDomain + $UserRole
		Log "UserDomain:$UserDomain"
		Log "UserRole:$UserRole"
		Log "UserDomRole:$UserDomRole"
		Log ""

		# Capture OsVersion information
		$ci = Get-Computerinfo
		$bldnum = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').currentbuildnumber
		$bldubr = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').ubr
		$dispver = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').displayversion

		Log "OSversion:$($ci.OsName)"
		Log "OSBuild: $dispver - $bldnum.$bldubr"
		Log ""
#End Custom Code


    # Main logic
    log "********************************"
	Log "Start the real work"
	Log ""
	$script:needReboot = $false

	#Now install OS Updates
    # Opt into Microsoft Update
    Log "Opting into Microsoft Update"
    $ServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager"
    $ServiceID = "7971f918-a847-4430-9279-4a52d1efe18d"
    $ServiceManager.AddService2($ServiceId, 7, "") | Out-Null

    # Install all available updates
    $WUDownloader = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateDownloader()
    $WUInstaller = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateInstaller()
	if ($ExcludeDrivers) {
        # Updates only
		Log "Exclude Drivers"
        $queries = @("IsInstalled=0 and Type='Software'")
    }
    elseif ($ExcludeUpdates) {
        # Drivers only
		Log "Exclude Software"
        $queries = @("IsInstalled=0 and Type='Driver'")
    } else {
        # Both
		Log "Include Drivers and Updates"
        $queries = @("IsInstalled=0 and Type='Software'", "IsInstalled=0 and Type='Driver'")
    }
    if ($IncludeFeatures) {
		Log "Include Features"
	} else {
		Log "Exclude Features"
	}

    $WUUpdates = New-Object -ComObject Microsoft.Update.UpdateColl
	$queries | ForEach-Object {
        Log "Getting $_ updates."        
        try {
            ((New-Object -ComObject Microsoft.Update.Session).CreateupdateSearcher().Search($_)).Updates | ForEach-Object {
                if (!$_.EulaAccepted) { $_.AcceptEula() }
 
                $featureUpdate = $_.Categories | Where-Object { $_.CategoryID -eq "3689BDC8-B205-4AF4-8D4A-A63924C5E9D5" }

                if (($featureUpdate) -and (!($IncludeFeatures))) {
                    Log "Skipping feature update: $($_.Title)"
                } elseif ($_.Title -match "Preview") { 
                    Log "Skipping preview update: $($_.Title)"
                } else {
                    Log "Add update: $($_.Title)"
                    [void]$WUUpdates.Add($_)
                }
            }
        } catch {
            # If this script is running during specialize, error 8024004A will happen:
            # 8024004A	Windows Update agent operations are not available while OS setup is running.
            $ts = get-date -f "yyyy/MM/dd hh:mm:ss tt"
            Write-Warning "$ts Unable to search for updates: $_"
        }
    }

    if ($WUUpdates.Count -eq 0) {
        Log "No Updates Found"
		Add-Content -Path "$($env:ProgramData)\CVMMPA\UpdateOS.tag" -Value "Finish Script $(get-date -f ""yyyy/MM/dd hh:mm:ss tt"") $($(Get-TimeZone).Id)"
		Stop-Transcript
        Exit 0
    } else {
        Log "Updates found: $($WUUpdates.count)"
		$TotUpdates = $($WUUpdates.count)
    }
    
    $CurrUpdate = 0
	foreach ($update in $WUUpdates) {
		$CurrUpdate = $CurrUpdate + 1
		Log "Update $($CurrUpdate) of $($TotUpdates)"
        $singleUpdate = New-Object -ComObject Microsoft.Update.UpdateColl
        $singleUpdate.Add($update) | Out-Null
    
        $WUDownloader = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateDownloader()
        $WUDownloader.Updates = $singleUpdate
    
        $WUInstaller = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateInstaller()
        $WUInstaller.Updates = $singleUpdate
        $WUInstaller.ForceQuiet = $true
    
        Log "Downloading update: $($update.size) : $($update.Title)"
        $Download = $WUDownloader.Download()
        Log "Download result: $($Download.ResultCode) ($($Download.HResult))"
    
        Log "Installing update: $($update.Title)"
        $Results = $WUInstaller.Install()
        Log "Install result: $($Results.ResultCode) ($($Results.HResult))"

        # result code 2 = success, see https://learn.microsoft.com/en-us/windows/win32/api/wuapi/ne-wuapi-operationresultcode

        if ($Results.RebootRequired) {
            $script:needReboot = $true
        }
    }

    # Specify return code
    if ($script:needReboot) {
        Log " Windows Update indicated that a reboot is needed."

        if ($Reboot -eq "Hard") {
            Log " Exiting with return code 1641 to indicate a hard reboot is needed."
			Add-Content -Path "$($env:ProgramData)\CVMMPA\UpdateOS.tag" -Value "Finish Script $(get-date -f ""yyyy/MM/dd hh:mm:ss tt"") $($(Get-TimeZone).Id)"
			Stop-Transcript
            Exit 1641
        }
        elseif ($Reboot -eq "Soft") {
            Log " Exiting with return code 3010 to indicate a soft reboot is needed."
			Add-Content -Path "$($env:ProgramData)\CVMMPA\UpdateOS.tag" -Value "Finish Script $(get-date -f ""yyyy/MM/dd hh:mm:ss tt"") $($(Get-TimeZone).Id)"
			Stop-Transcript
            Exit 3010
        }
        elseif ($Reboot -eq "Delayed") {
            Log " Rebooting with a $RebootTimeout second delay"
            & shutdown.exe /r /t $RebootTimeout /c "Rebooting to complete the installation of Windows updates."
			Add-Content -Path "$($env:ProgramData)\CVMMPA\UpdateOS.tag" -Value "Finish Script $(get-date -f ""yyyy/MM/dd hh:mm:ss tt"") $($(Get-TimeZone).Id)"
			Stop-Transcript
            Exit 0
        }    
    }
    else {
        Log " Windows Update indicated that no reboot is required."
    }


	$stopUtc = [datetime]::UtcNow
	$runTime = $stopUTC - $startUTC
	# Format the runtime with hours, minutes, and seconds
	$runTimeFormatted = 'Duration: {0:hh} hr {0:mm} min {0:ss} sec' -f $runTime
	Log "************************************************"
	Log "*    UpdateOS Complete"
	Log "*   Total Script Time: $($runTimeFormatted)"
	Log "************************************************"
	
	Set-Content -Path "$InstallRoot\UpdateOS.tag" -Value "$scriptstart"
	Add-Content -Path "$InstallRoot\UpdateOS.tag" -Value "Finish Script $(get-date -f ""yyyy/MM/dd hh:mm:ss tt"") $($(Get-TimeZone).Id)"

	Stop-Transcript
	
	exit 0
}
