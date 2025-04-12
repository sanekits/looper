#!/bin/bash
# looper.sh
#
#    Given a shell command, this puts it into an endless loop with optional  continuation prompt at the end of each iteration.
#
#   e.g.:
#
#   $  looper.sh 'cmd arg1 arg2 | cmd2 arg3 arg4'   # Run vloop_cmd with its args over and over, prompting for restart each time.
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

loop_scriptName="$(canonpath "$0")"

loop_color_red="\033[;31m"
loop_color_green="\033[;32m"
loop_color_yellow="\033[;33m"
loop_color_none="\033[;0m"
loopcmd_configdir=$HOME/.config/loop_cmd.d

loop_die() {
    builtin echo "ERROR($(command basename -- "${loop_scriptName}")): $*" >&2
    builtin exit 1
}


function loop_edit {
    if which vipe.sh &>/dev/null; then
        echo "$@" | vipe.sh
    else
        echo >&2
        echo -e "${loop_color_red}  --> Sorry, vipe.sh not available.  Ctrl+D to end edit.${loop_color_none}" >&2
        echo -e "${loop_color_yellow}  --> Command is: [${loop_color_green}$*${loop_color_yellow}]" >&2
        cat
    fi
}

function loop_show {
    echo -e "${loop_color_green}Command is: [${loop_color_none}${vloop_cmd} $*${loop_color_green}]"
    echo -e "Named as: ${loop_color_none}${loop_cmd_name}"
}

function update_loopcmd_name {
    mkdir -p "${loopcmd_configdir}"
    echo -ne "${loop_color_green}
  --> Assign a name to this command: ${loop_color_none}" >&2
    read -re -i "$1"
    if [[ -z $REPLY ]]; then
        return 1
    fi
    echo "$vloop_cmd" > "${loopcmd_configdir}/$REPLY"
    echo -e "  ${loop_color_green}--> (Command was saved as ${loop_color_none}$loopcmd_configdir/$REPLY${loop_color_green})" >&2
    echo "$REPLY"
}

loop_print_help() {
    echo -e "${loop_color_green}Usage:${loop_color_none}"
    echo -e "  looper.sh [options] [command]"
    echo
    echo -e "${loop_color_yellow}Options:${loop_color_none}"
    echo -e "  --rerun NAME Re-run a named command saved in ${loopcmd_configdir}."
    echo -e "  --auto       Automatically repeat the command every 2 seconds."
    echo -e "  -            Read the command from standard input."
    echo
    echo -e "${loop_color_yellow}Examples:${loop_color_none}"
    echo -e "  looper.sh 'echo Hello World'   # Run the command in a loop."
    echo -e "  looper.sh --rerun mycommand    # Re-run a previously saved command."
    echo -e "  looper.sh --auto 'date'        # Automatically repeat the command every 2 seconds."
    echo -e "  looper.sh -                    # Enter commands interactively."
    echo
}

loop_list_saved_cmds() {
    if [[ ! -d $loopcmd_configdir ]]; then
        echo -e "${loop_color_red}No saved commands found. Directory ${loopcmd_configdir} does not exist.${loop_color_none}" >&2
        return 1
    fi

    echo -e "${loop_color_green}Saved Commands:${loop_color_none}"
    for file in "$loopcmd_configdir"/*; do
        [[ -f $file ]] || continue
        cmd_name=$(basename "$file")
        echo -e "${loop_color_yellow}${cmd_name}:${loop_color_none}"
        sed 's/^/  /' "$file" # Indent each line of the command
        echo
    done
    echo "Run 'loop --rerun <command name>' to launch one of these commands"
}

function loop_cmd {
    loop_autorepeat_secs=0

    [[ $# == 0 ]] && { loop_print_help; return ; }
    case  $1 in 
        -h|--help) loop_print_help; return;;
        -l|--list) shift; loop_list_saved_cmds; return ;;
        -a|--auto) shift; loop_autorepeat_secs=2;;
    esac
    if [[ $1 == --rerun ]]; then
        # Re-run a named command from ~/.config/loop_cmd.d:
        shift
        loop_cmd_name=$1
        [[ -f $loopcmd_configdir/${loop_cmd_name} ]] || ( die "cant find ${loopcmd_configdir}/${loop_cmd_name}") || return
        vloop_cmd="$(cat "$loopcmd_configdir/${loop_cmd_name}")"
        shift
     elif [[ $1 == "-" ]]; then
         shift
         [[ $# -gt 0 ]] && echo "Args for command: [$*]" >&2
         [[ -t 0 ]] && echo "Enter command(s) , then ^D to execute:" >&2
         vloop_cmd="$(cat)"
     else
        # First arg is command to run:
        vloop_cmd=$1
        shift
        if [[ -z $vloop_cmd ]]; then
            vloop_cmd="$(loop_edit '# Enter loop command. (You may delete this line if you wish)
    ')"
        fi
    fi
    nloop=1
    while true; do
        eval "$vloop_cmd $*"
        loop_res=$?
        if (( loop_res == 0 )); then
            echo -e "${loop_color_yellow}<<-- loop_cmd[${nloop}]: ${loop_color_green}OK${loop_color_none}"
        else
            echo -e "${loop_color_yellow}<<-- loop_cmd[${nloop}]: ${loop_color_red}FAIL: $loop_res
    ${loop_color_yellow}Command was: [${loop_color_none}$vloop_cmd $*${loop_color_yellow}]"
        fi

        while true; do
            echo -ne "${loop_color_yellow}[A]gain, auto[R]epeat, [E]dit, [S]how, [N]ame+save, s[H]ell or [Q]uit:${loop_color_none}"

            unset REPLY

            TMOUT=$loop_autorepeat_secs
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
                    if (( loop_autorepeat_secs > 0 )) ; then
                        loop_autorepeat_secs=0
                        printf "\nAuto-repeat OFF\n"
                    else
                        loop_autorepeat_secs=2
                        printf "\nAuto-repeat ON, hit R to disable\n"
                    fi
                    break;
                    ;;
                e|E)
                    vloop_cmd=$(loop_edit "$vloop_cmd")
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
                    echo -e "${loop_color_yellow}Entering subshell, type exit to return to repl:${loop_color_none}"
                    Ps1Tail=loop $SHELL
                    echo ""
                    continue
                    ;;
                n|N)
                    loop_cmd_name=$(update_loopcmd_name "$loop_cmd_name")
                    echo ""
                    continue
                    ;;

                *)
                    if (( loop_autorepeat_secs > 0 )); then
                        echo ""
                        break
                    fi
                    echo -e "${loop_color_red} -->> loop_cmd doesn't understand: $REPLY${loop_color_none}"
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
