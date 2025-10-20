#!/bin/bash
# Schedule booking on macOS using launchd
# Usage: ./schedule-macos.sh "2025-10-25 09:00:00" 79633 2 "17:00:00,18:00:00"

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ $# -lt 4 ]; then
    echo "Usage: $0 <schedule_time> <venue_id> <party_size> <times>"
    echo "Example: $0 '2025-10-25 09:00:00' 79633 2 '17:00:00,18:00:00'"
    echo ""
    echo "This will create a launchd job that runs at the specified time."
    exit 1
fi

SCHEDULE_TIME="$1"
VENUE_ID="$2"
PARTY_SIZE="$3"
TIMES="$4"

# Parse the schedule time
SCHEDULE_DATE=$(date -j -f "%Y-%m-%d %H:%M:%S" "$SCHEDULE_TIME" "+%Y-%m-%d" 2>/dev/null)
SCHEDULE_HOUR=$(date -j -f "%Y-%m-%d %H:%M:%S" "$SCHEDULE_TIME" "+%H" 2>/dev/null)
SCHEDULE_MINUTE=$(date -j -f "%Y-%m-%d %H:%M:%S" "$SCHEDULE_TIME" "+%M" 2>/dev/null)

if [ -z "$SCHEDULE_DATE" ]; then
    echo "Error: Invalid schedule time format. Use: YYYY-MM-DD HH:MM:SS"
    exit 1
fi

# Create launchd plist
PLIST_NAME="com.resy.booking.$(date +%s)"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"

cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_NAME}</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>$PROJECT_ROOT/target/release/resy-rust</string>
        <string>book</string>
        <string>--venue-id</string>
        <string>$VENUE_ID</string>
        <string>--party-size</string>
        <string>$PARTY_SIZE</string>
        <string>--date</string>
        <string>$SCHEDULE_DATE</string>
        <string>--times</string>
        <string>$TIMES</string>
        <string>--threads</string>
        <string>5</string>
        <string>--retries</string>
        <string>5</string>
    </array>
    
    <key>EnvironmentVariables</key>
    <dict>
        <key>RESY_API_KEY</key>
        <string>$(grep RESY_API_KEY "$PROJECT_ROOT/.env" | cut -d '=' -f2)</string>
        <key>RESY_AUTH_TOKEN</key>
        <string>$(grep RESY_AUTH_TOKEN "$PROJECT_ROOT/.env" | cut -d '=' -f2)</string>
    </dict>
    
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>$SCHEDULE_HOUR</integer>
        <key>Minute</key>
        <integer>$SCHEDULE_MINUTE</integer>
    </dict>
    
    <key>StandardOutPath</key>
    <string>$PROJECT_ROOT/logs/launchd-output.log</string>
    
    <key>StandardErrorPath</key>
    <string>$PROJECT_ROOT/logs/launchd-error.log</string>
    
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
EOF

# Load the job
launchctl load "$PLIST_PATH"

echo "✅ Scheduled booking job: $PLIST_NAME"
echo "   Time: $SCHEDULE_TIME"
echo "   Venue: $VENUE_ID"
echo "   Party Size: $PARTY_SIZE"
echo "   Times: $TIMES"
echo ""
echo "To check status:"
echo "  launchctl list | grep resy"
echo ""
echo "To cancel:"
echo "  launchctl unload $PLIST_PATH"
echo "  rm $PLIST_PATH"
echo ""
echo "Logs will be in: $PROJECT_ROOT/logs/"

