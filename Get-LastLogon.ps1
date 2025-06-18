#######################################################
#how to use
#
# Get-LastLogon -ComputerName "SRV01", "SRV02"
#
#######################################################


function Get-LastLogon {
<#
.SYNOPSIS
    Lists the last user who logged on to one or more computers.

.DESCRIPTION
    Uses CIM or file system methods (depending on OS version) to determine the last logged on user. 
    Supports filtering by SID and checking whether the user is currently logged on.

.PARAMETER ComputerName
    One or more computer names. Defaults to the local machine.

.PARAMETER FilterSID
    A specific SID to exclude from the result.

.PARAMETER WQLFilter
    Optional WQL filter for refining Win32_UserProfile queries.

.EXAMPLE
    Get-LastLogon -ComputerName 'Server01', 'Server02'

.EXAMPLE
    Get-LastLogon -ComputerName (Get-Content .\servers.txt) -FilterSID 'S-1-5-21-1234567890-1234567890-1234567890-500'
#>

    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true, Position = 0)]
        [string[]]$ComputerName = $env:COMPUTERNAME,

        [string]$FilterSID,

        [string]$WQLFilter = "NOT SID = 'S-1-5-18' AND NOT SID = 'S-1-5-19' AND NOT SID = 'S-1-5-20'"
    )

    begin {
        $originalErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'
    }

    process {
        foreach ($Computer in $ComputerName) {
            $Computer = $Computer.Trim().ToUpper()

            try {
                $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $Computer
                $buildNumber = [int]$osInfo.BuildNumber

                if ($buildNumber -ge 6001) {
                    # Modern OS (Vista SP1 and later)
                    if ($FilterSID) {
                        $WQLFilter += " AND NOT SID = '$FilterSID'"
                    }

                    $profiles = Get-CimInstance -ClassName Win32_UserProfile -Filter $WQLFilter -ComputerName $Computer
                    $lastUserProfile = $profiles | Sort-Object -Property LastUseTime -Descending | Select-Object -First 1

                    $lastLogonTime = [System.Management.ManagementDateTimeConverter]::ToDateTime($lastUserProfile.LastUseTime)
                    $sidObj = New-Object System.Security.Principal.SecurityIdentifier($lastUserProfile.SID)
                    $userName = $sidObj.Translate([System.Security.Principal.NTAccount])
                    $isLoaded = $lastUserProfile.Loaded
                }
                else {
                    # Older OS (pre-Vista)
                    $systemDrive = if ($buildNumber -eq 2195) {
                        ($osInfo.SystemDirectory)[0] + ':'
                    } else {
                        $osInfo.SystemDrive
                    }

                    $profilePath = "\\$Computer\" + $systemDrive.Replace(':', '$') + "\Documents and Settings"
                    $profiles = Get-ChildItem -Path $profilePath -Directory -ErrorAction Stop

                    $ntuserLogs = $profiles | ForEach-Object {
                        $_.GetFiles("ntuser.dat.LOG") 
                    } | Sort-Object LastWriteTime -Descending

                    function Get-ProfileInfoFromLog ($index) {
                        $log = $ntuserLogs[$index]
                        $username = ($log.DirectoryName -replace [regex]::Escape($profilePath), '').Trim('\').ToUpper()
                        $lastWriteTime = $log.LastAccessTime
                        $sddl = $log.GetAccessControl().Sddl
                        $rawSID = ($sddl -split '\(' | Where-Object { $_ -match '[0-9]\)$' })[0] -split ';'
                        $sidString = $rawSID[5].Trim(')')

                        try {
                            $sidTranslated = (New-Object System.Security.Principal.NTAccount($username)).Translate([System.Security.Principal.SecurityIdentifier])
                        } catch {
                            $sidTranslated = $sidString
                        }

                        return [PSCustomObject]@{
                            UserName   = $username
                            SID        = $sidTranslated
                            Time       = $lastWriteTime
                            SddlSID    = $sidString
                        }
                    }

                    $profileInfo = Get-ProfileInfoFromLog -index 0
                    if ($FilterSID -and $profileInfo.SID -eq $FilterSID) {
                        $profileInfo = Get-ProfileInfoFromLog -index 1
                    }

                    $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::Users, $Computer)
                    $isLoaded = $reg.GetSubKeyNames() -contains $profileInfo.SddlSID

                    try {
                        $sidObj = New-Object System.Security.Principal.SecurityIdentifier($profileInfo.SID)
                        $userName = $sidObj.Translate([System.Security.Principal.NTAccount])
                    } catch {
                        $userName = $profileInfo.UserName
                        $sidObj = $profileInfo.SID
                        $isLoaded = 'Unknown'
                    }

                    $lastLogonTime = $profileInfo.Time
                }

                [PSCustomObject]@{
                    Computer          = $Computer
                    User              = $userName
                    SID               = $sidObj
                    Time              = $lastLogonTime
                    CurrentlyLoggedOn = $isLoaded
                }

            } catch {
                Write-Warning "[$Computer] Error: $($_.Exception.Message)"
            }
        }
    }

    end {
        $ErrorActionPreference = $originalErrorActionPreference
    }
}
