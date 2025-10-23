#!/bin/bash
# SCRIPT_NAME: check_linux_firewalld_default_deny.sh
# CONTROL_ID: C-411
# Author : Mostafa Essam (0xMOSTA)
# --- Standard Setup ---
# Allow Control ID to be passed as an argument (e.g., -c C-411)
CONTROL_ID="C-UNKNOWN"; while getopts "c:" opt; do case $opt in c) CONTROL_ID="$OPTARG" ;; esac done
HOSTNAME=$(hostname); TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Default to Error status unless we prove otherwise
STATUS="Error"
EVIDENCE="firewalld (firewall-cmd) not found or not active."

# --- Check Logic ---

# First, make sure firewalld is actually the active service.
# No point checking if it's off or if iptables is running instead.
if systemctl is-active --quiet "firewalld"; then
    
    # 1. Grab the name of the active default zone (e.g., "public", "trusted")
    DEFAULT_ZONE=$(firewall-cmd --get-default-zone)
    
    # 2. Get the default *target* for that zone (e.g., "default", "DROP", "ACCEPT")
    DEFAULT_TARGET=$(firewall-cmd --zone="$DEFAULT_ZONE" --get-target)

    # 3. Check the result. We're looking for a "default-deny" policy.
    # 'default' (implicit deny), 'DROP', or 'REJECT' (explicit deny) are all compliant.
    # Anything else (like 'ACCEPT') is non-compliant.
    if [ "$DEFAULT_TARGET" == "default" ] || [ "$DEFAULT_TARGET" == "DROP" ] || [ "$DEFAULT_TARGET" == "REJECT" ]; then
        STATUS="Compliant"
        EVIDENCE="firewalld default zone ($DEFAULT_ZONE) has a target of '$DEFAULT_TARGET' (Default Deny)."
    else
        STATUS="Non-Compliant"
        EVIDENCE="firewalld default zone ($DEFAULT_ZONE) has a target of '$DEFAULT_TARGET' (Not Default Deny)."
    fi
else
    # If firewalld isn't running, we can't audit it. Mark as Not-Applicable.
    STATUS="Not-Applicable"
    EVIDENCE="firewalld service is not active."
fi

# --- Output ---

# 4. Print the final JSON payload for the agent to pick up.
cat <<EOF
{
  "control_id": "$CONTROL_ID",
  "hostname": "$HOSTNAME",
  "status": "$STATUS",
  "evidence": "$EVIDENCE",
  "timestamp": "$TIMESTAMP"
}
EOF
