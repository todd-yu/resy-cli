# Quick Reference Card

## 🚀 Deployment to Cloud VM

```bash
# 1. Copy to VM
scp -r resy-rust user@your-vm-ip:~/

# 2. SSH and setup
ssh user@your-vm-ip
cd resy-rust
./scripts/vm-setup.sh

# 3. Add credentials
nano .env

# 4. Test
./scripts/run.sh

# 5. Schedule
./scripts/schedule.sh --time "09:00" --venue-id 58326 --times "19:00:00" --no-dry-run
```

## ⏰ Scheduling Options

### One-Time Booking (at)
```bash
./scripts/schedule.sh \
  --time "tomorrow 09:00" \
  --venue-id 58326 \
  --times "19:00:00" \
  --no-dry-run
```

### Daily Recurring (cron)
```bash
./scripts/schedule.sh \
  --method cron \
  --recurring "0 9 * * *" \
  --venue-id 58326 \
  --times "19:00:00" \
  --no-dry-run
```

### Maximum Competition
```bash
./scripts/schedule.sh \
  --time "08:59:55" \
  --venue-id 58326 \
  --times "19:00:00" \
  --threads 10 \
  --retries 5 \
  --poll-interval-ms 100 \
  --no-dry-run
```

## 📊 Monitoring

```bash
# Check scheduled jobs
./scripts/check-schedule.sh

# View logs
tail -f logs/booking_*.log

# Check at jobs
atq                     # List
at -c JOB_NUM          # View details
atrm JOB_NUM           # Remove

# Check cron jobs
crontab -l             # List
crontab -e             # Edit
```

## 🔧 Common Cron Patterns

```
0 9 * * *      Daily at 9 AM
0 */2 * * *    Every 2 hours
0 9 * * 1-5    Weekdays at 9 AM
0 9 * * 6      Saturdays at 9 AM
0 9 1 * *      First of month at 9 AM
0 9,18 * * *   9 AM and 6 PM daily
```

## 🎯 CLI Arguments

```bash
--venue-id ID              Restaurant venue ID (required)
--party-size N             Number of people (default: 2)
--date YYYY-MM-DD          Reservation date (default: +7 days)
--times HH:MM:SS,...       Comma-separated times (default: 18:00:00,19:00:00)
--threads N                Concurrent threads (default: 5)
--retries N                Retries per thread (default: 3)
--poll-interval-ms MS      Poll interval (default: 250)
--poll-timeout-secs S      Poll timeout (default: 120)
--log-file PATH            Custom log path
--dry-run                  Test mode (safe)
--no-dry-run               Actually book
```

## 🔑 Environment Variables

```bash
VENUE_ID=58326
PARTY_SIZE=2
RESERVATION_DATE=2025-11-15
TIMES="19:00:00,19:30:00"
THREADS=5
RETRIES=3
DRY_RUN=false
LOG_FILE=custom.log
```

## 🆘 Troubleshooting

```bash
# Check services
sudo systemctl status atd
sudo systemctl status cron

# View system logs
sudo journalctl -u atd
sudo journalctl -u cron

# Test manually
./scripts/run.sh

# Check credentials
cat .env

# Network test
ping api.resy.com
```

## 📦 Files

```
scripts/
├── vm-setup.sh          Setup VM (run once)
├── run.sh               Run booking with defaults
├── schedule.sh          Schedule a booking
├── check-schedule.sh    View scheduled jobs & logs
└── examples.sh          Usage examples

docs/
├── README.md            Main documentation
├── QUICKSTART.md        Quick start guide
├── COMPETITIVE_MODE.md  Competitive booking
├── LOGGING.md           Logging guide
└── DEPLOYMENT.md        Full deployment guide (⭐)
```

## ⚡ Quick Commands

```bash
# Schedule for tomorrow 9 AM
./scripts/schedule.sh --time "tomorrow 09:00" --venue-id 58326 --times "19:00:00" --no-dry-run

# Daily at 9 AM
./scripts/schedule.sh --method cron --recurring "0 9 * * *" --venue-id 58326 --times "19:00:00" --no-dry-run

# Check everything
./scripts/check-schedule.sh

# Watch logs live
tail -f logs/booking_*.log

# Remove all cron jobs
crontab -r
```

