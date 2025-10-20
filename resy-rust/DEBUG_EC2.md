# Debug EC2 500 Error - With Full Response Logging

The code now prints detailed debug information to help us diagnose the issue.

## Deploy Updated Binary to EC2

```bash
# From your local machine, rebuild and copy to EC2
cd ~/code/resy-cli/resy-rust
cargo build --release

# Copy the new binary to EC2
scp target/release/resy-rust ec2-user@your-ec2-ip:~/resy-cli/resy-rust/target/release/
```

## Run with Debug Output

On your EC2 instance:

```bash
ssh ec2-user@your-ec2-ip
cd ~/resy-cli/resy-rust

# Run and capture ALL output
./scripts/run.sh --venue-id 79633 --party-size 2 --date 2025-10-25 --times "17:00:00" --dry-run 2>&1 | tee debug-output.log
```

## What to Look For

The output will now show:

### 1. **Credentials Being Used**
```
DEBUG: API Key (first 20 chars): VbCklWA54m1ktUbf...
DEBUG: Auth Token (first 20 chars): eyJ0eXAiOiJKV1QiLCJh...
```

**Check:** Do these match what you have in your .env file?

### 2. **URLs Being Called**
```
DEBUG: Fetching venue details from: https://api.resy.com/2/config?venue_id=79633
DEBUG: Fetching slots from: https://api.resy.com/4/find?party_size=2&venue_id=79633&day=2025-10-25&lat=0&long=0
```

### 3. **Response Status**
```
DEBUG: Response status: 200 OK
```
or
```
DEBUG: Response status: 500 Internal Server Error
```

### 4. **Full Error Response Body**
```
DEBUG: Error response body: {"error":"Invalid authentication","code":"auth_failed"}
```

This is the KEY information we need!

### 5. **Headers Sent** (if error occurs)
```
DEBUG: Headers sent:
  authorization: ResyAPI api_key="VbCklWA54m1ktUbf..."
  x-resy-auth-token: "eyJ0eXAiOiJKV1Q..."
```

## Common Issues to Check

### Issue 1: Credentials Have Extra Characters

If you see:
```
DEBUG: API Key (first 20 chars): "VbCklWA54m1ktUbf...
```

Notice the **`"`** at the beginning? That means your .env file has quotes!

**Fix:**
```bash
nano .env
# Remove quotes:
# Wrong: RESY_API_KEY="abc123"
# Right: RESY_API_KEY=abc123
```

### Issue 2: Credentials Have Whitespace

If the debug shows weird lengths:
```
DEBUG: API Key length: 45  # Should be around 16-32
```

**Fix:**
```bash
./scripts/fix-env.sh
```

### Issue 3: Wrong Credentials

If the response body says:
```
DEBUG: Error response body: {"error":"Invalid API key"}
```

Your credentials are wrong or expired. Get fresh ones.

### Issue 4: Hidden Characters

Run:
```bash
cat -A .env
```

If you see `^M` at the end of lines:
```
RESY_API_KEY=abc123^M$
```

**Fix:**
```bash
sed -i 's/\r$//' .env
```

## Send Me the Output

After running with debug output, send me:

```bash
cat debug-output.log
```

Specifically, I need to see:
1. The first 20 chars of API Key and Auth Token
2. The response status (200, 500, etc.)
3. **The full error response body**
4. The headers that were sent

## Quick Commands

```bash
# 1. Deploy new binary
scp target/release/resy-rust ec2-user@your-ec2-ip:~/resy-cli/resy-rust/target/release/

# 2. On EC2, run with debug
cd ~/resy-cli/resy-rust
./scripts/run.sh --venue-id 79633 --times "17:00:00" --dry-run 2>&1 | tee debug.log

# 3. Check what credentials the binary is actually seeing
cat debug.log | grep "DEBUG: API Key"
cat debug.log | grep "DEBUG: Auth Token"

# 4. Check the response
cat debug.log | grep "DEBUG: Response status"
cat debug.log | grep "DEBUG: Error response body"

# 5. Share the output
cat debug.log
```

## Compare with Working curl

On EC2, also run the test-connection.sh to confirm curl still works:

```bash
./scripts/test-connection.sh 79633 2>&1 | tee curl-test.log
```

Then we can compare:
- What curl sends (working) vs what Rust sends (failing)
- The credentials curl uses vs the credentials Rust uses

This will tell us exactly what's different!

