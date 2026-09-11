#!/usr/bin/bash

check() {
    return 0
}

depends() {
    echo systemd
    return 0
}

install() {
    mkdir -p "$initdir/etc/systemd/system" "$initdir/etc/systemd/system-generators"
    ln_r /dev/null /etc/systemd/system/debug-shell.service
    ln_r /dev/null /etc/systemd/system-generators/systemd-debug-generator
}
