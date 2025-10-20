# Logging

All booking attempts are automatically logged to files for later review and troubleshooting.

## Default Log Location

Logs are saved to:
```
~/.resy-rust/logs/venue_<venue_id>_<timestamp>.log
```

Example:
```
~/.resy-rust/logs/venue_58326_20251020_143052.log
```

## Custom Log Path

Specify a custom log file path:

```bash
./target/release/resy-rust book \
  --venue-id 12345 \
  --party-size 2 \
  --date 2025-11-15 \
  --times "19:00:00" \
  --log-file /tmp/my-booking.log
```

## Log Format

Each log entry includes:
- **Timestamp**: `[YYYY-MM-DD HH:MM:SS.mmm]`
- **Message**: The log message (same as console output)

Example log content:

```
[2025-10-20 14:30:52.123] ═══════════════════════════════════════════════════════
[2025-10-20 14:30:52.124] 🚀 Starting Resy booking...
[2025-10-20 14:30:52.124]    Venue ID: 58326
[2025-10-20 14:30:52.125]    Party Size: 2
[2025-10-20 14:30:52.125]    Date: 2025-11-15
[2025-10-20 14:30:52.125]    Times: 19:00:00, 19:30:00
[2025-10-20 14:30:52.126]    Concurrent Threads: 5
[2025-10-20 14:30:52.126]    Retries per Thread: 3
[2025-10-20 14:30:52.126]    Log File: /Users/todd/.resy-rust/logs/venue_58326_20251020_143052.log
[2025-10-20 14:30:52.127] 
[2025-10-20 14:30:52.127] 📍 Fetching venue details...
[2025-10-20 14:30:52.456] 🍽️  Restaurant: Atomix
[2025-10-20 14:30:52.456] 
[2025-10-20 14:30:52.456] 🔍 Polling for available slots...
[2025-10-20 14:30:52.457]    Poll interval: 250ms
[2025-10-20 14:30:52.457]    Poll timeout: 30s
[2025-10-20 14:30:52.890] ⏳ Polling for slots... (No venues found)
[2025-10-20 14:30:58.234] ✅ Found 2 matching slots after 23 attempts (5.78s)
[2025-10-20 14:30:58.235] 
[2025-10-20 14:30:58.235] 🎯 Available matching slots:
[2025-10-20 14:30:58.235]    - 2025-11-15 19:00:00 (Dining Room)
[2025-10-20 14:30:58.236]    - 2025-11-15 19:30:00 (Counter)
[2025-10-20 14:30:58.236] 
[2025-10-20 14:30:58.236] 🚀 Launching 5 concurrent booking threads...
[2025-10-20 14:30:58.789]    ⚠️  Thread 0 attempt 1/3: Failed to get booking token: 400
[2025-10-20 14:30:58.890]    ⚠️  Thread 1 attempt 1/3: Failed to book reservation: 409
[2025-10-20 14:30:59.123]    ✅ Thread 2 succeeded on attempt 1
[2025-10-20 14:30:59.124] 
[2025-10-20 14:30:59.124] 🎉 Successfully booked reservation!
[2025-10-20 14:30:59.124]    Total attempts: 3
[2025-10-20 14:30:59.125] 
[2025-10-20 14:30:59.125] ═══════════════════════════════════════════════════════
[2025-10-20 14:30:59.125] ✅ Booking completed successfully
```

## Features

### Dual Output
- All messages appear in **both** console and log file
- Console shows real-time progress
- Log file preserves complete history with timestamps

### Automatic Directory Creation
The tool automatically creates the log directory if it doesn't exist:
```bash
mkdir -p ~/.resy-rust/logs
```

### Thread-Safe Logging
- Multiple concurrent booking threads can log safely
- Uses mutex to prevent interleaved writes
- Each thread's activity is captured

### Append Mode
- Log files open in append mode
- Multiple runs can write to the same file
- Useful for scheduling multiple bookings

## Use Cases

### Review Booking Attempts
Check what went wrong if booking failed:
```bash
tail -n 50 ~/.resy-rust/logs/venue_58326_20251020_143052.log
```

### Monitor Polling
See how long it took to find slots:
```bash
grep "Found.*matching slots" ~/.resy-rust/logs/*.log
```

### Track Success Rate
Find all successful bookings:
```bash
grep "Successfully booked" ~/.resy-rust/logs/*.log
```

### Debug Thread Activity
See which thread succeeded:
```bash
grep "Thread.*succeeded" ~/.resy-rust/logs/*.log
```

### Scheduled Bookings
When using `at` or `cron`, logs are essential since you won't see console output:
```bash
# Schedule booking
echo "./resy-rust book --venue-id 123 --party-size 2 --date 2025-11-15 --times '19:00:00'" | at 9:00 AM

# Later, check the log
cat ~/.resy-rust/logs/venue_123_*.log
```

## Log Management

### View Recent Logs
```bash
ls -lt ~/.resy-rust/logs/ | head -10
```

### Find Logs by Venue
```bash
ls ~/.resy-rust/logs/venue_58326_*.log
```

### Clean Old Logs
```bash
# Delete logs older than 30 days
find ~/.resy-rust/logs/ -name "*.log" -mtime +30 -delete
```

### Monitor Live
Follow a log file in real-time:
```bash
tail -f ~/.resy-rust/logs/venue_58326_20251020_143052.log
```

## Tips

1. **Keep Logs**: They're useful for understanding booking patterns
2. **Custom Paths for Tests**: Use `--log-file /tmp/test.log` for dry runs
3. **Grep is Your Friend**: Use `grep`, `awk`, `sed` to analyze logs
4. **Timestamps are Precise**: Down to milliseconds for timing analysis
5. **Logs Persist**: Even if terminal scrolls away, logs remain

## Example Analysis

### Calculate Average Poll Time
```bash
grep "Found.*matching slots" ~/.resy-rust/logs/*.log | \
  sed 's/.*(\([0-9.]*\)s)/\1/' | \
  awk '{sum+=$1; count++} END {print "Average:", sum/count, "seconds"}'
```

### Count Booking Attempts
```bash
grep "Total attempts" ~/.resy-rust/logs/*.log | \
  sed 's/.*Total attempts: \([0-9]*\)/\1/' | \
  awk '{sum+=$1; count++} END {print "Total attempts:", sum, "Average per booking:", sum/count}'
```

### Success Rate
```bash
echo "Successes: $(grep -c 'Successfully booked' ~/.resy-rust/logs/*.log)"
echo "Failures: $(grep -c 'Booking failed' ~/.resy-rust/logs/*.log)"
```

