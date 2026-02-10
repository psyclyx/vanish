# vanish shell wrapper for fish — save to ~/.config/fish/functions/v.fish
#
# Usage:
#   v              — pick a session with fzf, attach as primary
#   v <name>       — attach to session (or create it with $SHELL)
#   v <name> <cmd> — create session with command
#   v -l           — list sessions
#
# Requires: vanish, fzf (optional, for interactive picker)

function v
    switch (count $argv)
        case 0
            set -l sessions (vanish list 2>/dev/null | string match -rv ' \(stale\)$')
            if test -z "$sessions"
                echo "No sessions. Usage: v <name> [cmd]" >&2
                return 1
            end
            if not command -q fzf
                echo "Install fzf for interactive selection, or: v <name>" >&2
                echo "" >&2
                vanish list
                return 1
            end
            set -l pick (printf '%s\n' $sessions | fzf --prompt="session> " --no-multi)
            or return 0
            vanish attach -p $pick
        case '*'
            switch $argv[1]
                case -l --list
                    vanish list $argv[2..]
                case '-*'
                    vanish $argv
                case '*'
                    set -l name $argv[1]
                    if vanish list 2>/dev/null | string match -qx $name
                        vanish attach -p $name
                    else if test (count $argv) -eq 1
                        vanish new $name $SHELL
                    else
                        vanish new $argv
                    end
            end
    end
end
