# 🏆 Competitive Booking Mode

This guide explains how to use the advanced competitive features to maximize your chances of securing highly sought-after reservations.

## Overview

The competitive mode includes:
- **Polling**: Continuously check for slots every 0.25s (configurable)
- **Concurrent Threads**: Multiple simultaneous booking attempts (3-5 recommended)
- **Retries**: Each thread retries independently (configurable)
- **Lock-Free**: Uses atomic operations for zero-overhead coordination
- **Low Latency**: HTTP/2, connection pooling, TCP_NODELAY optimizations

## Usage

### Basic Competitive Booking

```bash
# 3 concurrent threads, each retrying 3 times
./target/release/resy-rust book \
  --venue-id 12345 \
  --party-size 2 \
  --date 2025-11-15 \
  --times "19:00:00,19:30:00" \
  --threads 3 \
  --retries 3
```

### Maximum Competitiveness

```bash
# 5 threads, 5 retries each, poll every 100ms for 60 seconds
./target/release/resy-rust book \
  --venue-id 12345 \
  --party-size 2 \
  --date 2025-11-15 \
  --times "19:00:00" \
  --threads 5 \
  --retries 5 \
  --poll-interval-ms 100 \
  --poll-timeout-secs 60
```

### Scheduled Execution

Use `at` or `cron` to schedule the booking to run at a specific time:

```bash
# Schedule to run at 9:00 AM on Nov 15
echo "./target/release/resy-rust book --venue-id 12345 --party-size 2 --date 2025-11-15 --times '19:00:00' --threads 5 --retries 3" | at 9:00 AM Nov 15
```

Or with macOS `at`:
```bash
at 09:00 <<EOF
cd /Users/yourusername/code/resy-cli/resy-rust && \
./target/release/resy-rust book \
  --venue-id 12345 \
  --party-size 2 \
  --date 2025-11-15 \
  --times "19:00:00" \
  --threads 5 \
  --retries 3
EOF
```

## Parameters

### `--threads <N>`
- **Default**: 1
- **Recommended**: 3-5
- **Description**: Number of concurrent booking attempts
- **Note**: More threads = higher success rate but more API load

### `--retries <N>`
- **Default**: 3
- **Recommended**: 3-5
- **Description**: Number of retry attempts per thread
- **Note**: Each thread retries independently with exponential backoff

### `--poll-interval-ms <MS>`
- **Default**: 250 (0.25 seconds)
- **Recommended**: 100-500
- **Description**: Milliseconds between slot availability checks
- **Note**: Lower = faster detection but more API calls

### `--poll-timeout-secs <SECS>`
- **Default**: 30
- **Recommended**: 30-60
- **Description**: Maximum time to poll before giving up
- **Note**: Restaurants often release slots 1-2 minutes late

### `--log-file <PATH>`
- **Default**: `~/.resy-rust/logs/venue_<venue_id>_<timestamp>.log`
- **Description**: Custom path for log file
- **Note**: Logs include timestamps and capture all booking activity

## How It Works

### 1. Polling Phase
```
t=0s   → Check for slots (not found)
t=0.25s → Check for slots (not found)
t=0.5s  → Check for slots (not found)
...
t=5.2s  → Check for slots (FOUND!)
```

### 2. Concurrent Booking Phase
```
Thread 0 ─┬─> Attempt 1 ─> Attempt 2 ─> SUCCESS! ✓
Thread 1 ─┤
Thread 2 ─┤  (all threads stop when one succeeds)
Thread 3 ─┤
Thread 4 ─┘
```

### 3. Lock-Free Coordination
- Uses `AtomicBool` to signal success (no mutex overhead)
- All threads check atomically and exit immediately when one succeeds
- Zero contention, maximum performance

## Optimization Tips

### For Ultra-Competitive Reservations
- Use **5 threads** and **5 retries**
- Set **poll-interval-ms to 100** (checks every 0.1 seconds)
- Run on a machine with good internet connection
- Schedule 30 seconds before expected release time
- Keep computer awake and connected

### For Normal Reservations
- Use **3 threads** and **3 retries**
- Keep default **poll-interval-ms of 250**
- Should be sufficient for most popular restaurants

### Network Optimizations
The client is already optimized with:
- Connection pooling (10 connections per host)
- TCP_NODELAY enabled (disables Nagle's algorithm)
- 500ms connect timeout
- 2 second request timeout
- 90 second pool idle timeout for connection reuse

## Performance Characteristics

### Latency
- **First slot check**: ~50-200ms (depends on network)
- **Booking attempt**: ~100-300ms (depends on API)
- **Thread spawn overhead**: <1ms each
- **Atomic coordination**: <1µs

### Success Rate
With 5 threads and 3 retries:
- **Total attempts**: Up to 15 (5 threads × 3 retries)
- **Time window**: ~1-2 seconds (with exponential backoff)
- **Success probability**: Very high if slots are available

## Examples

### Test with Dry Run
```bash
# Test polling and threading without actually booking
./target/release/resy-rust book \
  --venue-id 12345 \
  --party-size 2 \
  --date 2025-11-15 \
  --times "19:00:00" \
  --threads 5 \
  --retries 3 \
  --poll-interval-ms 250 \
  --poll-timeout-secs 10 \
  --dry-run
```

### Quick Booking (Slots Already Available)
```bash
# If slots are already available, use 1 thread with short poll timeout
./target/release/resy-rust book \
  --venue-id 12345 \
  --party-size 2 \
  --date 2025-11-15 \
  --times "19:00:00" \
  --threads 1 \
  --retries 1 \
  --poll-timeout-secs 5
```

### Maximum Aggression
```bash
# For the most competitive restaurants (use responsibly!)
./target/release/resy-rust book \
  --venue-id 12345 \
  --party-size 2 \
  --date 2025-11-15 \
  --times "19:00:00,19:15:00,19:30:00" \
  --threads 10 \
  --retries 5 \
  --poll-interval-ms 50 \
  --poll-timeout-secs 120
```

## Troubleshooting

### "No matching slots found after 30s of polling"
- Increase `--poll-timeout-secs` to 60 or 120
- Restaurant may release slots later than expected
- Check if times are correct (HH:MM:SS format)

### "Failed to book after X attempts"
- Slots were taken by others before you could book
- Try increasing `--threads` and `--retries`
- Ensure your network connection is fast

### "Failed to create client"
- Check your `.env` file has valid credentials
- Run `resy ping` equivalent to test auth

### Rate Limiting
- If you get rate limited, reduce `--threads`
- Increase `--poll-interval-ms`
- Use fewer `--retries`

## Best Practices

1. **Test First**: Always do a dry run before the actual booking time
2. **Stay Awake**: Ensure your computer won't sleep during booking
3. **Good Connection**: Use wired ethernet if possible
4. **Backup Plan**: Have the Resy website open as backup
5. **Be Reasonable**: Don't DOS the API with excessive threads

## Output Example

```
🚀 Starting Resy booking...
   Venue ID: 12345
   Party Size: 2
   Date: 2025-11-15
   Times: 19:00:00, 19:30:00
   Concurrent Threads: 5
   Retries per Thread: 3

📍 Fetching venue details...
🍽️  Restaurant: Atomix

🔍 Polling for available slots...
   Poll interval: 250ms
   Poll timeout: 30s
⏳ Polling for slots...
✅ Found 2 matching slots after 23 attempts (5.75s)

🎯 Available matching slots:
   - 2025-11-15 19:00:00 (Dining Room)
   - 2025-11-15 19:30:00 (Counter)

🚀 Launching 5 concurrent booking threads...
   ✅ Thread 2 succeeded on attempt 1

🎉 Successfully booked reservation!
   Total attempts: 3
```

## Responsible Use

Please use this tool responsibly:
- Follow Resy's Terms of Service
- Don't run excessive threads (>10)
- Don't set poll interval below 50ms
- This tool is for personal use, not commercial scalping
- Be considerate of API resources

---

**Good luck booking your dream restaurant! 🍽️✨**

