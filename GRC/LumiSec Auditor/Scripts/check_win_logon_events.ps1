# SCRIPT_NAME: check_win_logon_events.ps1
# CONTROL_ID: C-312
# Author : Mostafa Essam (0xMOSTA)
# This script checks one of the most fundamental audit settings:
# Are we logging both successful and failed logon attempts?
# This is critical for tracking unauthorized access attempts (failures)
# and successful intrusions (success).

param (
    # Allow the Control ID to be passed in from the agent's job.
    [string]$ControlID = "C-312" 
)

# --- Standard Functions ---

function Get-Timestamp { 
    # Helper to get a standardized ISO 8601 timestamp (UTC).
    return (Get-Date).ToUniversalTime().ToString("o") 
}

# --- Main Logic ---

# 1. Set up the JSON payload.
# We default to 'Non-Compliant' because if anything fails or isn't set,
# it's not compliant.
$result = @{
    control_id = $ControlID
    hostname = $env:COMPUTERNAME
    status = "Non-Compliant"
    evidence = ""
    timestamp = (Get-Timestamp)
}

try {
    # 2. Get the current audit policy for the "Logon/Logoff" category.
    # We use auditpol, parse its CSV output, and find the specific "Logon" subcategory.
    $policy = (auditpol /get /category:"Logon/Logoff" /r | ConvertFrom-Csv | Where-Object { $_.'Subcategory Name' -eq "Logon" })[0]
    $inclusionSetting = $policy.'Inclusion Setting'

    # 3. Determine the result.
    # The requirement is to log *both* success and failure.
    if ($inclusionSetting -like "*Success*" -and $inclusionSetting -like "*Failure*") {
        $result.status = "Compliant"
        $result.evidence = "Logon events auditing is set to 'Success and Failure'."
    } else {
        # If we're here, one or both are missing. Let's build a clear evidence string.
        if (-not ($inclusionSetting -like "*Success*")) { $result.evidence += "Logon 'Success' auditing is disabled. " }
        if (-not ($inclusionSetting -like "*Failure*")) { $result.evidence += "Logon 'Failure' auditing is disabled." }
    }

} catch {
    # 4. Handle any errors (e.g., auditpol command fails)
    $result.status = "Error"
    $result.evidence = "Failed to query audit policy for Logon events: $($_.Exception.Message)"
}

# 5. Print the final JSON payload for the C++ agent to capture.
return ConvertTo-Json $result -Compress
