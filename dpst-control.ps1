##########################################
# Control Intel Display Power Saving Technology (DPST)
#
# TO DO:
# - Error checking/reporting
#   - Writing registry value
#   - Saving backup file
# - Exit code to indicate success or failure
#   - e.g. If enable is requested, and already enabled, return success
#   - e.g. If enable is requested, and not enabled, enable it and return success
#   - return failure code if write is unsuccessful
#
# References:
#   - https://mikebattistablog.wordpress.com/2016/05/27/disable-intel-dpst-on-sp4/
#
##########################################

# Get command-line parameters
Param(
    [switch]$Enable,
    [switch]$Disable,
    [switch]$Debug
)

# Enforce strict mode
Set-StrictMode -Version Latest

# Stop on any error
$ErrorActionPreference = "Stop"


##########################################
### Variables

$usage = @"
Usage (must Run as Administrator):
    Get current state of DPST (default if no option is given)
        dpst-control.ps1
    Exit code:
        0:  DPST is disabled
        1:  DPST is enabled

    Enable DPST
        dpst-control.ps1 -enable

    Disable DPST
        dpst-control.ps1 -disable

    Other Options:
        -debug
            Enable debug output
"@

# Path to display adapter ClassGuid
$regBase = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'

# Name of registry key holding ftc data
$ftcName = "FeatureTestControl"


##########################################
### Functions

# Check if running as administrator
# Returns True if Admin, False if not
Function RunningAsAdmin() {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent() )
    Return $currentPrincipal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator )
}


# Locate FTC registry key
# Returns:
#   If found: Full path to registry key containing FTC
#   If not:   $false
Function LocateFTC() {
    Param(
        [parameter(Mandatory=$true)]$regPath
    )
    ForEach( $key in
        $( Get-ChildItem -ErrorAction SilentlyContinue -LiteralPath "${regPath}" |
            Where-Object { $_.Name -match '\\\d{4}$' } )
    ) {
        If( $key.GetValue( $ftcName, $null ) -ne $null ) {
            Return $key.Name
        }
    }
    Return $false
}


# Backup current value before changing it
Function BackupFTC() {
    Param(
        [parameter(Mandatory=$true)]$regPath,
        [parameter(Mandatory=$true)]$ftcValue
    )
    $bkFile = "dpst_backup-$(Get-Date -Format FileDateTime).reg"
    $r  = "Windows Registry Editor Version 5.00`n`n"
    $r += "[$($regPath)]`n"
    $r += '"FeatureTestControl"=dword:'
    $r += "$(([Convert]::ToString( $ftcValue, 16 )).PadLeft(8, '0'))`n`n"
    $r | Out-File $bkFile -NoNewLine
}


# Check if DPST is enabled
# Returns: 0: Disabled; 1: Enabled
Function DPSTEnabled() {
    Param(
        [parameter(Mandatory=$true)]$ftc,
        [parameter(Mandatory=$true)]$bitMask
    )
    $dpstState = $ftc -band $bitMask
    Write-Debug( "  State (bin): $(([Convert]::ToString( $dpstState, 2 )).PadLeft(32, '0'))" )
    If( $dpstState ) { Return 0 }
    Else             { Return 1 }
}


##########################################
### Main

If( $Debug ) {
    $DebugPreference = "Continue"   # Enable debug output
}

# Search registry for FTC entry
$ftcPath = LocateFTC -regPath ${regBase}
If( $ftcPath -eq $false ) {
    Write-Error "Cannot locate ${ftcName} in registry"
    Exit 1
}

# Indicate position of DPST bit in binary output
Write-Debug( "                        ---- DPST bit ----v" )

# Get current value from registry
$ftcCur = (Get-Item -LiteralPath "Registry::${ftcPath}").GetValue($ftcName)
Write-Debug( "Current (hex): 0x$(([Convert]::ToString( $ftcCur, 16 )))" )
Write-Debug( "Current (bin): $(([Convert]::ToString( $ftcCur, 2 )).PadLeft(32, '0'))" )

# Generate bitmask to be used for manipulating DPST bit
#   Start with 1 which sets the right-most bit to 1,
#   Then shift that bit left X number of times
#   DPST bit is the 5th bit from the right.
#   Shift 4 times since "1" is in the 1st position
$bitMask = 1 -shl 4
Write-Debug( "Bitmask (bin): $(([Convert]::ToString( $bitMask, 2 )).PadLeft(32, '0'))" )


$ftcNew = 0
$opStr = ''
# Enable DPST (to enable, DPST bit needs to be 0)
If( $Enable ) {
    $opStr = "enable"
    If( ! (DPSTEnabled -ftc $ftcCur -bitMask $bitMask) ) {
        Write-Output "DPST is currently disabled"
        # Clear DPST bit (enable DPST)
        $ftcNew = $ftcCur -band ( -bnot $bitMask )
    }
}
# Disable DPST (to disable, DPST bit needs to be 1)
ElseIf( $Disable ) {
    $opStr = "disable"
    If( (DPSTEnabled -ftc $ftcCur -bitMask $bitMask) ) {
        Write-Output "DPST is currently enabled"
        # Set DPST bit (disable DPST)
        $ftcNew = $ftcCur -bor $bitMask
    }
}
# Report on DPST state and exit
Else {
    If( (DPSTEnabled -ftc $ftcCur -bitMask $bitMask) ) {
        Write-Output "DPST is enabled"
        Exit 1
    }
    Else {
        Write-Output "DPST is disabled"
        Exit 0
    }
}

# This script must run as admin if the value is going to be overwritten
If( !(RunningAsAdmin) ) {
    Write-Error "Must run as Administrator!"
    Exit 255
}


# Write new value to registry and report results
If( $ftcNew ) {
    Write-Debug( "    New (hex): 0x$(([Convert]::ToString( $ftcNew, 16 )))" )
    Write-Debug( "    New (bin): $(([Convert]::ToString( $ftcNew, 2 )).PadLeft(32, '0'))" )

    # Backup current value
    BackupFTC -regPath $ftcPath -ftcValue $ftcCur

    # Write new value to registry
    Set-ItemProperty -Path "Registry::${ftcPath}" -Name $ftcName -Value $ftcNew | Out-Null

    Write-Output "DPST is now $($opStr)d.`n"
    Write-Warning "-> Reboot is required for changes to take effect. <-"
}
Else {
    Write-Output "DPST is already $($opStr)d"
}

