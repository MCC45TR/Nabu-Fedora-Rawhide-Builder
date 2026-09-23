#!/usr/bin/env bash
set -Eeuo pipefail
case " $* " in
    *' --dump '*) printf '/etc/passwd 1 0 digest 0100644 root root 0 0 0 X\n' ;;
    *' --qf '*) printf '/etc/passwd|root|root\n' ;;
    *) exit 2 ;;
esac
