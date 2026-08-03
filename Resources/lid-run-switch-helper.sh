#!/bin/sh
set -eu

version="9"
fan_control_path="/Library/PrivilegedHelperTools/io.github.achengbatian.lidrunswitch-fanctl"
command_name="${1:-}"

case "$command_name" in
    version)
        [ "$#" -eq 1 ] || exit 64
        /bin/echo "$version"
        ;;
    status)
        [ "$#" -eq 1 ] || exit 64
        [ "$(/usr/bin/id -u)" -eq 0 ] || exit 77
        [ -x "$fan_control_path" ] || exit 69
        [ "$("$fan_control_path" version)" = "3" ] || exit 69
        ;;
    enable)
        [ "$#" -eq 1 ] || exit 64
        [ "$(/usr/bin/id -u)" -eq 0 ] || exit 77
        /usr/bin/pmset -a disablesleep 1
        /usr/bin/pmset -a sleep 0
        ;;
    restore)
        shift
        [ "$#" -eq 3 ] || exit 64
        [ "$(/usr/bin/id -u)" -eq 0 ] || exit 77
        for value in "$@"; do
            case "$value" in
                ''|*[!0-9]*) exit 64 ;;
            esac
        done

        sleep_disabled="$1"
        battery_sleep="$2"
        ac_sleep="$3"

        /usr/bin/pmset -b sleep "$battery_sleep"
        /usr/bin/pmset -c sleep "$ac_sleep"
        /usr/bin/pmset -a disablesleep "$sleep_disabled"
        ;;
    fan-set)
        shift
        [ "$#" -ge 1 ] && [ "$#" -le 8 ] || exit 64
        [ "$(/usr/bin/id -u)" -eq 0 ] || exit 77
        [ -x "$fan_control_path" ] || exit 69
        for value in "$@"; do
            case "$value" in
                ''|*[!0-9]*) exit 64 ;;
            esac
            [ "$value" -ge 0 ] && [ "$value" -le 10000 ] || exit 64
        done
        "$fan_control_path" manual "$@"
        ;;
    fan-auto)
        [ "$#" -eq 1 ] || exit 64
        [ "$(/usr/bin/id -u)" -eq 0 ] || exit 77
        [ -x "$fan_control_path" ] || exit 69
        "$fan_control_path" auto
        ;;
    fan-status)
        [ "$#" -eq 1 ] || exit 64
        [ "$(/usr/bin/id -u)" -eq 0 ] || exit 77
        [ -x "$fan_control_path" ] || exit 69
        "$fan_control_path" status
        ;;
    *)
        exit 64
        ;;
esac
