#!/usr/bin/env bash
set -euo pipefail

LAB_ROOT="/tmp/lab-linux-triage"

echo "=== Linux Triage Lab Setup ==="
echo "Creating broken environment at ${LAB_ROOT}..."

# Idempotent: clean up any previous run
rm -rf "${LAB_ROOT}"
mkdir -p "${LAB_ROOT}"/{var/log,etc/cron.d,opt/app/config,proc}

# --- Objective 1: Disk full (oversized log files) ---
echo "[1/5] Creating oversized log files..."
dd if=/dev/urandom of="${LAB_ROOT}/var/log/app.log" bs=1M count=200 status=none
dd if=/dev/urandom of="${LAB_ROOT}/var/log/app.log.1" bs=1M count=150 status=none
dd if=/dev/urandom of="${LAB_ROOT}/var/log/app.log.2" bs=1M count=100 status=none
dd if=/dev/urandom of="${LAB_ROOT}/var/log/debug.log" bs=1M count=80 status=none
# Leave a small current syslog that should NOT be deleted
echo "$(date) system operational" > "${LAB_ROOT}/var/log/syslog"

# --- Objective 2: Zombie process ---
echo "[2/5] Spawning zombie process..."
# Create a script that spawns a child and doesn't reap it
cat > "${LAB_ROOT}/zombie-parent.sh" <<'SCRIPT'
#!/usr/bin/env bash
# Parent that creates a zombie child
(exit 0) &
# Don't wait for child — it becomes a zombie
while true; do sleep 60; done
SCRIPT
chmod +x "${LAB_ROOT}/zombie-parent.sh"
# Launch in background; store PID for grading
nohup bash "${LAB_ROOT}/zombie-parent.sh" > /dev/null 2>&1 &
echo $! > "${LAB_ROOT}/proc/zombie-parent.pid"
sleep 1  # Let zombie form

# --- Objective 3: Broken cron job ---
echo "[3/5] Creating broken cron entry..."
cat > "${LAB_ROOT}/etc/cron.d/broken-task" <<'CRON'
# This cron file has errors the student must fix:
# 1. Six fields instead of five+command (extra field)
# 2. Command path does not exist
# 3. Missing output redirection (noisy)
* * * * * * /usr/local/bin/nonexistent-backup --full
CRON

# Create the fixed reference for grading
cat > "${LAB_ROOT}/etc/cron.d/.broken-task.expected" <<'CRON'
# Backup task — runs daily at 2 AM
0 2 * * * /usr/local/bin/backup --full > /dev/null 2>&1
CRON

# --- Objective 4: Bad file permissions ---
echo "[4/5] Setting bad file permissions..."
chmod 777 "${LAB_ROOT}/opt/app/config"
# Create some config files that should be protected
echo "db_password=hunter2" > "${LAB_ROOT}/opt/app/config/database.yml"
echo "api_key=sk-1234567890" > "${LAB_ROOT}/opt/app/config/secrets.yml"
chmod 666 "${LAB_ROOT}/opt/app/config/database.yml"
chmod 666 "${LAB_ROOT}/opt/app/config/secrets.yml"

# --- Objective 5: Broken DNS ---
echo "[5/5] Breaking DNS configuration..."
cat > "${LAB_ROOT}/etc/resolv.conf" <<'DNS'
# Someone broke this
nameserver 999.999.999.999
nameserver not-a-valid-ip
search localdomain
DNS

echo ""
echo "=== Setup Complete ==="
echo "Lab environment created at: ${LAB_ROOT}"
echo ""
echo "Your mission:"
echo "  1. Free disk space (clean up /var/log)"
echo "  2. Kill the zombie process"
echo "  3. Fix the cron job in /etc/cron.d/broken-task"
echo "  4. Fix permissions on /opt/app/config/ (root:root, 750)"
echo "  5. Repair DNS in /etc/resolv.conf"
echo ""
echo "Run ./grade.sh when done to check your work."
