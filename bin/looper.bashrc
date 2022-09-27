# looper.bashrc - shell init file for looper sourced from ~/.bashrc

looper-semaphore() {
    [[ 1 -eq  1 ]]
}

loop() {
    type -t loop_cmd &>/dev/null && {
        sourceMe=1 source "$(command which looper.sh)"
    }
    loop_cmd "$@"
}

