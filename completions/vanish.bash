_vanish_sessions() {
    vanish list 2>/dev/null | while read -r line; do
        echo "${line%% *}"
    done
}

_vanish_client_ids() {
    local session="$1"
    [ -z "$session" ] && return
    vanish clients "$session" 2>/dev/null | while read -r line; do
        case "$line" in
            [0-9]*) echo "${line%%:*}" ;;
        esac
    done
}

_vanish() {
    local cur prev words cword
    _init_completion || return

    local commands="new attach list send clients kick kill serve otp revoke print-config"

    # Find the subcommand
    local cmd="" cmd_idx=0
    for ((i = 1; i < cword; i++)); do
        case "${words[i]}" in
            -c|--config) ((i++)) ;;
            -v|-vv|-h|--help) ;;
            *)
                cmd="${words[i]}"
                cmd_idx=$i
                break
                ;;
        esac
    done

    # Global options before subcommand
    if [ -z "$cmd" ]; then
        case "$cur" in
            -*)
                COMPREPLY=($(compgen -W "-c --config -v -vv -h --help" -- "$cur"))
                return
                ;;
        esac
        COMPREPLY=($(compgen -W "$commands" -- "$cur"))
        return
    fi

    # Count positional args after subcommand (excluding flags and their values)
    local pos=0
    for ((i = cmd_idx + 1; i < cword; i++)); do
        case "${words[i]}" in
            -*) case "$cmd" in
                    serve) case "${words[i]}" in -b|--bind|-p|--port) ((i++)) ;; esac ;;
                    otp) case "${words[i]}" in --duration|--session) ((i++)) ;; esac ;;
                    revoke) case "${words[i]}" in --session) ((i++)) ;; esac ;;
                    new) case "${words[i]}" in -c|--config) ((i++)) ;; esac ;;
                esac
                ;;
            *) ((pos++)) ;;
        esac
    done

    case "$cmd" in
        new)
            case "$cur" in
                -*) COMPREPLY=($(compgen -W "-d --detach -a --auto-name -s --serve" -- "$cur")) ;;
                *)
                    if [ "$pos" -eq 0 ]; then
                        # Session name
                        COMPREPLY=()
                    else
                        # Command to run
                        COMPREPLY=($(compgen -c -- "$cur"))
                    fi
                    ;;
            esac
            ;;
        attach)
            case "$cur" in
                -*) COMPREPLY=($(compgen -W "-p --primary" -- "$cur")) ;;
                *) COMPREPLY=($(compgen -W "$(_vanish_sessions)" -- "$cur")) ;;
            esac
            ;;
        list)
            COMPREPLY=($(compgen -W "-j --json" -- "$cur"))
            ;;
        send)
            if [ "$pos" -eq 0 ]; then
                COMPREPLY=($(compgen -W "$(_vanish_sessions)" -- "$cur"))
            fi
            ;;
        clients)
            case "$cur" in
                -*) COMPREPLY=($(compgen -W "-j --json" -- "$cur")) ;;
                *) COMPREPLY=($(compgen -W "$(_vanish_sessions)" -- "$cur")) ;;
            esac
            ;;
        kick)
            if [ "$pos" -eq 0 ]; then
                COMPREPLY=($(compgen -W "$(_vanish_sessions)" -- "$cur"))
            elif [ "$pos" -eq 1 ]; then
                local session="${words[cmd_idx + 1]}"
                COMPREPLY=($(compgen -W "$(_vanish_client_ids "$session")" -- "$cur"))
            fi
            ;;
        kill)
            COMPREPLY=($(compgen -W "$(_vanish_sessions)" -- "$cur"))
            ;;
        serve)
            COMPREPLY=($(compgen -W "-b --bind -p --port -d --daemonize" -- "$cur"))
            ;;
        otp)
            COMPREPLY=($(compgen -W "--duration --session --daemon --indefinite --read-only" -- "$cur"))
            case "$prev" in
                --session) COMPREPLY=($(compgen -W "$(_vanish_sessions)" -- "$cur")) ;;
            esac
            ;;
        revoke)
            COMPREPLY=($(compgen -W "--all --temporary --daemon --indefinite --session" -- "$cur"))
            case "$prev" in
                --session) COMPREPLY=($(compgen -W "$(_vanish_sessions)" -- "$cur")) ;;
            esac
            ;;
        print-config)
            ;;
    esac
}

complete -F _vanish vanish
