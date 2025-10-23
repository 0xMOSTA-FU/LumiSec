# SCRIPT_NAME: check_win_store_disabled.ps1
# CONTROL_ID: C-512
# Author : Mostafa Essam (0xMOSTA)
# This script checks if the Windows Store is disabled via Group Policy.
# On servers, the Store is often disabled to prevent unauthorized app installs.

param (
    # Allow the Control ID to be passed in from the agent's job.
    [string]$ControlID = "C-512" 
)

# --- Standard Functions ---

function Get-Timestamp { 
    # Helper to get a standardized ISO 8601 timestamp (UTC).
    return (Get-Date).ToUniversalTime().ToString("o") 
}

# --- Main Logic ---

# 1. Set up the JSON payload. We'll assume 'Error' until we prove otherwise.
$result = @{
    control_id = $ControlID
    hostname = $env:COMPUTERNAME
    status = "Error"
    evidence = "Script failed to execute."
    timestamp = (Get-Timestamp)
}

# This is the specific registry key set by the GPO "Turn off the Store application".
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore"

try {
    # 2. Check the registry value.
    # We use -ErrorAction SilentlyContinue so the script doesn't crash if the key doesn't exist.
    $regValue = (Get-ItemProperty -Path $regPath -Name "RemoveWindowsStore" -ErrorAction SilentlyContinue).RemoveWindowsStore
    
    # 3. Determine the result.
    # A value of '1' means the policy is enabled (Store is disabled).
    if ($regValue -eq 1) {
        $result.status = "Compliant"
        $result.evidence = "Windows Store is disabled via policy (RemoveWindowsStore: 1)."
    } else {
        # This handles '0' or any other value.
        $result.status = "Non-Compliant"
        $result.evidence = "Windows Store is enabled (RemoveWindowsStore: $regValue). Expected 1."
    }
} catch {
    # 4. Handle the 'catch' block.
    # If Get-ItemProperty fails (e.g., key doesn't exist), the '$regValue' variable is null,
    # and the script jumps to 'catch'. This is our non-compliant path.
    # If the key isn't there, the policy isn't set, meaning the Store is enabled by default.
    $result.status = "Non-Compliant"
    $result.evidence = "Windows Store policy key not found, which means it is enabled by default."
}

# 5. Print the final JSON payload for the C++ agent to capture.
return ConvertTo-Json $result -Compress
