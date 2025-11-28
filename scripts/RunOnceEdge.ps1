# Edge warm-up for force-installed PWAs
# Run at user logon (ideally first logon for that user)

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
$AppLog = "$AppFldr\$UsrNm-Run.log"

Start-Transcript -Path "$AppLog"
write-host "***********************************************************"
Log        "**********************RunOnceEdge**********************"
write-host "***********************************************************"

#now start real work

Log "Find Edge"
# 1. Find Edge
$edgePathsToTry = @(
    "$env:ProgramFiles (x86)\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
)

$EdgePath = $edgePathsToTry | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $EdgePath) {
    Log "Edge not found. Exiting warm-up script."
	Stop-Transcript
    return
}

Log "Snapshot any existing Edge processes (if any)"
# 2. Snapshot any existing Edge processes (if any)
$existingEdge = Get-Process -Name "msedge" -ErrorAction SilentlyContinue
$existingIds  = @()
if ($existingEdge) {
    $existingIds = $existingEdge.Id
}

Log "3. Start Edge minimized with a harmless URL"
# 3. Start Edge minimized with a harmless URL
$edgeArgs = "about:blank"

$startedProc = Start-Process -FilePath $EdgePath `
                             -ArgumentList $edgeArgs `
                             -WindowStyle Minimized `
                             -PassThru
Log "Started Edge (PID: $($startedProc.Id)) to initialize PWAs."

Log "4. Wait a bit to let policies apply & PWAs install"
# 4. Wait a bit to let policies apply & PWAs install
# Adjust this if you find it needs more/less time
$maxWaitSeconds = 20
Start-Sleep -Seconds $maxWaitSeconds

Log "Close Edge"
# 5. Close only the Edge processes that this script introduced
$currentEdge = Get-Process -Name "msedge" -ErrorAction SilentlyContinue
write $currentedge

if ($currentEdge) {
    # If there were no Edge processes before, we can safely kill them all
    if ($existingIds.Count -eq 0) {
        Write-Verbose "No pre-existing Edge processes; stopping all msedge instances."
		foreach ($proc in $currentEdge) {
			try {
				# Attempt graceful close
				if (-not $proc.CloseMainWindow()) {
					Write-Host "Process ID $($proc.Id) did not respond to close request."
					$proc | Stop-Process -Force -ErrorAction SilentlyContinue
				} else {
					Write-Host "Sent close request to Edge process ID $($proc.Id)."
				}
			} catch {
				Write-Host "Error closing process ID $($proc.Id): $_"
			}
		}
#		$currentEdge | Stop-Process -Force -ErrorAction SilentlyContinue
    } else {
        # Otherwise, only stop the ones that weren't there before
        $newOnes = $currentEdge | Where-Object { $existingIds -notcontains $_.Id }
        if ($newOnes) {
            Write-Verbose "Stopping newly created Edge processes (PIDs: $($newOnes.Id -join ', '))."
           foreach ($proc in $newones) {
			try {
				# Attempt graceful close
				if (-not $proc.CloseMainWindow()) {
					Write-Host "Process ID $($proc.Id) did not respond to close request."
					$proc | Stop-Process -Force -ErrorAction SilentlyContinue
				} else {
					Write-Host "Sent close request to Edge process ID $($proc.Id)."
				}
			} catch {
				Write-Host "Error closing process ID $($proc.Id): $_"
			}
		   }
#$newOnes | Stop-Process -Force -ErrorAction SilentlyContinue
        } else {
            Write-Verbose "No new Edge processes to stop."
        }
    }
}

Log "Script completed"
Stop-Transcript

return
