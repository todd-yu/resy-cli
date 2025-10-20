# Scripts

Helper scripts for running the Resy booking CLI.

## run.sh

A convenience script that wraps the `resy-rust` binary with sensible defaults.

### Usage

**1. Run with defaults:**
```bash
./scripts/run.sh
```

Default configuration:
- Venue ID: `58326`
- Party Size: `2`
- Date: 7 days from today
- Times: `18:00:00,19:00:00`
- Threads: `5`
- Retries: `3`
- Log File: `logs/booking_<timestamp>.log`
- Dry Run: `true`

**2. Override with environment variables:**
```bash
VENUE_ID=12345 PARTY_SIZE=4 DRY_RUN=false ./scripts/run.sh
```

Available environment variables:
- `VENUE_ID` - Restaurant venue ID
- `PARTY_SIZE` - Number of people
- `RESERVATION_DATE` - Date (YYYY-MM-DD format)
- `TIMES` - Comma-separated times (HH:MM:SS format)
- `THREADS` - Number of concurrent booking threads
- `RETRIES` - Retry attempts per thread
- `LOG_FILE` - Path to log file
- `DRY_RUN` - Set to `false` to actually book (default: `true`)

**3. Pass arguments directly:**
```bash
./scripts/run.sh --venue-id 12345 --party-size 4 --date 2025-11-15 --times "19:00:00"
```

When passing arguments, the script automatically adds a default log file unless you specify `--log-file`.

### Examples

**Quick test with specific venue:**
```bash
VENUE_ID=58326 ./scripts/run.sh
```

**Actual booking (not dry run):**
```bash
DRY_RUN=false VENUE_ID=12345 TIMES="19:00:00" ./scripts/run.sh
```

**Competitive mode with custom settings:**
```bash
VENUE_ID=12345 THREADS=10 RETRIES=5 DRY_RUN=false ./scripts/run.sh
```

**Pass through all arguments:**
```bash
./scripts/run.sh \
  --venue-id 12345 \
  --party-size 2 \
  --date 2025-12-31 \
  --times "18:00:00,18:30:00,19:00:00" \
  --threads 5 \
  --retries 3 \
  --poll-interval-ms 250 \
  --poll-timeout-secs 30
```

**Custom log file:**
```bash
./scripts/run.sh --venue-id 12345 --times "19:00:00" --log-file /tmp/my-booking.log
```

### Features

✅ **Auto-finds binary**: Locates the release binary from any directory  
✅ **Sensible defaults**: Works out of the box for testing  
✅ **Flexible**: Use env vars, arguments, or mix both  
✅ **Safe**: Defaults to dry-run mode  
✅ **Auto-logging**: Always creates a log file  
✅ **Date calculation**: Defaults to 7 days from today  

### Notes

- The script checks if the binary exists and prompts you to build if needed
- Logs are stored in `logs/` directory (created automatically)
- Default log files include timestamp: `booking_20251020_143052.log`
- When using environment variables, you can mix with arguments
- The script uses `exec` for clean process management

