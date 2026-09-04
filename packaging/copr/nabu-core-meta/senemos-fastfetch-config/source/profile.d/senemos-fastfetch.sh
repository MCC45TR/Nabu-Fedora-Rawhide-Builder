# Route interactive Fastfetch calls through the SENEMOS locale selector.
# Keep a runtime fallback so an already-open shell remains usable after RPM
# removal, even though this profile fragment itself is removed immediately.
fastfetch() {
    if [ -x /usr/bin/senemos-fastfetch ]; then
        /usr/bin/senemos-fastfetch "$@"
    else
        /usr/bin/fastfetch "$@"
    fi
}
