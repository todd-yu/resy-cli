#!/bin/bash

# Schedule a booking with cron or at
# Usage: ./schedule.sh [OPTIONS]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_SCRIPT="$SCRIPT_DIR/run.sh"

show_help() {
    cat << EOF
Schedule a Resy booking

Usage: ./schedule.sh [OPTIONS]

Options:
    -t, --time TIME         Time to run (e.g., "09:00", "2025-11-15 09:00")
    -v, --venue-id ID       Venue ID (required)
    -p, --party-size N      Party size (default: 2)
    -d, --date DATE         Reservation date YYYY-MM-DD (default: +7 days)
    --times TIMES           Comma-separated times HH:MM:SS (default: 18:00:00,19:00:00)
    --threads N             Concurrent threads (default: 5)
    --retries N             Retries per thread (default: 3)
    --log-file PATH         Custom log file path
    --dry-run               Test mode (default for safety)
    --no-dry-run            Actually book the reservation
    --method METHOD         Scheduling method: cron, at, or systemd (default: at)
    --recurring PATTERN     Cron pattern for recurring jobs (requires --method cron)
    -h, --help              Show this help

Examples:
    # Schedule for tomorrow at 9 AM with 'at'
    ./schedule.sh --time "09:00" --venue-id 58326 --times "19:00:00" --no-dry-run

    # Schedule for specific date and time
    ./schedule.sh --time "2025-11-15 09:00" --venue-id 12345 --times "19:00:00,19:30:00" --no-dry-run

    # Daily recurring at 9 AM with cron
    ./schedule.sh --method cron --recurring "0 9 * * *" --venue-id 12345 --times "19:00:00" --no-dry-run

    # Aggressive competitive mode
    ./schedule.sh --time "09:00" --venue-id 12345 --times "19:00:00" --threads 10 --retries 5 --no-dry-run

EOF
}

# Default values
VENUE_ID=""
PARTY_SIZE="2"
RESERVATION_DATE=""
TIMES="18:00:00,19:00:00"
THREADS="5"
RETRIES="3"
LOG_FILE=""
DRY_RUN="true"
SCHEDULE_TIME=""
METHOD="at"
CRON_PATTERN=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--time)
            SCHEDULE_TIME="$2"
            shift 2
            ;;
        -v|--venue-id)
            VENUE_ID="$2"
            shift 2
            ;;
        -p|--party-size)
            PARTY_SIZE="$2"
            shift 2
            ;;
        -d|--date)
            RESERVATION_DATE="$2"
            shift 2
            ;;
        --times)
            TIMES="$2"
            shift 2
            ;;
        --threads)
            THREADS="$2"
            shift 2
            ;;
        --retries)
            RETRIES="$2"
            shift 2
            ;;
        --log-file)
            LOG_FILE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --no-dry-run)
            DRY_RUN="false"
            shift
            ;;
        --method)
            METHOD="$2"
            shift 2
            ;;
        --recurring)
            CRON_PATTERN="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$VENUE_ID" ]; then
    echo "Error: --venue-id is required"
    show_help
    exit 1
fi

# Build the command
CMD="cd $(dirname $RUN_SCRIPT) && "
CMD+="DRY_RUN=$DRY_RUN VENUE_ID=$VENUE_ID PARTY_SIZE=$PARTY_SIZE THREADS=$THREADS RETRIES=$RETRIES "

if [ -n "$RESERVATION_DATE" ]; then
    CMD+="RESERVATION_DATE=$RESERVATION_DATE "
fi

if [ -n "$TIMES" ]; then
    CMD+="TIMES='$TIMES' "
fi

if [ -n "$LOG_FILE" ]; then
    CMD+="LOG_FILE=$LOG_FILE "
fi

CMD+="$RUN_SCRIPT"

echo "════════════════════════════════════════════════════════"
echo "Scheduling Configuration:"
echo "  Method: $METHOD"
echo "  Venue ID: $VENUE_ID"
echo "  Party Size: $PARTY_SIZE"
echo "  Times: $TIMES"
echo "  Threads: $THREADS"
echo "  Retries: $RETRIES"
echo "  Dry Run: $DRY_RUN"
if [ -n "$RESERVATION_DATE" ]; then
    echo "  Reservation Date: $RESERVATION_DATE"
fi
if [ -n "$LOG_FILE" ]; then
    echo "  Log File: $LOG_FILE"
fi
echo "════════════════════════════════════════════════════════"
echo ""

case $METHOD in
    at)
        if [ -z "$SCHEDULE_TIME" ]; then
            echo "Error: --time is required for 'at' scheduling"
            exit 1
        fi
        
        echo "Scheduling with 'at' for: $SCHEDULE_TIME"
        echo "$CMD" | at "$SCHEDULE_TIME" 2>&1
        
        if [ $? -eq 0 ]; then
            echo "✅ Successfully scheduled!"
            echo ""
            echo "To view scheduled jobs: atq"
            echo "To remove a job: atrm JOB_NUMBER"
            echo "Logs will be in: ~/.resy-rust/logs/ or your specified log path"
        else
            echo "❌ Failed to schedule. Make sure 'at' is installed and atd is running."
            exit 1
        fi
        ;;
        
    cron)
        if [ -z "$CRON_PATTERN" ]; then
            echo "Error: --recurring is required for 'cron' scheduling"
            exit 1
        fi
        
        # Add to crontab
        CRON_ENTRY="$CRON_PATTERN $CMD"
        
        echo "Adding to crontab:"
        echo "$CRON_ENTRY"
        echo ""
        
        # Check if entry already exists
        if crontab -l 2>/dev/null | grep -F "$VENUE_ID" | grep -q "run.sh"; then
            echo "⚠️  Warning: A similar entry may already exist in crontab"
            echo ""
            echo "Current crontab entries for resy:"
            crontab -l 2>/dev/null | grep "run.sh" || echo "(none)"
            echo ""
            read -p "Continue anyway? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Cancelled."
                exit 1
            fi
        fi
        
        # Add to crontab
        (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
        
        echo "✅ Successfully added to crontab!"
        echo ""
        echo "To view crontab: crontab -l"
        echo "To edit crontab: crontab -e"
        echo "To remove all entries: crontab -r"
        ;;
        
    systemd)
        echo "Creating systemd timer..."
        
        if [ -z "$SCHEDULE_TIME" ]; then
            echo "Error: --time is required for systemd scheduling"
            exit 1
        fi
        
        # Parse time for systemd OnCalendar format
        # This is a simplified version - you may need to adjust based on your needs
        ONCALENDAR="$SCHEDULE_TIME"
        
        SERVICE_NAME="resy-booking-${VENUE_ID}"
        
        cat > "/tmp/${SERVICE_NAME}.service" << EOFSERVICE
[Unit]
Description=Resy Booking for Venue $VENUE_ID
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c '$CMD'
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOFSERVICE

        cat > "/tmp/${SERVICE_NAME}.timer" << EOFTIMER
[Unit]
Description=Timer for Resy Booking (Venue $VENUE_ID)

[Timer]
OnCalendar=$ONCALENDAR
Persistent=true

[Install]
WantedBy=timers.target
EOFTIMER

        echo "Created systemd unit files in /tmp/"
        echo ""
        echo "To install, run these commands as root:"
        echo "  sudo cp /tmp/${SERVICE_NAME}.service /etc/systemd/system/"
        echo "  sudo cp /tmp/${SERVICE_NAME}.timer /etc/systemd/system/"
        echo "  sudo systemctl daemon-reload"
        echo "  sudo systemctl enable ${SERVICE_NAME}.timer"
        echo "  sudo systemctl start ${SERVICE_NAME}.timer"
        echo ""
        echo "To check status:"
        echo "  sudo systemctl status ${SERVICE_NAME}.timer"
        echo "  sudo systemctl list-timers"
        ;;
        
    *)
        echo "Error: Unknown method '$METHOD'. Use 'at', 'cron', or 'systemd'"
        exit 1
        ;;
esac

