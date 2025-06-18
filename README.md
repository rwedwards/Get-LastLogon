
# Get-LastLogon

A PowerShell function to retrieve the most recent user logon across local or remote Windows systems. Compatible with both modern (Vista SP1 and newer) and legacy (pre-Vista) operating systems.

## Features

- Detects last logged-on user via WMI or file system (based on OS version)
- Compatible with local and remote systems
- Supports filtering known service SIDs
- Converts SID to NT Account name
- Indicates if the user profile is currently loaded
- Provides fallback logic for legacy OS profiles via `ntuser.dat.LOG` analysis
- Outputs structured objects suitable for reporting

## 🖥Usage

```powershell
Get-LastLogon [-ComputerName] <String[]> [-FilterSID <String>] [-WQLFilter <String>]
```

### Parameters

| Name         | Description                                                                                  | Default                  |
|--------------|----------------------------------------------------------------------------------------------|--------------------------|
| `ComputerName` | One or more computer names to query. Can also be piped.                                      | `$env:COMPUTERNAME`      |
| `FilterSID`    | A SID to exclude from results. Useful for omitting known service accounts.                  | *(optional)*             |
| `WQLFilter`    | Custom WQL filter for the `Win32_UserProfile` query on newer OS versions.                   | `"NOT SID = 'S-1-5-18' AND NOT SID = 'S-1-5-19' AND NOT SID = 'S-1-5-20'"` |

## Examples

```powershell
# Run on local machine
Get-LastLogon

# Run against multiple computers
Get-LastLogon -ComputerName 'PC01', 'PC02'

# Run against computers listed in a file, excluding a service account SID
Get-LastLogon -ComputerName (Get-Content .\computers.txt) -FilterSID 'S-1-5-21-0000000000-0000000000-0000000000-500'
```

## Output

Returns a custom object for each computer with the following properties:

- `Computer`: Name of the queried computer
- `User`: Resolved NT Account name of the last logged-on user
- `SID`: Security Identifier of the user
- `Time`: Last use or logon time
- `CurrentlyLoggedOn`: Boolean or status indicating if the profile is loaded

## Example Output

```text
Computer : SERVER01
User     : CONTOSO\jsmith
SID      : S-1-5-21-...
Time     : 6/18/2025 9:45:12 AM
CurrentlyLoggedOn : True
```

## ⚠Notes

- Requires administrative permissions on remote computers.
- For legacy systems, profile detection is based on file metadata and may be less accurate.
- Translation of SIDs may fail for deleted or unmapped accounts; fallback to raw SID is used in such cases.

## Tested On

- Windows 10, Windows 11
- Windows Server 2012 R2, 2016, 2019, 2022
- Legacy support tested on Windows XP/2003 (with limitations)

##  License

This script is provided as-is under the MIT License. Contributions welcome.
