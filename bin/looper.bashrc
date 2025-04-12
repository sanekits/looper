#!/bin/bash
# looper.bashrc - shell init file for looper sourced from ~/.bashrc

looper-semaphore() {
    [[ 1 -eq  1 ]]
}

loop() {
    [[ $(type -t loop_cmd) == function ]] || {
        # Jit-load the loop_cmd function, which does all the heavy lifting:
        #shellcheck disable=1090
        sourceMe=1 source "$(command which looper.sh)"
    }
    loop_cmd "$@"
}

