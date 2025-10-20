# Cloud VM Deployment Guide

Complete guide for deploying and scheduling Resy bookings on a cloud VM.

## Quick Start

### 1. Deploy to VM

**Copy files to your VM:**
```bash
# From your local machine
scp -r resy-rust user@your-vm-ip:~/
```

**SSH into your VM:**
```bash
ssh user@your-vm-ip
cd resy-rust
```

### 2. Run Setup Script

```bash
./scripts/vm-setup.sh
```

This automatically:
- ✅ Installs dependencies (at, cron, Rust)
- ✅ Configures scheduling services
- ✅ Builds the release binary
- ✅ Sets up directories and permissions
- ✅ Creates .env template

### 3. Add Your Credentials

```bash
nano .env
```

Add your Resy API credentials:
```
RESY_API_KEY=your_actual_api_key
RESY_AUTH_TOKEN=your_actual_auth_token
```

### 4. Test It

```bash
./scripts/run.sh
```

### 5. Schedule a Booking

```bash
./scripts/schedule.sh \
  --time "09:00" \
  --venue-id 58326 \
  --times "19:00:00" \
  --no-dry-run
```

## Scheduling Methods

### Method 1: `at` (One-Time Bookings)

**Best for**: Single bookings at specific times

**Schedule for tomorrow at 9 AM:**
```bash
./scripts/schedule.sh \
  --time "tomorrow 09:00" \
  --venue-id 58326 \
  --times "19:00:00,19:30:00" \
  --no-dry-run
```

**Schedule for specific date:**
```bash
./scripts/schedule.sh \
  --time "2025-11-15 09:00" \
  --venue-id 12345 \
  --times "19:00:00" \
  --threads 10 \
  --retries 5 \
  --no-dry-run
```

**View scheduled jobs:**
```bash
atq                    # List all jobs
at -c JOB_NUMBER      # View job details
atrm JOB_NUMBER       # Remove a job
```

### Method 2: `cron` (Recurring Bookings)

**Best for**: Regular bookings (daily, weekly, etc.)

**Daily at 9 AM:**
```bash
./scripts/schedule.sh \
  --method cron \
  --recurring "0 9 * * *" \
  --venue-id 58326 \
  --times "19:00:00" \
  --no-dry-run
```

**Every Monday at 9 AM:**
```bash
./scripts/schedule.sh \
  --method cron \
  --recurring "0 9 * * 1" \
  --venue-id 12345 \
  --times "19:00:00" \
  --no-dry-run
```

**Twice daily (9 AM and 6 PM):**
```bash
# Schedule first booking
./scripts/schedule.sh \
  --method cron \
  --recurring "0 9 * * *" \
  --venue-id 58326 \
  --times "19:00:00" \
  --no-dry-run

# Schedule second booking  
./scripts/schedule.sh \
  --method cron \
  --recurring "0 18 * * *" \
  --venue-id 58326 \
  --times "21:00:00" \
  --no-dry-run
```

**Cron patterns:**
```
* * * * *
│ │ │ │ │
│ │ │ │ └─ Day of week (0-7, 0 and 7 = Sunday)
│ │ │ └─── Month (1-12)
│ │ └───── Day of month (1-31)
│ └─────── Hour (0-23)
└───────── Minute (0-59)

Examples:
0 9 * * *      - Every day at 9:00 AM
0 */2 * * *    - Every 2 hours
0 9 * * 1-5    - Weekdays at 9:00 AM
0 9 1 * *      - First day of each month at 9:00 AM
```

**Manage cron jobs:**
```bash
crontab -l         # List jobs
crontab -e         # Edit jobs
crontab -r         # Remove all jobs
```

### Method 3: `systemd` (Advanced)

**Best for**: Complex scheduling with systemd integration

```bash
./scripts/schedule.sh \
  --method systemd \
  --time "09:00:00" \
  --venue-id 58326 \
  --times "19:00:00" \
  --no-dry-run
```

Then install the generated files:
```bash
sudo cp /tmp/resy-booking-*.service /etc/systemd/system/
sudo cp /tmp/resy-booking-*.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable resy-booking-*.timer
sudo systemctl start resy-booking-*.timer
```

## Monitoring

### Check Scheduled Jobs

```bash
./scripts/check-schedule.sh
```

This shows:
- All scheduled at jobs
- All cron entries
- Recent log files
- Booking statistics

### View Logs

**Latest log:**
```bash
tail -f logs/booking_*.log
```

**All logs:**
```bash
ls -lt logs/
```

**Search for successes:**
```bash
grep "Successfully booked" logs/*.log
```

**Search for failures:**
```bash
grep "Booking failed" logs/*.log
```

### Live Monitoring During Booking

```bash
# In one terminal, schedule the booking
./scripts/schedule.sh --time "09:00" --venue-id 58326 --times "19:00:00" --no-dry-run

# In another terminal, watch the logs
watch -n 1 'tail -20 logs/booking_*.log'
```

## Common Scenarios

### Scenario 1: Book at Restaurant Opening Time

Most restaurants release reservations at 9 AM exactly. Schedule for 1-2 minutes before:

```bash
# Schedule for 8:59:55 AM
./scripts/schedule.sh \
  --time "08:59:55" \
  --venue-id 58326 \
  --times "19:00:00,19:30:00" \
  --threads 10 \
  --retries 5 \
  --poll-interval-ms 100 \
  --poll-timeout-secs 120 \
  --no-dry-run
```

### Scenario 2: Daily Booking for Popular Restaurant

Book every day for the same restaurant:

```bash
./scripts/schedule.sh \
  --method cron \
  --recurring "0 9 * * *" \
  --venue-id 58326 \
  --times "19:00:00,19:30:00,20:00:00" \
  --threads 5 \
  --retries 3 \
  --no-dry-run
```

### Scenario 3: Multiple Restaurants

Schedule different restaurants at different times:

```bash
# Restaurant A at 9 AM
./scripts/schedule.sh --time "09:00" --venue-id 11111 --times "19:00:00" --no-dry-run

# Restaurant B at 10 AM  
./scripts/schedule.sh --time "10:00" --venue-id 22222 --times "20:00:00" --no-dry-run

# Restaurant C at 11 AM
./scripts/schedule.sh --time "11:00" --venue-id 33333 --times "18:00:00" --no-dry-run
```

### Scenario 4: Weekend-Only Bookings

Book only on Saturdays:

```bash
./scripts/schedule.sh \
  --method cron \
  --recurring "0 9 * * 6" \
  --venue-id 58326 \
  --times "19:00:00" \
  --no-dry-run
```

## VM Configuration

### Timezone

**Check current timezone:**
```bash
timedatectl
```

**Set timezone:**
```bash
sudo timedatectl set-timezone America/New_York
```

Common timezones:
- `America/New_York` (EST/EDT)
- `America/Chicago` (CST/CDT)
- `America/Denver` (MST/MDT)
- `America/Los_Angeles` (PST/PDT)

### Keep VM Awake

Most cloud VMs don't sleep, but ensure:

```bash
# Check if VM will stay awake
sudo systemctl status sleep.target

# Disable sleep if needed (usually not necessary on VMs)
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```

### Automatic Log Rotation

Prevent logs from filling disk:

```bash
# Create logrotate config
sudo tee /etc/logrotate.d/resy << EOF
/home/$(whoami)/resy-rust/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
}
EOF
```

## Troubleshooting

### Job Didn't Run

**Check at daemon:**
```bash
sudo systemctl status atd
sudo systemctl start atd
```

**Check cron daemon:**
```bash
sudo systemctl status cron      # or crond
sudo systemctl start cron
```

**Check logs:**
```bash
# System logs
sudo journalctl -u atd
sudo journalctl -u cron

# Resy logs
tail -f logs/booking_*.log
```

### Booking Failed

**Common issues:**

1. **Credentials expired**
   - Get fresh credentials from resy.com
   - Update `.env` file

2. **Slots already taken**
   - Increase `--threads` and `--retries`
   - Decrease `--poll-interval-ms`
   - Schedule earlier (reservations often release 1-2 min late)

3. **Network issues**
   - Check VM internet: `ping api.resy.com`
   - Check firewall: `sudo ufw status`

4. **Timezone mismatch**
   - Verify VM timezone matches booking time
   - Use absolute times: "2025-11-15 09:00"

### View Schedule Didn't Save

**at jobs:**
```bash
# List jobs
atq

# If empty, check at daemon
sudo systemctl status atd
```

**cron jobs:**
```bash
# View current crontab
crontab -l

# If empty, check cron logs
sudo grep CRON /var/log/syslog
```

## Security Best Practices

1. **Protect credentials:**
   ```bash
   chmod 600 .env
   ```

2. **Use SSH keys** (not passwords):
   ```bash
   ssh-copy-id user@your-vm-ip
   ```

3. **Firewall:**
   ```bash
   sudo ufw enable
   sudo ufw allow ssh
   ```

4. **Keep system updated:**
   ```bash
   sudo apt update && sudo apt upgrade
   ```

5. **Monitor logs:**
   ```bash
   # Set up alerts for failures
   grep "Booking failed" logs/*.log | mail -s "Booking Failed" you@example.com
   ```

## Cost Optimization

### Cloud Provider Tips

**AWS EC2:**
- Use t3.micro or t3.small (sufficient)
- Reserve instance for regular use
- Stop when not needed (scheduled bookings don't need 24/7)

**Google Cloud:**
- Use e2-micro (free tier eligible)
- Set up auto-shutdown after booking

**DigitalOcean:**
- $6/month droplet is plenty
- Enable automated backups

### Minimize Costs

```bash
# Schedule VM to start before booking time
# Use your cloud provider's scheduler or:

# AWS - use Lambda to start EC2
# GCP - use Cloud Scheduler
# DO - use cron on another machine to API start
```

## Quick Reference

```bash
# Setup (once)
./scripts/vm-setup.sh

# Schedule booking
./scripts/schedule.sh --time "09:00" --venue-id 58326 --times "19:00:00" --no-dry-run

# Check status
./scripts/check-schedule.sh

# View logs
tail -f logs/booking_*.log

# Remove scheduled job
atrm JOB_NUMBER           # for at
crontab -e                # for cron (delete line)
```

## Support

For issues:
1. Check logs: `tail -f logs/*.log`
2. Verify credentials: `cat .env`
3. Test manually: `./scripts/run.sh`
4. Check schedule: `./scripts/check-schedule.sh`

Happy booking! 🎉

