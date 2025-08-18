#!/bin/bash

# Prompt for hostname
echo "Enter the hostname to monitor (e.g., bracketbot-216):"
read -r HOST

# Validate input
if [ -z "$HOST" ]; then
    echo "Error: Hostname cannot be empty"
    exit 1
fi

DEST=./logs/${HOST}
SESSION_NAME="dietpi-logs"

mkdir -p ${DEST}
# pick a per-host socket name
sock=/tmp/ssh_mux_%h_%p_%r

# Cleanup function
cleanup() {
    echo -e "\n\nCleaning up..."
    # Kill the background scp process
    if [ -n "$SCP_PID" ]; then
        kill $SCP_PID 2>/dev/null
    fi
    # Close SSH master connection
    ssh -O exit -S "$sock" root@${HOST}.local 2>/dev/null
    # Kill tmux session if it exists
    tmux kill-session -t "$SESSION_NAME" 2>/dev/null

    exit 0
}

# Set up trap to cleanup on exit
trap cleanup EXIT INT TERM

# Check if tmux is installed
if ! command -v tmux &> /dev/null; then
    echo "Error: tmux is not installed. Please install tmux first."
    echo "On macOS: brew install tmux"
    echo "On Linux: sudo apt-get install tmux"
    exit 1
fi

# Kill any existing session with the same name
tmux kill-session -t "$SESSION_NAME" 2>/dev/null

# 1) open a background master (auth once)
echo "Establishing SSH connection to ${HOST}.local..."
ssh -M -Nf -o ControlPath="$sock" -o ControlPersist=5m root@${HOST}.local

# 2) Start syncing files in the background
echo "Starting file sync in background..."
(
    while true; do
        scp -q -o ControlPath="$sock" "root@${HOST}.local:/var/tmp/dietpi/logs/dietpi*.log" ${DEST}/ 2>/dev/null
        sleep 0.5
    done
) &
SCP_PID=$!

# Give it a moment to sync the initial files
echo "Waiting for initial file sync..."
sleep 3

# 3) Create tmux session with panes for each log file
echo "Creating tmux dashboard for log files..."

# Get list of synced log files
LOG_FILES=(${DEST}/dietpi*.log)

if [ ${#LOG_FILES[@]} -eq 0 ] || [ ! -e "${LOG_FILES[0]}" ]; then
    echo "No log files found yet. Waiting..."
    sleep 2
    LOG_FILES=(${DEST}/dietpi*.log)
fi

# Create the first tmux window with the first log file
if [ -e "${LOG_FILES[0]}" ]; then
    # Create session with the first log file and capture pane ID
    first_pane=$(tmux new-session -d -s "$SESSION_NAME" -n "logs" \
        -P -F '#{pane_id}' \
        "tail -F '${LOG_FILES[0]}' 2>/dev/null || (echo 'Waiting for ${LOG_FILES[0]}...'; sleep infinity)")
    
    # Set the pane title using the captured pane ID
    tmux select-pane -t "$first_pane" -T "📄 $(basename "${LOG_FILES[0]}")"
    
    # Now that we have a window, set the window options for pane borders
    tmux setw -t "$SESSION_NAME:logs" pane-border-status top
    tmux setw -t "$SESSION_NAME:logs" pane-border-format ' #{pane_index}: #{pane_title} '
    
    # Add remaining log files as panes
    for ((i=1; i<${#LOG_FILES[@]}; i++)); do
        if [ -e "${LOG_FILES[$i]}" ]; then
            # Split the window and capture the new pane ID
            new_pane=$(tmux split-window -t "$SESSION_NAME:logs" -v \
                -P -F '#{pane_id}' \
                "tail -F '${LOG_FILES[$i]}' 2>/dev/null || (echo 'Waiting for ${LOG_FILES[$i]}...'; sleep infinity)")
            
            # Set the pane title using the captured pane ID
            tmux select-pane -t "$new_pane" -T "📄 $(basename "${LOG_FILES[$i]}")"
        fi
    done
    
    # Apply tiled layout for better organization
    tmux select-layout -t "$SESSION_NAME:logs" tiled
    
    # Add a status pane at the bottom showing sync status
    sync_pane=$(tmux split-window -t "$SESSION_NAME:logs" -v -l 3 \
        -P -F '#{pane_id}' \
        "while true; do echo -ne '\\rFile sync active... Last update: '\\$(date '+%H:%M:%S')'  Press Ctrl+C in any pane to exit all'; sleep 1; done")
    
    # Set title for sync pane
    tmux select-pane -t "$sync_pane" -T "🔄 SYNC STATUS"
    
    # Reapply tiled layout
    tmux select-layout -t "$SESSION_NAME:logs" tiled
    
    echo "----------------------------------------"
    echo "Log monitoring dashboard created!"
    echo "Showing: ${LOG_FILES[@]}"
    echo "----------------------------------------"
    echo "Press Ctrl+C in any pane to stop monitoring"
    echo ""
    
    # Attach to the tmux session
    tmux attach-session -t "$SESSION_NAME"
else
    echo "Error: No log files found to monitor"
    cleanup
fi