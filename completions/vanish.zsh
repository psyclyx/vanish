#compdef vanish

_vanish_sessions() {
    local -a sessions
    sessions=(${(f)"$(vanish list 2>/dev/null | awk '{print $1}')"})
    _describe 'session' sessions
}

_vanish_client_ids() {
    local session="$1"
    [ -z "$session" ] && return
    local -a ids
    ids=(${(f)"$(vanish clients "$session" 2>/dev/null | awk -F'\t' '/^[0-9]/{print $1}')"})
    _describe 'client id' ids
}

_vanish() {
    local -a global_opts commands

    global_opts=(
        '(-c --config)'{-c,--config}'[config file]:path:_files'
        '-v[verbose output]'
        '-vv[debug output]'
        '(-h --help)'{-h,--help}'[show help]'
    )

    commands=(
        'new:create a new session'
        'attach:attach to an existing session'
        'list:list active sessions'
        'send:send keystrokes to a session'
        'clients:list connected clients'
        'kick:disconnect a client'
        'kill:terminate a session'
        'serve:start HTTP server'
        'otp:generate one-time password'
        'revoke:revoke authentication tokens'
        'print-config:print effective configuration'
    )

    _arguments -C \
        $global_opts \
        '1:command:->command' \
        '*::arg:->args'

    case "$state" in
        command)
            _describe 'command' commands
            ;;
        args)
            case "${words[1]}" in
                new)
                    _arguments \
                        '(-d --detach)'{-d,--detach}'[detach after creating]' \
                        '(-a --auto-name)'{-a,--auto-name}'[generate session name]' \
                        '(-s --serve)'{-s,--serve}'[start HTTP server]' \
                        '1:session name:' \
                        '2:command:_command_names' \
                        '*:args:'
                    ;;
                attach)
                    _arguments \
                        '(-p --primary)'{-p,--primary}'[attach as primary]' \
                        '1:session:_vanish_sessions'
                    ;;
                list)
                    _arguments \
                        '(-j --json)'{-j,--json}'[JSON output]'
                    ;;
                send)
                    _arguments \
                        '1:session:_vanish_sessions' \
                        '2:keys:'
                    ;;
                clients)
                    _arguments \
                        '(-j --json)'{-j,--json}'[JSON output]' \
                        '1:session:_vanish_sessions'
                    ;;
                kick)
                    _arguments \
                        '1:session:_vanish_sessions' \
                        '2:client id:'
                    ;;
                kill)
                    _arguments \
                        '1:session:_vanish_sessions'
                    ;;
                serve)
                    _arguments \
                        '(-b --bind)'{-b,--bind}'[bind address]:address:' \
                        '(-p --port)'{-p,--port}'[port]:port:' \
                        '(-d --daemonize)'{-d,--daemonize}'[run as daemon]'
                    ;;
                otp)
                    _arguments \
                        '--duration[token duration]:duration:' \
                        '--session[scope to session]:session:_vanish_sessions' \
                        '--daemon[daemon-scoped token]' \
                        '--indefinite[indefinite token]' \
                        '--read-only[view-only token]'
                    ;;
                revoke)
                    _arguments \
                        '--all[revoke all tokens]' \
                        '--temporary[revoke temporary tokens]' \
                        '--daemon[revoke daemon tokens]' \
                        '--indefinite[revoke indefinite tokens]' \
                        '--session[revoke session-scoped tokens]:session:_vanish_sessions'
                    ;;
                print-config) ;;
            esac
            ;;
    esac
}

_vanish "$@"
