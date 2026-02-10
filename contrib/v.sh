# vanish shell wrapper — source in .bashrc or .zshrc
#
# Usage:
#   v              — pick a session with fzf, attach as primary
#   v <name>       — attach to session (or create it with $SHELL)
#   v <name> <cmd> — create session with command
#   v -l           — list sessions
#
# Requires: vanish, fzf (optional, for interactive picker)

v() {
    case "${1-}" in
        "")
            _v_pick
            ;;
        -l|--list)
            shift
            vanish list "$@"
            ;;
        -*)
            vanish "$@"
            ;;
        *)
            local name="$1"
            shift
            if _v_session_exists "$name"; then
                vanish attach -p "$name"
            elif [ $# -eq 0 ]; then
                vanish new "$name" "$SHELL"
            else
                vanish new "$name" "$@"
            fi
            ;;
    esac
}

_v_session_exists() {
    vanish list 2>/dev/null | grep -qx "$1"
}

_v_pick() {
    local sessions
    sessions=$(vanish list 2>/dev/null | grep -v ' (stale)$') || true
    if [ -z "$sessions" ]; then
        echo "No sessions. Usage: v <name> [cmd]" >&2
        return 1
    fi
    if ! command -v fzf >/dev/null 2>&1; then
        echo "Install fzf for interactive selection, or: v <name>" >&2
        echo "" >&2
        vanish list
        return 1
    fi
    local pick
    pick=$(echo "$sessions" | fzf --prompt="session> " --no-multi) || return 0
    vanish attach -p "$pick"
}
