function __vanish_sessions
    vanish list 2>/dev/null | string replace -r ' .*' ''
end

function __vanish_needs_command
    set -l cmd (commandline -opc)
    set -l skip_next 0
    for c in $cmd[2..]
        if test $skip_next -eq 1
            set skip_next 0
            continue
        end
        switch $c
            case '-c' '--config'
                set skip_next 1
            case '-*'
                continue
            case '*'
                return 1
        end
    end
    return 0
end

function __vanish_using_command
    set -l cmd (commandline -opc)
    set -l skip_next 0
    for c in $cmd[2..]
        if test $skip_next -eq 1
            set skip_next 0
            continue
        end
        switch $c
            case '-c' '--config'
                set skip_next 1
            case '-*'
                continue
            case '*'
                test "$c" = "$argv[1]"
                return
        end
    end
    return 1
end

# Global options
complete -c vanish -n __vanish_needs_command -s c -l config -rF -d 'Config file'
complete -c vanish -n __vanish_needs_command -s v -d 'Verbose output'
complete -c vanish -n __vanish_needs_command -f -a '-vv' -d 'Debug output'
complete -c vanish -n __vanish_needs_command -s h -l help -d 'Show help'

# Commands
complete -c vanish -n __vanish_needs_command -f -a new -d 'Create a new session'
complete -c vanish -n __vanish_needs_command -f -a attach -d 'Attach to a session'
complete -c vanish -n __vanish_needs_command -f -a list -d 'List active sessions'
complete -c vanish -n __vanish_needs_command -f -a send -d 'Send keystrokes to a session'
complete -c vanish -n __vanish_needs_command -f -a clients -d 'List connected clients'
complete -c vanish -n __vanish_needs_command -f -a kick -d 'Disconnect a client'
complete -c vanish -n __vanish_needs_command -f -a kill -d 'Terminate a session'
complete -c vanish -n __vanish_needs_command -f -a serve -d 'Start HTTP server'
complete -c vanish -n __vanish_needs_command -f -a otp -d 'Generate one-time password'
complete -c vanish -n __vanish_needs_command -f -a revoke -d 'Revoke auth tokens'
complete -c vanish -n __vanish_needs_command -f -a print-config -d 'Print configuration'

# new
complete -c vanish -n '__vanish_using_command new' -s d -l detach -d 'Detach after creating'
complete -c vanish -n '__vanish_using_command new' -s a -l auto-name -d 'Generate session name'
complete -c vanish -n '__vanish_using_command new' -s s -l serve -d 'Start HTTP server'

# attach
complete -c vanish -n '__vanish_using_command attach' -s p -l primary -d 'Attach as primary'
complete -c vanish -n '__vanish_using_command attach' -f -a '(__vanish_sessions)'

# list
complete -c vanish -n '__vanish_using_command list' -s j -l json -d 'JSON output'

# send
complete -c vanish -n '__vanish_using_command send' -f -a '(__vanish_sessions)'

# clients
complete -c vanish -n '__vanish_using_command clients' -s j -l json -d 'JSON output'
complete -c vanish -n '__vanish_using_command clients' -f -a '(__vanish_sessions)'

# kick
complete -c vanish -n '__vanish_using_command kick' -f -a '(__vanish_sessions)'

# kill
complete -c vanish -n '__vanish_using_command kill' -f -a '(__vanish_sessions)'

# serve
complete -c vanish -n '__vanish_using_command serve' -s b -l bind -r -d 'Bind address'
complete -c vanish -n '__vanish_using_command serve' -s p -l port -r -d 'Port'
complete -c vanish -n '__vanish_using_command serve' -s d -l daemonize -d 'Run as daemon'

# otp
complete -c vanish -n '__vanish_using_command otp' -l duration -r -d 'Token duration'
complete -c vanish -n '__vanish_using_command otp' -l session -rf -a '(__vanish_sessions)' -d 'Scope to session'
complete -c vanish -n '__vanish_using_command otp' -l daemon -d 'Daemon-scoped token'
complete -c vanish -n '__vanish_using_command otp' -l indefinite -d 'Indefinite token'
complete -c vanish -n '__vanish_using_command otp' -l read-only -d 'View-only token'

# revoke
complete -c vanish -n '__vanish_using_command revoke' -l all -d 'Revoke all tokens'
complete -c vanish -n '__vanish_using_command revoke' -l temporary -d 'Revoke temporary tokens'
complete -c vanish -n '__vanish_using_command revoke' -l daemon -d 'Revoke daemon tokens'
complete -c vanish -n '__vanish_using_command revoke' -l indefinite -d 'Revoke indefinite tokens'
complete -c vanish -n '__vanish_using_command revoke' -l session -rf -a '(__vanish_sessions)' -d 'Revoke session tokens'
