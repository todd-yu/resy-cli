# Quick Fix for EC2 500 Error

## The Problem

```
⏳ Polling for slots... (Failed to fetch slots: 500 Internal Server Error)
```

## The Solution (90% of cases)

**Your credentials are invalid, missing, or incorrectly formatted.**

### Step 1: Run the diagnostic tool

```bash
cd ~/resy-cli/resy-rust
./scripts/test-connection.sh 79633
```

This will tell you exactly what's wrong.

### Step 2: Fix your .env file

The most common issues:

#### ❌ Problem 1: Still has default values
```bash
$ cat .env
RESY_API_KEY=your_api_key_here
RESY_AUTH_TOKEN=your_auth_token_here
```

#### ❌ Problem 2: Has spaces around =
```bash
$ cat .env
RESY_API_KEY = abc123
RESY_AUTH_TOKEN = xyz789
```

#### ❌ Problem 3: Has quotes
```bash
$ cat .env
RESY_API_KEY="abc123"
RESY_AUTH_TOKEN="xyz789"
```

#### ✅ Correct format
```bash
$ cat .env
RESY_API_KEY=VbCklWA54m1ktUbf
RESY_AUTH_TOKEN=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...
```

### Step 3: Get fresh credentials

1. **On your local machine** (not EC2), open browser
2. Go to https://resy.com and log in
3. Press F12 to open DevTools
4. Click on "Network" tab
5. Search for any restaurant
6. In the Network tab, find a request to `api.resy.com`
7. Click on it, then click "Headers"
8. Scroll to "Request Headers" section
9. Find these two lines:

```
authorization: ResyAPI api_key="VbCklWA54m1ktUbf"
x-resy-auth-token: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo...
```

10. Copy the values (WITHOUT the quotes for api_key, just the part inside)

### Step 4: Update .env on EC2

```bash
# On your EC2 instance
cd ~/resy-cli/resy-rust
nano .env
```

Paste your credentials:
```
RESY_API_KEY=VbCklWA54m1ktUbf
RESY_AUTH_TOKEN=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo...
```

**Important:**
- No spaces around the `=` sign
- No quotes around the values
- The auth token is usually very long (100+ characters) - copy all of it

Save and exit:
- Press `Ctrl+O` to save
- Press `Enter` to confirm
- Press `Ctrl+X` to exit

### Step 5: Test again

```bash
./scripts/test-connection.sh 79633
```

You should see:
```
✅ Authentication successful!
   Restaurant: Idashi Omakase
```

### Step 6: Try your booking again

```bash
./scripts/run.sh --venue-id 79633 --party-size 2 --date 2025-10-25 --times "17:00:00" --dry-run
```

## If it still doesn't work

### Check the .env file permissions

```bash
ls -la .env
# Should show: -rw-r--r-- or -rw-------
```

### Verify the file has no hidden characters

```bash
cat -A .env
```

Should look like:
```
RESY_API_KEY=VbCklWA54m1ktUbf$
RESY_AUTH_TOKEN=eyJ0eXAiOi...$
```

The `$` at the end is just marking end of line. There should be NO `^M` or other weird characters.

### Re-create the .env file from scratch

```bash
rm .env
cat > .env << 'EOF'
RESY_API_KEY=VbCklWA54m1ktUbf
RESY_AUTH_TOKEN=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.your_token_here
EOF
```

Replace with your actual credentials, then test:
```bash
./scripts/test-connection.sh 79633
```

## Other Possible Causes

### 1. Firewall blocking outbound HTTPS

Test:
```bash
curl -I https://api.resy.com
```

Should return `HTTP/2 200` or similar.

If it times out, check your AWS Security Group allows outbound HTTPS (port 443).

### 2. Credentials expired

Resy credentials can expire. Get fresh ones from your browser and update .env.

### 3. Wrong API endpoint

The code should be using `https://api.resy.com` not `http://` or any other domain.

## Quick Diagnostic

Run this one-liner to test authentication:

```bash
source .env && curl -s "https://api.resy.com/2/config?venue_id=79633" \
  -H "authorization: ResyAPI api_key=\"${RESY_API_KEY}\"" \
  -H "x-resy-auth-token: ${RESY_AUTH_TOKEN}" \
  -H "x-resy-universal-auth: ${RESY_AUTH_TOKEN}" \
  | head -20
```

**If successful**, you'll see JSON with restaurant info.

**If failed**, you'll see an error message or empty response.

## Need More Help?

Run the full diagnostic:
```bash
./scripts/test-connection.sh 79633 2>&1 | tee diagnostic.log
cat diagnostic.log
```

This will give you a complete report of what's working and what's not.

