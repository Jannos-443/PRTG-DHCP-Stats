<#
    .SYNOPSIS
    Monitors DHCP Scopes (PercentageInUse, AddressesFree, AddressesInUse and ReservedAddresses)
    Monitors DHCP Failover State and Mode

    .DESCRIPTION
    Using Powershell this script checks the DHCP Scopes and DHCP Failover Sates 
    Exceptions can be made within this script by changing the variable $IgnoreScript. This way, the change applies to all PRTG sensors 
    based on this script. If exceptions have to be made on a per sensor level, the script parameter $IgnorePattern can be used.

    1. Copy this script to the PRTG probe EXE scripts folder (C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML)
    2. Place the lookup File "dhcp.failover.mode.ovl" "dhcp.failover.state.ovl" under (C:\Program Files (x86)\PRTG Network Monitor\lookups\custom)
    3. Run PRTG Lookup File Reload
    4. create a "EXE/Script Advanced" sensor. Choose this script from the dropdown and set at least:

    + Parameters: -DHCPServer %host or -DHCPServer DHCP-Server
    + Security Context: Use Windows credentials of parent device
  
    .PARAMETER DHCPServer
    The hostname or IP address of the Windows machine to be checked. Should be set to %host in the PRTG parameter configuration.

    .PARAMETER PercentageInUse
    Shows the percentage of used IP Adresses per scope. 
    - Default is $true

    .PARAMETER CheckFailOver
    Shows DHCP Failover State and Mode. 
    - Default is $false

    .PARAMETER AddressesFree
    Shows the Free Addresses per scope. 
    - Default is $false

    .PARAMETER AddressesInUse
    Shows the Addresses in Use per scope. 
    - Default is $false

    .PARAMETER ReservedAddress
    Shows the Reserved Addresses per scope.
    - Default is $false

    .PARAMETER IgnorePattern
    Regular expression to describe the DHCP Scope ID for Exampe "192.168.2.0"
     
      Example: ^(192.168.2.0|192.168.3.0)$

      Example2: ^(192.168.*|10.10.10.1)$ excludes all 192.168. subnets 

    #https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_regular_expressions?view=powershell-7.1

    .EXAMPLE
    Sample call from PRTG
    PRTG-DHCP-Stats.ps1 -DHCPServer "DHCP-Sever.contorso.com" -CheckFailOver -AddressesFree

    .NOTES
    This script is based on the following script https://github.com/sredlin/PRTG/tree/master/DHCP%20Scope

    Author:  Jannos-443
    https://github.com/Jannos-443/PRTG-DHCP-Stats
#>
param(
[Parameter(Mandatory)] [string]$DHCPServer = $null,
[switch]$PercentageInUse = $true,
[switch]$CheckFailOver = $false,
[switch]$AddressesFree = $false,
[switch]$AddressesInUse = $false,
[switch]$ReservedAddress = $false,
[string]$IgnorePattern = ""
)

#Catch all unhandled Errors
trap{
    Write-Error $_.ToString()
    Write-Error $_.ScriptStackTrace

    Write-Output "<prtg>"
    Write-Output " <error>1</error>"
    Write-Output " <text>$($_.ToString())</text>"
    Write-Output "</prtg>"
    Exit
}

#get Scope statistics
$dhcpScopeStats = Get-DhcpServerv4ScopeStatistics -ComputerName $DHCPServer

#remove excluded Scopes
# hardcoded list that applies to all hosts
$IgnoreScript = '^(TestIgnore)$' 

#Remove Ignored
if ($IgnorePattern -ne "") {
    $dhcpScopeStats = $dhcpScopeStats | where {$_.ScopeID -notmatch $IgnorePattern}  
}

if ($IgnoreScript -ne "") {
    $dhcpScopeStats = $dhcpScopeStats | where {$_.ScopeID -notmatch $IgnoreScript}  
}

$xmlOutput = '<prtg>'

#Check Scope state for each Scope
foreach ($scope in $dhcpScopeStats)
{
    if($PercentageInUse){
        $xmlOutput = $xmlOutput + "<result>
        <channel>Scope: $($scope.ScopeId) -PercentageInUse</channel>
        <value>$([math]::Round($scope.PercentageInUse))</value>
        <unit>Percent</unit>
        <limitmode>1</limitmode>
        <LimitMaxError>95</LimitMaxError>
        <LimitMaxWarning>90</LimitMaxWarning>
        <LimitErrorMsg>DHCP Scope is over 95%</LimitErrorMsg>
        <LimitWarningMsg>DHCP Scope is over 90%</LimitWarningMsg>
        </result>"
    }
    if($AddressesFree){
        $xmlOutput = $xmlOutput + "<result>
        <channel>Scope: $($scope.ScopeId)  -AddressesFree</channel>
        <unit>Custom</unit>
        <customUnit>IP</customUnit>
        <mode>Absolute</mode>
        <showChart>1</showChart>
        <showTable>1</showTable>
        <float>0</float>
        <value>  $($scope.AddressesFree) </value>                           
        </result>"
    }
    if($AddressesInUse){
        $xmlOutput = $xmlOutput + "<result>
        <channel>Scope:  $($scope.ScopeId)  -AddressesInUse</channel>
        <unit>Custom</unit>
        <customUnit>IP</customUnit>
        <mode>Absolute</mode>
        <showChart>1</showChart>
        <showTable>1</showTable>
        <float>0</float>
        <value>  $($scope.AddressesInUse) </value>
        </result>"
    }
    if($ReservedAddress){
        $xmlOutput = $xmlOutput + "<result>
        <channel>Scope: $($scope.ScopeId)  -ReservedAddress</channel>
        <unit>Custom</unit>
        <customUnit>IP</customUnit>
        <mode>Absolute</mode
        ><showChart>1</showChart>
        <showTable>1</showTable>
        <float>0</float>
        <value> $($scope.ReservedAddress) </value>
        </result>"
    }
    
}


if($CheckFailOver)
    {

    #Check FailOver state
    $DhcpFailOver = Get-DhcpServerv4Failover -ComputerName $DHCPServer
 

    #DHCP States:
    #1 = Normal
    #2 = Communication interrupted
    #3 = Partner Down
    switch ($DhcpFailOver.state)
    {
        'Normal' { $dhcpstate = 1 }
        'Communication interrupted' { $dhcpstate = 2}
        'CommunicationInterrupted' { $dhcpstate = 2}
        'Partner Down' { $dhcpstate = 3}
        default { $dhcpstate = 0 }
    }


    #DHCP Modes: 
    #1 = HotStandby
    #2 = LoadBalance
    switch ($DhcpFailOver.mode)
    {
        'HotStandby' { $dhcpmode = 1 }
        'LoadBalance' { $dhcpmode = 2}
        default { $dhcpmode = 0 }
    }



    $xmlOutput = $xmlOutput + "<result>        
            <channel>DHCP Failover Mode</channel>
            <value>$($dhcpmode)</value>
            <ValueLookup>dhcp.failover.mode</ValueLookup>
        </result>
        <result>
            <channel>DHCP Failover State</channel>
            <value>$($dhcpstate)</value>
            <ValueLookup>dhcp.failover.state</ValueLookup>
        </result>
    "

    }

#finish Script - Write Output
$xmlOutput = $xmlOutput + "</prtg>"

$xmlOutput
