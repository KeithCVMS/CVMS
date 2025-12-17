param(
  [string]$TaskName = 'Set-WindowsTerminal-DefaultShell-to-Pwsh'
)

$ErrorActionPreference = 'Stop'

#Enhanced Logging function
invoke-expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/KeithCVMS/CVMS/main/scripts/Log.ps1" -UseBasicParsing).Content  

#Check for Root folder

$startUtc = [datetime]::UtcNow
$UserNameSetPS7 = $env:USERNAME
$RootFolder = "$env:ProgramData\CVMMPA\DefaultPS7"
New-Item -Path $RootFolder -ItemType Directory -Force | Out-Null

Start-Transcript -Path "$RootFolder\$UserNameSetPS7.log" -Append
Log ""
Log "******************************************************************************"
Log "                     Install and Default PS7 "
Log "******************************************************************************"
Log ""

$DoneKey  = 'HKCU:\Software\CVMMPA\PS7'
$DoneName = 'WindowsTerminalDefaultProfileSet'

if ((Get-ItemProperty -Path $DoneKey -Name $DoneName -ErrorAction SilentlyContinue).$DoneName -eq 1) {
    Log "user-set default already done - exiting"
	return
}

Log "Initiating PowerShell default"

try {
    $PwshPath = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
    if (-not (Test-Path $PwshPath)) { return }  # PS7 not installed yet

    $SettingsPath = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
    if (-not (Test-Path $SettingsPath)) { return } # WT settings not created yet

    $raw = Get-Content -Path $SettingsPath -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) { return }

    $settings = $raw | ConvertFrom-Json

    $profiles = $settings.profiles.list
    if (-not $profiles) { return }

    $pwshProfile = $profiles | Where-Object {
        $_.commandline -and ($_.commandline -match '\\PowerShell\\7\\pwsh\.exe')
    } | Select-Object -First 1

    if (-not $pwshProfile) { return }

	# If already set, we can remove the task and stop
    if ($settings.defaultProfile -eq $pwshProfile.guid) {
            New-Item -Path $DoneKey -Force | Out-Null
			New-ItemProperty -Path $DoneKey -Name $DoneName -Value 1 -PropertyType DWord -Force | Out-Null
			#Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        return
    }

    $settings.defaultProfile = $pwshProfile.guid
    $settings | ConvertTo-Json -Depth 50 | Set-Content -Path $SettingsPath -Encoding UTF8

    # Success -> remove task so it stops running at every login
    New-Item -Path $DoneKey -Force | Out-Null
	New-ItemProperty -Path $DoneKey -Name $DoneName -Value 1 -PropertyType DWord -Force | Out-Null
	#Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}
finally {
    # Calculate the total run time
	$stopUtc = [datetime]::UtcNow
	$runTime = $stopUTC - $startUTC
	# Format the runtime with hours, minutes, and seconds
	$runTimeFormatted = 'Duration: {0:hh} hr {0:mm} min {0:ss} sec' -f $runTime

	Log "*************************************************************"
	Log "*     PowerShell default shell complete"
	Log "*   Total Script Time: $($runTimeFormatted)"
	Log "*************************************************************"

	Stop-Transcript | Out-Null
}
