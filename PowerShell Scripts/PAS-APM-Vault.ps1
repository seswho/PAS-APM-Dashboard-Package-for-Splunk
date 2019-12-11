Function Get_Service_Info {
    param($monType, $svcName, $HostName, $Version, $DateTime, $logSrv, $logPort)

    $MonitorType = "ApplicationMonitor"
    $ServiceName = Get-Service $svcName -ErrorAction SilentlyContinue | Format-Table -HideTableHeaders Name | Out-String
    if ($ServiceName.Length -gt 0) {
        $ServiceStatus = Get-Service $svcName | Format-Table -HideTableHeaders Status | Out-String
            If ($ServiceStatus -like "*Running*") { $ServiceStatusNumeric = 1 } else { $ServiceStatusNumeric = 0 }
        if ($svcName -eq "CyberArk Vault Disaster Recovery" -or $svcName -eq "PrivateArk Server" ) {
			if ($svcName -eq "CyberArk Vault Disaster Recovery") {
				$regSrc = "*CyberArk Vault Disaster Recovery*"
			} else {
				$regSrc = "*CyberArk Digital Vault*"
			}
            $SoftwareName = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object DisplayName -like $regSrc | Select-Object DisplayName | Select -first 1 | Format-Table -HideTableHeaders | Out-String
            $SoftwareVersion = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object DisplayName -like $regSrc | Select-Object DisplayVersion | Select -first 1 | Format-Table -HideTableHeaders | Out-String
            $syslogoutput = "<5>1 $DateTime $HostName CEF:0|CyberArk|$MonitorType|$Version|$HostName|$ServiceName|$ServiceStatus|$ServiceStatusNumeric|$SoftwareName|$SoftwareVersion"

        } else {
            $syslogoutput = "<5>1 $DateTime $HostName CEF:0|CyberArk|$MonitorType|$Version|$HostName|$ServiceName|$ServiceStatus|$ServiceStatusNumeric"
        }
        Send_Syslog -syslogMsg $syslogoutput -syslogSrv $logSrv -syslogPort $logPort
    }
}

Function Send_Syslog {
    param($syslogMsg, $syslogSrv, $syslogPort)

    #cleanup command to remove new lines and carriage returns
    $syslogoutputclean = $syslogMsg -replace "`n|`r"
    $syslogoutputclean | ConvertTo-Json
    #send syslog to SIEM
    $UDPCLient = New-Object System.Net.Sockets.UdpClient
    $UDPCLient.Connect($syslogSrv, $syslogPort)
    $Encoding = [System.Text.Encoding]::ASCII
    $ByteSyslogMessage = $Encoding.GetBytes(''+$syslogoutputclean+'')
    $UDPCLient.Send($ByteSyslogMessage, $ByteSyslogMessage.Length)
}

#Service Status Check for Component Server
$Version = "1.0.0001"
$compName = "$env:computername"
$Date = Get-Date
$Date_Time = $DATE.ToString("yyyy-MM-ddTHH:mm:ssZ")

# syslog/SIEM server info
$PORT = 51444
# chage SYSLOGSERVER to the IP Address of your SIEM
$SYSLOGSERVER="1.1.1.1"

# Service array for the vault servers, add services as required
$svcArray = @("CyberArk Vault Disaster Recovery", "PrivateArk Server", "PrivateArk Database", "CyberArk Logic Container", "PrivateArk Remote Control Agent", "Cyber-Ark Event Notification Engine")

# Loop through the array of services to get info on them
foreach($svc in $svcArray) {
    Get_Service_Info -monType "ApplicationMonitor" -svcName $svc -HostName $compName -Version $ver -DateTime $Date_Time -logSrv $SYSLOGSERVER -logPort $PORT
}

#OS System Information
$MonitorType = "OSMonitor"
$OSName = (Get-WmiObject Win32_OperatingSystem).Caption | Out-String
$OSVersion = (Get-WmiObject Win32_OperatingSystem).Version | Out-String
$OSServPack = (Get-WmiObject Win32_OperatingSystem).ServicePackMajorVersion | Out-String
$OSArchitecture = (Get-WmiObject Win32_OperatingSystem).OSArchitecture | Out-String
$syslogoutput = "<5>1 $DateTime $compName CEF:0|CyberArk|$MonitorType|$ver|$compName|$OSName|$OSVersion|$OSServPack|$OSArchitecture"
Send_Syslog -syslogMsg $syslogoutput -syslogSrv $SYSLOGSERVER -syslogPort $PORT
