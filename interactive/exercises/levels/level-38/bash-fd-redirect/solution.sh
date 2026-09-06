#!/bin/bash
# This script separates stdout and stderr into different log files

STDOUT_LOG="/tmp/fd_stdout_$$.log"
STDERR_LOG="/tmp/fd_stderr_$$.log"

run_command() {
    echo "Output: operation successful"
    echo "Error: disk warning" >&2
    echo "Output: data processed"
    echo "Error: memory low" >&2
}

# Fixed: Redirect stdout to its file and stderr to its own file separately
run_command 1>"$STDOUT_LOG" 2>"$STDERR_LOG"

STDOUT_LINES=$(wc -l < "$STDOUT_LOG" 2>/dev/null || echo 0)
STDERR_LINES=$(cat "$STDERR_LOG" 2>/dev/null | wc -l)

if [ "$STDOUT_LINES" -eq 2 ] && [ "$STDERR_LINES" -eq 2 ]; then
    echo "SUCCESS: stdout ($STDOUT_LINES lines) and stderr ($STDERR_LINES lines) separated"
else
    echo "FAIL: Redirect wrong - stdout: $STDOUT_LINES lines, stderr: $STDERR_LINES lines"
fi

rm -f "$STDOUT_LOG" "$STDERR_LOG"
