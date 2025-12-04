# PowerShell Logging Functions for AVD Deployments
#
# Purpose: Unified logging across PowerShell deployment scripts
# Usage: . ./logging-functions.ps1
#
# Functions:
#   Write-LogInfo()     - Log informational message
#   Write-LogSuccess()  - Log successful operation
#   Write-LogError()    - Log error message
#   Write-LogWarning()  - Log warning message
#   Write-LogSection()  - Log section header
#   Write-LogDebug()    - Log debug message
#   Start-LogFile()     - Initialize logging to file
#   Write-LogSummary()  - Print operation summary

param()

$ErrorActionPreference = "Stop"

# Global logging variables
$script:LogFile = ""
$script:LogLevel = "INFO"
$script:ScriptName = $MyInvocation.ScriptName
$script:OperationsAttempted = 0
$script:OperationsSucceeded = 0
$script:OperationsFailed = 0

# Color codes
$script:Colors = @{
    Green  = "Green"
    Red    = "Red"
    Yellow = "Yellow"
    Cyan   = "Cyan"
    Gray   = "Gray"
}

# ============================================================================
# Core Logging Functions
# ============================================================================

<#
.SYNOPSIS
    Writes an informational message
.DESCRIPTION
    Logs an informational message with timestamp
.PARAMETER Message
    The message to log
#>
function Write-LogInfo {
    param([string]$Message)

    Write-Host "ℹ $Message" -ForegroundColor $Colors.Cyan
    _WriteLogFile "INFO" $Message
}

<#
.SYNOPSIS
    Writes a success message
.DESCRIPTION
    Logs a successful operation with green checkmark
.PARAMETER Message
    The message to log
#>
function Write-LogSuccess {
    param([string]$Message)

    Write-Host "✓ $Message" -ForegroundColor $Colors.Green
    _WriteLogFile "SUCCESS" $Message
}

<#
.SYNOPSIS
    Writes an error message
.DESCRIPTION
    Logs an error message to stderr with red X
.PARAMETER Message
    The message to log
#>
function Write-LogError {
    param([string]$Message)

    Write-Host "✗ $Message" -ForegroundColor $Colors.Red -ErrorAction Continue
    [Console]::Error.WriteLine("ERROR: $Message")
    _WriteLogFile "ERROR" $Message
}

<#
.SYNOPSIS
    Writes a warning message
.DESCRIPTION
    Logs a warning message with yellow triangle
.PARAMETER Message
    The message to log
#>
function Write-LogWarning {
    param([string]$Message)

    Write-Host "⚠ $Message" -ForegroundColor $Colors.Yellow
    _WriteLogFile "WARNING" $Message
}

<#
.SYNOPSIS
    Writes a section header
.DESCRIPTION
    Logs a formatted section header
.PARAMETER Message
    The section title
#>
function Write-LogSection {
    param([string]$Message)

    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor $Colors.Cyan
    Write-Host ""
    _WriteLogFile "SECTION" $Message
}

<#
.SYNOPSIS
    Writes a debug message
.DESCRIPTION
    Logs debug message only if DEBUG mode is enabled
.PARAMETER Message
    The message to log
#>
function Write-LogDebug {
    param([string]$Message)

    if ($env:DEBUG -eq "1" -or $script:LogLevel -eq "DEBUG") {
        Write-Host "[DEBUG] $Message" -ForegroundColor $Colors.Gray
        _WriteLogFile "DEBUG" $Message
    }
}

# Internal function to write to log file
function _WriteLogFile {
    param(
        [string]$Level,
        [string]$Message
    )

    if ([string]::IsNullOrWhiteSpace($script:LogFile)) {
        return
    }

    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    "[$timestamp] $Level`: $Message" | Out-File -FilePath $script:LogFile -Append -Encoding UTF8
}

# ============================================================================
# Log File Management
# ============================================================================

<#
.SYNOPSIS
    Initializes logging to file
.DESCRIPTION
    Starts logging to a timestamped file
.PARAMETER OutputDirectory
    Directory where log file will be created
.PARAMETER ScriptName
    Name of the script (used in filename)
.EXAMPLE
    Start-LogFile -OutputDirectory "./artifacts" -ScriptName "deploy-vnet"
#>
function Start-LogFile {
    param(
        [string]$OutputDirectory = "artifacts",
        [string]$ScriptName = "deployment"
    )

    # Create directory if needed
    if (-not (Test-Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $script:LogFile = Join-Path $OutputDirectory "${ScriptName}_${timestamp}.log"

    # Write header
    $header = @"
================================================================================
Deployment Log: $ScriptName
Started: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC")
================================================================================

"@

    $header | Out-File -FilePath $script:LogFile -Encoding UTF8

    Write-LogSuccess "Logging to: $script:LogFile"
    return $script:LogFile
}

<#
.SYNOPSIS
    Gets the current log file path
.DESCRIPTION
    Returns the path to the current log file
#>
function Get-LogFile {
    return $script:LogFile
}

# ============================================================================
# Structured Output
# ============================================================================

<#
.SYNOPSIS
    Writes a key-value pair
.DESCRIPTION
    Formats and logs a key-value pair
.PARAMETER Key
    The key name
.PARAMETER Value
    The value
#>
function Write-LogKeyValue {
    param(
        [string]$Key,
        [string]$Value
    )

    $formatted = "{0,-30} : {1}" -f $Key, $Value
    Write-Host $formatted
    _WriteLogFile "KEYVAL" "$Key = $Value"
}

<#
.SYNOPSIS
    Starts a data block
.DESCRIPTION
    Writes a formatted data block header
.PARAMETER Label
    Block label
.PARAMETER Format
    Data format (json, yaml, xml, etc.)
#>
function Start-LogDataBlock {
    param(
        [string]$Label,
        [string]$Format = ""
    )

    $label_text = if ($Format) { "$Label ($Format)" } else { $Label }
    Write-Host ""
    Write-Host "--- $label_text ---" -ForegroundColor $Colors.Cyan
    _WriteLogFile "DATA_START" $label_text
}

<#
.SYNOPSIS
    Ends a data block
#>
function End-LogDataBlock {
    Write-Host "---" -ForegroundColor $Colors.Cyan
    Write-Host ""
    _WriteLogFile "DATA_END" ""
}

# ============================================================================
# Operation Tracking
# ============================================================================

<#
.SYNOPSIS
    Tracks an operation attempt
#>
function Track-Operation {
    $script:OperationsAttempted++
}

<#
.SYNOPSIS
    Tracks successful operation
#>
function Track-Success {
    $script:OperationsSucceeded++
}

<#
.SYNOPSIS
    Tracks failed operation
#>
function Track-Failure {
    $script:OperationsFailed++
}

<#
.SYNOPSIS
    Writes operation summary
.PARAMETER Section
    Summary section name
#>
function Write-LogSummary {
    param([string]$Section = "Operations")

    Write-Host ""
    Write-Host "=== $Section Summary ===" -ForegroundColor $Colors.Cyan
    Write-Host "✓ Succeeded: $script:OperationsSucceeded" -ForegroundColor $Colors.Green

    if ($script:OperationsFailed -gt 0) {
        Write-Host "✗ Failed: $script:OperationsFailed" -ForegroundColor $Colors.Red
    }

    if ($script:OperationsAttempted -gt 0) {
        $successRate = [math]::Round(($script:OperationsSucceeded / $script:OperationsAttempted) * 100, 0)
        Write-Host "Success rate: ${successRate}%" -ForegroundColor $Colors.Cyan
    }

    Write-Host ""
}

# ============================================================================
# Error Handling
# ============================================================================

<#
.SYNOPSIS
    Logs error and exits
.DESCRIPTION
    Logs an error message and terminates the script
.PARAMETER Message
    The error message
.PARAMETER ExitCode
    The exit code (default: 1)
#>
function Invoke-Exit {
    param(
        [string]$Message,
        [int]$ExitCode = 1
    )

    Write-LogError $Message
    Write-LogError "Script failed. See log for details: $script:LogFile"
    exit $ExitCode
}

<#
.SYNOPSIS
    Logs warning and continues
.DESCRIPTION
    Logs a warning but continues execution
.PARAMETER Message
    The warning message
#>
function Invoke-WarnContinue {
    param([string]$Message)

    Write-LogWarning $Message
    Write-LogWarning "Continuing anyway..."
}

# ============================================================================
# Export Functions
# ============================================================================

Export-ModuleMember -Function @(
    "Write-LogInfo",
    "Write-LogSuccess",
    "Write-LogError",
    "Write-LogWarning",
    "Write-LogSection",
    "Write-LogDebug",
    "Start-LogFile",
    "Get-LogFile",
    "Write-LogKeyValue",
    "Start-LogDataBlock",
    "End-LogDataBlock",
    "Track-Operation",
    "Track-Success",
    "Track-Failure",
    "Write-LogSummary",
    "Invoke-Exit",
    "Invoke-WarnContinue"
)
