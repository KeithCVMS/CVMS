#Log function added KH
Function Log() {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$false)] [String] $message
	)

	$tz = [Regex]::Replace([System.TimeZoneInfo]::Local.StandardName, '([A-Z])\w+\s*', '$1')
	$ts = get-date -f "yyyy/MM/dd hh:mm:ss tt"
	Write-Output "$ts $tz -  $message"
}
#Log function end

	
 $CVMtz = "Mountain Standard Time"

If ($CVMtz -ieq (Get-TimeZone).Id) {
	Log "TimeZone currently set correctly:"
	(Get-TimeZone).DisplayName
}
Else { 
	Log "Current TimeZone: "
	(Get-TimeZone).DisplayName

	Log "set TimeZone to: $CVMtz"
	# Set the timezone
	Set-TimeZone -Id $CVMtz 

	Log "New TimeZone: "
	(Get-TimeZone).DisplayName
}