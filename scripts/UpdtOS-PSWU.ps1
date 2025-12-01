<#PSScriptInfo

UpdtOS-PSWU.ps1

.VERSION 1.0
Version 1.0:  Original version. - Conceto from UPdateOS by Mniehaus, but simplified to PSWindowsUPdate directly
# Run from Shift+F10 during OOBE or potentially as platform script


#>

Begin {
    if ("$env:PROCESSOR_ARCHITEW6432" -ne "ARM64") {
        if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe") {
			& "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy bypass -NoProfile -File "$PSCommandPath" -Reboot $Reboot -RebootTimeout $RebootTimeout
			Exit $lastexitcode
        }
    }

	#Set TimeZone in case it has been changed
	invoke-expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/KeithCVMS/CVMS/main/scripts/SetTimeZone.ps1").Content  -UseBasicParsing
	#Enhanced Logging function
	invoke-expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/KeithCVMS/CVMS/main/scripts/Log.ps1").Content -UseBasicParsing


    #Create RootFolder as necessary for logging
	$RootFolder = "$($env:ProgramData)\CVMMPA"
	if (-not (Test-Path "$RootFolder")) {
        Mkdir "$RootFolder"				
    }
    
	# Create a tag file just so Intune knows this was run
	Set-Content -Path "$RootFolder\UpdtOS-PSWU.tag" -Value "Start Script $(get-date)"

    # Start logging
    Start-Transcript "$RootFolder\UpdtOS-PSWU.log" -Append
	Log "*****************************************************"
	Log "***************UpdtOS-PSWU.ps1**************************"
	Log "*****************************************************"
	Log ""
	
    $ci = Get-Computerinfo				
	Log "OSversion:$($ci.OsName)"		
	Log "OSBuild:$($ci.OsBuildNumber)"	
	Log ""					

	$ErrorActionPreference = 'Stop'
}

Process {
	Log "=== Enabling Microsoft Update via PSWindowsUpdate ==="

	# Set TLS 1.2 so Install-Module works
	try {
		[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	} catch {}

	# Ensure NuGet is available
	if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
		Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false
	}

	# Ensure PSGallery exists
	if (-not (Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue)) {
		Register-PSRepository -Default
	}

	# Install module if missing
	if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
		Install-Module -Name PSWindowsUpdate -Force -AllowClobber -Confirm:$false
	}

	# Import it
	Import-Module PSWindowsUpdate -Force

	# Register Microsoft Update if needed
	$mu = Get-WUServiceManager | Where-Object Name -eq "Microsoft Update"
	if (-not $mu) {
		Add-WUServiceManager -MicrosoftUpdate -Confirm:$false | Out-Null
		Log "Microsoft Update registered."
	} else {
		Log "Microsoft Update already registered."
	}

	Log ""
	Log "=== Installing ALL available updates ==="

	Install-WindowsUpdate -Verbose -AcceptAll -IgnoreReboot

	Log "=== Update scan/install complete ==="
}

End {
	
	Add-Content -Path "$($env:ProgramData)\CVMMPA\UpdateOS.tag" -Value "Finish Script $(get-date) "
	
	Stop-Transcript
	
    Exit 0
}
