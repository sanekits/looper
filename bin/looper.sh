#!/bin/bash
# looper.sh
#
#    Given a shell command, this puts it into an endless loop with optional  continuation prompt at the end of each iteration.
#
#   e.g.:
#
#   $  looper.sh 'cmd arg1 arg2 | cmd2 arg3 arg4'   # Run cmd with its args over and over, prompting for restart each time.
#
#  or...
#
#  $ looper.sh <<< "echo \$(date)"
#
#
canonpath() {
    builtin type -t realpath.sh &>/dev/null && {
        realpath.sh -f "$@"
        return
    }
    builtin type -t readlink &>/dev/null && {
        command readlink -f "$@"
        return
    }
    # Fallback: Ok for rough work only, does not handle some corner cases:
    ( builtin cd -L -- "$(command dirname -- "$0")" || exit; builtin echo "$(command pwd -P)/$(command basename -- "$0")" )
}

scriptName="$(canonpath "$0")"

color_red="\033[;31m"
color_green="\033[;32m"
color_yellow="\033[;33m"
color_none="\033[;0m"
loopcmd_configdir=$HOME/.config/loop_cmd.d

die() {
    builtin echo "ERROR($(command basename -- "${scriptName}")): $*" >&2
    builtin exit 1
}


function loop_edit {
    if which vipe.sh &>/dev/null; then
        echo "$@" | vipe.sh
    else
        echo >&2
        echo -e "${color_red}  --> Sorry, vipe.sh not available.  Ctrl+D to end edit.${color_none}" >&2
        echo -e "${color_yellow}  --> Command is: [${color_green}$*${color_yellow}]" >&2
        cat
    fi
}

function loop_show {
    echo -e "${color_green}Command is: [${color_none}${cmd} $*${color_green}]"
    echo -e "Named as: ${color_none}${cmd_name}"
}

function update_loopcmd_name {
    mkdir -p "${loopcmd_configdir}"
    echo -ne "${color_green}
  --> Assign a name to this command: ${color_none}" >&2
    read -re -i "$1"
    if [[ -z $REPLY ]]; then
        return 1
    fi
    echo "$cmd" > "${loopcmd_configdir}/$REPLY"
    echo -e "  ${color_green}--> (Command was saved as ${color_none}$loopcmd_configdir/$REPLY${color_green})" >&2
    echo "$REPLY"
}


function loop_cmd {
    autorepeat_secs=0
    

    if [[ $1 == --rerun ]]; then
        # Re-run a named command from ~/.config/loop_cmd.d:
        shift
        cmd_name=$1
        [[ -f $loopcmd_configdir/${cmd_name} ]] || ( die "cant find ${loopcmd_configdir}/${cmd_name}") || return
        cmd="$(cat "$loopcmd_configdir/${cmd_name}")"
        shift
    elif [[ $1 == --auto ]]; then
        # Turn on autorepeat_secs immediately
        shift
        autorepeat_secs=3
     elif [[ $1 == "-" ]]; then
         shift
         [[ $# -gt 0 ]] && echo "Args for command: [$*]" >&2
         [[ -t 0 ]] && echo "Enter command(s) , then ^D to execute:" >&2
         cmd="$(cat)"
     else
        # First arg is command to run:
        cmd=$1
        shift
        if [[ -z $cmd ]]; then
            cmd="$(loop_edit '# Enter loop command. (You may delete this line if you wish)
    ')"
        fi
    fi
    nloop=1
    while true; do
        eval "$cmd $*"
        res=$?
        if (( res == 0 )); then
            echo -e "${color_yellow}<<-- loop_cmd[${nloop}]: ${color_green}OK${color_none}"
        else
            echo -e "${color_yellow}<<-- loop_cmd[${nloop}]: ${color_red}FAIL: $res
    ${color_yellow}Command was: [${color_none}$cmd $*${color_yellow}]"
        fi

        while true; do
            echo -ne "${color_yellow}[A]gain, auto[R]epeat, [E]dit, [S]how, [N]ame+save, s[H]ell or [Q]uit:${color_none}"

            unset REPLY

            TMOUT=$autorepeat_secs
            read -rn 1  </dev/tty
            TMOUT=0
            case $REPLY in
                q|Q)
                    return $?;
                    ;;
                a|A)
                    echo ""
                    break;
                    ;;
                r|R)
                    if (( autorepeat_secs > 0 )) ; then
                        autorepeat_secs=0
                        printf "\nAuto-repeat OFF\n"
                    else
                        autorepeat_secs=3
                        printf "\nAuto-repeat ON, hit R to disable\n"
                    fi
                    break;
                    ;;
                e|E)
                    cmd=$(loop_edit "$cmd")
                    echo ""
                    break
                    ;;
                s|S)
                    echo ""
                    loop_show "$@"
                    continue
                    ;;
                h|H)
                    echo
                    echo -e "${color_yellow}Entering subshell, type exit to return to repl:${color_none}"
                    Ps1Tail=loop $SHELL
                    echo ""
                    continue
                    ;;
                n|N)
                    cmd_name=$(update_loopcmd_name "$cmd_name")
                    echo ""
                    continue
                    ;;

                *)
                    if (( autorepeat_secs > 0 )); then
                        echo ""
                        break
                    fi
                    echo -e "${color_red} -->> loop_cmd doesn't understand: $REPLY${color_none}"
                    ;;
            esac
        done

    (( nloop++ ))
    done
}

[[ -z ${sourceMe} ]] && {
    loop_cmd "$@"
    exit
}
true
