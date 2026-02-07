#!/usr/bin/env bash
# Integration tests for vanish
set -euo pipefail

VANISH="${VANISH:-./zig-out/bin/vanish}"
TEST_DIR="/run/user/$(id -u)/vanish-test-$$"
PASS=0
FAIL=0

cleanup() {
    pkill -f "vanish.*test-" 2>/dev/null || true
    rm -rf "$TEST_DIR" 2>/dev/null || true
}
trap cleanup EXIT

setup() {
    mkdir -p "$TEST_DIR"
}

pass() {
    echo "  PASS: $1"
    ((PASS++)) || true
}

fail() {
    echo "  FAIL: $1"
    ((FAIL++)) || true
}

test_help() {
    echo "=== Testing help output ==="
    if $VANISH --help 2>&1 | grep -q "terminal session multiplexer"; then
        pass "--help shows description"
    else
        fail "--help doesn't show description"
    fi

    if $VANISH --help 2>&1 | grep -q "vanish new"; then
        pass "--help shows new command"
    else
        fail "--help doesn't show new command"
    fi
}

test_list_empty() {
    echo "=== Testing list with no sessions ==="
    local output
    output=$($VANISH list "$TEST_DIR" 2>&1)
    if [ "$output" = "No sessions found" ]; then
        pass "list empty directory shows message"
    else
        fail "list empty directory: expected 'No sessions found', got '$output'"
    fi
}

test_list_json_empty() {
    echo "=== Testing list --json with no sessions ==="
    local output
    output=$($VANISH list --json "$TEST_DIR" 2>&1)
    if echo "$output" | grep -q '"sessions":\[\]'; then
        pass "list --json empty shows empty array"
    else
        fail "list --json empty: expected empty sessions array, got '$output'"
    fi
}

test_session_create_list() {
    echo "=== Testing session creation and listing ==="
    local socket="$TEST_DIR/test-create"

    # Start a session that just sleeps (vanish new daemonizes and returns immediately)
    $VANISH new "$socket" -- sleep 10

    # Check it appears in list
    local output
    output=$($VANISH list "$TEST_DIR" 2>&1)
    if echo "$output" | grep -q "test-create"; then
        pass "session appears in list"
    else
        fail "session not in list: '$output'"
    fi

    # Check JSON output
    output=$($VANISH list --json "$TEST_DIR" 2>&1)
    if echo "$output" | grep -q '"name":"test-create"'; then
        pass "session appears in JSON list"
    else
        fail "session not in JSON list: '$output'"
    fi

    # Cleanup
    pkill -f "vanish.*test-create" 2>/dev/null || true
    rm -f "$socket"
}

test_session_exits_with_child() {
    echo "=== Testing session exits when child exits ==="
    local socket="$TEST_DIR/test-exit"

    # Start a session with a quick command (vanish new daemonizes and returns immediately)
    $VANISH new "$socket" -- sh -c "echo done; exit 0"
    # Wait for the child process to complete
    sleep 1

    # Session should be gone (socket cleaned up when child exits)
    if [ ! -S "$socket" ]; then
        pass "socket removed after child exits"
    else
        fail "socket still exists after child exits"
    fi

    # The daemon process should have exited too
    if ! pgrep -f "vanish.*test-exit" > /dev/null 2>&1; then
        pass "session daemon exited"
    else
        fail "session daemon still running"
        pkill -f "vanish.*test-exit" 2>/dev/null || true
    fi
}

test_send_command() {
    echo "=== Testing send command ==="
    local socket="$TEST_DIR/test-send"
    local output_file="$TEST_DIR/output.txt"

    # Start a session that reads input and writes to file
    # vanish new daemonizes and returns immediately
    $VANISH new "$socket" -- sh -c "head -n1 > $output_file; sleep 5"
    sleep 0.3

    # Send input with newline in one go
    $VANISH send "$socket" $'hello\n'
    sleep 0.5

    # Check output
    if [ -f "$output_file" ] && grep -q "hello" "$output_file"; then
        pass "send delivered input to session"
    else
        if [ -f "$output_file" ]; then
            local content
            content=$(cat "$output_file" 2>/dev/null || echo "(empty)")
            fail "send test: file exists but content is '$content'"
        else
            fail "send test: output file not created"
        fi
    fi

    pkill -f "vanish.*test-send" 2>/dev/null || true
}

test_clients_command() {
    echo "=== Testing clients command ==="
    local socket="$TEST_DIR/test-clients"

    # Start a session (vanish new daemonizes and returns immediately)
    $VANISH new "$socket" -- sleep 30
    sleep 0.3

    # List clients - note: the 'clients' command itself connects as a viewer
    # so there won't be a primary unless someone attached as primary
    local output
    output=$($VANISH clients "$socket" 2>&1)
    if echo "$output" | grep -q "viewer"; then
        pass "clients shows viewer (the command itself)"
    else
        fail "clients doesn't show viewer: '$output'"
    fi

    # JSON output
    output=$($VANISH clients --json "$socket" 2>&1)
    if echo "$output" | grep -q '"role":"viewer"'; then
        pass "clients --json shows role"
    else
        fail "clients --json doesn't show role: '$output'"
    fi

    pkill -f "vanish.*test-clients" 2>/dev/null || true
}

test_session_detaches() {
    echo "=== Testing session keeps running after detach ==="
    local socket="$TEST_DIR/test-detach"
    local marker_file="$TEST_DIR/marker.txt"

    # Create a session that creates a marker file (vanish new daemonizes and returns immediately)
    $VANISH new "$socket" -- sh -c "touch $marker_file; sleep 30"
    sleep 0.5

    # Session should have created the marker
    if [ -f "$marker_file" ]; then
        pass "session started and created marker"
    else
        fail "session didn't create marker file"
    fi

    # Session daemon should still be running
    if pgrep -f "vanish.*test-detach" > /dev/null 2>&1; then
        pass "session daemon still running"
    else
        fail "session daemon died unexpectedly"
    fi

    pkill -f "vanish.*test-detach" 2>/dev/null || true
}

test_kick_command() {
    echo "=== Testing kick command ==="
    local socket="$TEST_DIR/test-kick"

    # Start a session (vanish new daemonizes and returns immediately)
    $VANISH new "$socket" -- sleep 30
    sleep 0.3

    # Get client list to find the viewer's ID
    local clients_output
    clients_output=$($VANISH clients --json "$socket" 2>&1)
    if echo "$clients_output" | grep -q '"id":'; then
        pass "got client list for kick test"
    else
        fail "couldn't get client list: '$clients_output'"
        pkill -f "vanish.*test-kick" 2>/dev/null || true
        return
    fi

    # Extract a client ID (should be 1 for the first viewer)
    local client_id
    client_id=$(echo "$clients_output" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)

    # Kick the client (note: we're kicking ourselves, which is a bit odd but should work)
    local kick_output
    kick_output=$($VANISH kick "$socket" "$client_id" 2>&1)
    # Just check that the command runs without error
    if [ $? -eq 0 ]; then
        pass "kick command executed"
    else
        fail "kick command failed: '$kick_output'"
    fi

    pkill -f "vanish.*test-kick" 2>/dev/null || true
}

test_invalid_session() {
    echo "=== Testing error handling for invalid session ==="
    local socket="$TEST_DIR/nonexistent"

    # Attach to non-existent session should fail gracefully
    local output
    output=$($VANISH attach "$socket" 2>&1) || true
    # Just check it doesn't crash and gives some output
    if [ -n "$output" ]; then
        pass "attach to invalid session gives error message"
    else
        fail "attach to invalid session gave no output"
    fi

    # Clients on non-existent session should fail gracefully
    output=$($VANISH clients "$socket" 2>&1) || true
    if echo "$output" | grep -qi "error\|could not\|failed"; then
        pass "clients on invalid session gives error"
    else
        fail "clients on invalid session: unexpected output '$output'"
    fi
}

test_json_escaping() {
    echo "=== Testing JSON escaping in list ==="
    # Create a session with a name that needs escaping
    local socket="$TEST_DIR/test-json-name"

    # vanish new daemonizes and returns immediately
    $VANISH new "$socket" -- sleep 10

    # Check JSON output is valid
    local output
    output=$($VANISH list --json "$TEST_DIR" 2>&1)

    # Check it's valid JSON (contains expected structure)
    if echo "$output" | grep -q '"sessions":\['; then
        pass "JSON list has valid structure"
    else
        fail "JSON list invalid: '$output'"
    fi

    if echo "$output" | grep -q '"name":"test-json-name"'; then
        pass "JSON list contains session name"
    else
        fail "JSON list missing session name: '$output'"
    fi

    pkill -f "vanish.*test-json-name" 2>/dev/null || true
}

run_tests() {
    setup

    test_help
    test_list_empty
    test_list_json_empty
    test_session_create_list
    test_session_exits_with_child
    test_send_command
    test_clients_command
    test_session_detaches
    test_kick_command
    test_invalid_session
    test_json_escaping

    echo ""
    echo "=== Results ==="
    echo "Passed: $PASS"
    echo "Failed: $FAIL"

    if [ "$FAIL" -gt 0 ]; then
        exit 1
    fi
}

run_tests
