#!/bin/bash

# Check scheduled bookings and view logs

echo "════════════════════════════════════════════════════════"
echo "Scheduled Bookings Status"
echo "════════════════════════════════════════════════════════"
echo ""

# Check at jobs
echo "📅 AT scheduled jobs:"
if command -v atq &> /dev/null; then
    AT_JOBS=$(atq 2>/dev/null)
    if [ -n "$AT_JOBS" ]; then
        atq
        echo ""
        echo "To view a job: at -c JOB_NUMBER"
        echo "To remove a job: atrm JOB_NUMBER"
    else
        echo "  (none)"
    fi
else
    echo "  'at' command not available"
fi
echo ""

# Check cron jobs
echo "⏰ CRON scheduled jobs:"
if command -v crontab &> /dev/null; then
    CRON_JOBS=$(crontab -l 2>/dev/null | grep -v "^#" | grep "resy\|run.sh" || echo "")
    if [ -n "$CRON_JOBS" ]; then
        echo "$CRON_JOBS"
        echo ""
        echo "To edit: crontab -e"
    else
        echo "  (none)"
    fi
else
    echo "  'crontab' command not available"
fi
echo ""

# Check systemd timers
echo "🔔 SYSTEMD timers:"
if command -v systemctl &> /dev/null; then
    TIMERS=$(systemctl list-timers --all 2>/dev/null | grep "resy" || echo "")
    if [ -n "$TIMERS" ]; then
        echo "$TIMERS"
        echo ""
        echo "To check status: sudo systemctl status resy-booking-*.timer"
    else
        echo "  (none)"
    fi
else
    echo "  'systemctl' command not available"
fi
echo ""

# Show recent logs
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$PROJECT_ROOT/logs"

if [ -d "$LOG_DIR" ] && [ "$(ls -A $LOG_DIR 2>/dev/null)" ]; then
    echo "════════════════════════════════════════════════════════"
    echo "📝 Recent Log Files:"
    echo "════════════════════════════════════════════════════════"
    ls -lht "$LOG_DIR"/*.log 2>/dev/null | head -10
    echo ""
    
    LATEST_LOG=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_LOG" ]; then
        echo "Latest log file: $LATEST_LOG"
        echo ""
        read -p "View latest log? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            echo "════════════════════════════════════════════════════════"
            tail -50 "$LATEST_LOG"
            echo "════════════════════════════════════════════════════════"
        fi
    fi
else
    echo "📝 No log files found in $LOG_DIR"
fi
echo ""

# Show quick stats
echo "════════════════════════════════════════════════════════"
echo "📊 Booking Statistics:"
echo "════════════════════════════════════════════════════════"
if [ -d "$LOG_DIR" ] && [ "$(ls -A $LOG_DIR 2>/dev/null)" ]; then
    SUCCESSES=$(grep -h "Successfully booked" "$LOG_DIR"/*.log 2>/dev/null | wc -l)
    FAILURES=$(grep -h "Booking failed" "$LOG_DIR"/*.log 2>/dev/null | wc -l)
    TOTAL=$((SUCCESSES + FAILURES))
    
    echo "Total booking attempts: $TOTAL"
    echo "Successful: $SUCCESSES"
    echo "Failed: $FAILURES"
    
    if [ $TOTAL -gt 0 ]; then
        SUCCESS_RATE=$(echo "scale=1; $SUCCESSES * 100 / $TOTAL" | bc)
        echo "Success rate: ${SUCCESS_RATE}%"
    fi
else
    echo "No booking history yet"
fi
echo ""

