# Troubleshooting Guide

## 500 Internal Server Error on EC2

**Symptom:**
```
⏳ Polling for slots... (Failed to fetch slots: 500 Internal Server Error)
```

**Most Common Cause:** Invalid or missing credentials

### Quick Fix

1. **Run the diagnostic tool:**
   ```bash
   ./scripts/test-connection.sh 79633
   ```

2. **Check your .env file:**
   ```bash
   cat .env
   ```

3. **Common issues:**

   ❌ **Wrong format:**
   ```bash
   # BAD - has spaces around =
   RESY_API_KEY = abc123
   
   # BAD - has quotes
   RESY_API_KEY="abc123"
   
   # BAD - still has default value
   RESY_API_KEY=your_api_key_here
   ```

   ✅ **Correct format:**
   ```bash
   RESY_API_KEY=abc123def456
   RESY_AUTH_TOKEN=xyz789uvw012
   ```

4. **Get fresh credentials:**
   
   a. Go to https://resy.com and log in
   
   b. Open DevTools (F12)
   
   c. Go to Network tab
   
   d. Search for a restaurant
   
   e. Find an `api.resy.com` request
   
   f. Look at Request Headers:
   ```
   authorization: ResyAPI api_key="YOUR_KEY_HERE"
   x-resy-auth-token: YOUR_TOKEN_HERE
   ```
   
   g. Copy just the values (no quotes for auth token)

5. **Update .env on EC2:**
   ```bash
   nano .env
   # Paste your actual credentials
   # Save with Ctrl+O, Enter, Ctrl+X
   ```

6. **Test again:**
   ```bash
   ./scripts/test-connection.sh 79633
   ```

## Other Common Issues

### Issue: "Binary not found"

**Symptom:**
```
Error: Binary not found at /path/to/target/release/resy-rust
```

**Fix:**
```bash
cargo build --release
```

### Issue: "atd not running"

**Symptom:**
```
Can't open /var/run/atd.pid to signal atd. No atd running?
```

**Fix:**
```bash
sudo systemctl start atd
sudo systemctl enable atd
```

### Issue: Network timeout

**Symptom:**
```
Failed to fetch slots: error sending request
```

**Fix:**
```bash
# Check connectivity
ping api.resy.com
curl -I https://api.resy.com

# Check firewall
sudo ufw status

# If using AWS, check Security Group allows outbound HTTPS
```

### Issue: Credentials keep expiring

**Cause:** Resy periodically rotates credentials

**Fix:**
1. Set up a reminder to refresh credentials monthly
2. Run test-connection.sh regularly
3. Consider scripting credential refresh (advanced)

### Issue: Timezone mismatch

**Symptom:** Booking runs at wrong time

**Fix:**
```bash
# Check timezone
timedatectl

# Set timezone
sudo timedatectl set-timezone America/New_York

# Verify
date
```

### Issue: Slots not found even though available

**Cause:** Time format mismatch

**Fix:**
Ensure times are in `HH:MM:SS` format:
```bash
# CORRECT
--times "18:00:00,19:00:00"

# WRONG
--times "18:00,19:00"
--times "6:00 PM"
```

### Issue: Job didn't run on schedule

**For `at` jobs:**
```bash
# Check if scheduled
atq

# Check atd status
sudo systemctl status atd

# Check logs
sudo journalctl -u atd
```

**For `cron` jobs:**
```bash
# Check if scheduled
crontab -l

# Check cron logs
sudo grep CRON /var/log/syslog   # Ubuntu/Debian
sudo journalctl -u crond         # RHEL/CentOS
```

### Issue: Permission denied

**Symptom:**
```
bash: ./scripts/run.sh: Permission denied
```

**Fix:**
```bash
chmod +x scripts/*.sh
```

### Issue: curl not found

**Fix:**
```bash
# Ubuntu/Debian
sudo apt-get install curl

# RHEL/CentOS
sudo yum install curl
```

## Debugging Commands

### Test API manually with curl

```bash
source .env

curl -v -X GET "https://api.resy.com/2/config?venue_id=58326" \
  -H "authorization: ResyAPI api_key=\"${RESY_API_KEY}\"" \
  -H "x-resy-auth-token: ${RESY_AUTH_TOKEN}" \
  -H "x-resy-universal-auth: ${RESY_AUTH_TOKEN}" \
  -H "user-agent: Mozilla/5.0" \
  -H "origin: https://resy.com"
```

### Check environment variables

```bash
source .env
echo "API Key: ${RESY_API_KEY:0:20}..."
echo "Auth Token: ${RESY_AUTH_TOKEN:0:20}..."
```

### View recent bookings

```bash
ls -lt logs/
tail -50 logs/booking_*.log
```

### Check system resources

```bash
# Disk space
df -h

# Memory
free -h

# CPU
top
```

## Getting Help

If you're still stuck:

1. **Run diagnostics:**
   ```bash
   ./scripts/test-connection.sh 79633 > diagnostic.log 2>&1
   cat diagnostic.log
   ```

2. **Check logs:**
   ```bash
   cat logs/booking_*.log | tail -100
   ```

3. **Verify setup:**
   ```bash
   ./scripts/check-schedule.sh
   ```

4. **Test manually:**
   ```bash
   # Simplest possible test
   VENUE_ID=79633 TIMES="17:00:00" DRY_RUN=true ./scripts/run.sh
   ```

## Quick Checklist

When something doesn't work:

- [ ] `.env` file exists and has actual credentials (not defaults)
- [ ] Credentials have no quotes or extra spaces
- [ ] Binary is built: `ls target/release/resy-rust`
- [ ] Scripts are executable: `chmod +x scripts/*.sh`
- [ ] `atd` is running: `sudo systemctl status atd`
- [ ] Network works: `curl -I https://api.resy.com`
- [ ] Timezone is correct: `date`
- [ ] Times are in HH:MM:SS format
- [ ] Test script passes: `./scripts/test-connection.sh`

## Prevention

**Best practices to avoid issues:**

1. **Test before scheduling:**
   ```bash
   ./scripts/run.sh --dry-run
   ./scripts/test-connection.sh
   ```

2. **Monitor logs:**
   ```bash
   tail -f logs/booking_*.log
   ```

3. **Keep credentials fresh:**
   - Test weekly with `./scripts/test-connection.sh`
   - Refresh if you see 401/403/500 errors

4. **Use dry-run first:**
   ```bash
   # Always test with --dry-run before actual booking
   ./scripts/schedule.sh --time "09:00" --venue-id 123 --times "19:00:00" --dry-run
   ```

5. **Check status regularly:**
   ```bash
   ./scripts/check-schedule.sh
   ```

