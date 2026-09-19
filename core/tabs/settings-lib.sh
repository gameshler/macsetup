#!/usr/bin/env bash

SETTINGS_FAILED_COUNT=0
SETTINGS_FAILED_KEYS=""

_settings_activate="/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings"

_settings_trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

_settings_normalize_bool() {
    case "$1" in
    true | TRUE | True | yes | YES | Yes | 1) printf '1' ;;
    false | FALSE | False | no | NO | No | 0) printf '0' ;;
    *) printf '%s' "$1" ;;
    esac
}

_settings_needs_sudo() {
    case "$1" in
    /*) return 0 ;;
    *) return 1 ;;
    esac
}

_settings_is_current_host() {
    case "$1" in
    "-currentHost "*) return 0 ;;
    *) return 1 ;;
    esac
}

_settings_strip_scope() {
    _settings_trim "${1#-currentHost }"
}

_settings_write() {
    local domain="$1" key="$2" flag="$3" value="$4"
    local target

    target="$(_settings_strip_scope "$domain")"

    if _settings_is_current_host "$domain"; then
        defaults -currentHost write "$target" "$key" "$flag" "$value" </dev/null 2>/dev/null || true
    elif _settings_needs_sudo "$target"; then
        sudo defaults write "$target" "$key" "$flag" "$value" </dev/null 2>/dev/null || true
    else
        defaults write "$target" "$key" "$flag" "$value" </dev/null 2>/dev/null || true
    fi
}

_settings_read() {
    local domain="$1" key="$2"
    local target

    target="$(_settings_strip_scope "$domain")"

    if _settings_is_current_host "$domain"; then
        defaults -currentHost read "$target" "$key" </dev/null 2>/dev/null || true
    elif _settings_needs_sudo "$target"; then
        sudo defaults read "$target" "$key" </dev/null 2>/dev/null || true
    else
        defaults read "$target" "$key" </dev/null 2>/dev/null || true
    fi
}

_settings_record_failure() {
    local label="$1" detail="$2"

    SETTINGS_FAILED_COUNT=$((SETTINGS_FAILED_COUNT + 1))
    SETTINGS_FAILED_KEYS="${SETTINGS_FAILED_KEYS}  ${label} -- ${detail}
"
}

_settings_restart_owner() {
    local owner="$1"

    case "$owner" in
    "")
        return 0
        ;;
    activateSettings)
        if [ -x "$_settings_activate" ]; then
            "$_settings_activate" -u || true
        fi
        ;;
    *)
        killall "$owner" >/dev/null 2>&1 || true
        ;;
    esac

    return 0
}

verify_value() {
    local label="$1" expected="$2" actual="$3" mode="${4:-exact}"

    case "$mode" in
    contains)
        case "$actual" in
        *"$expected"*) return 0 ;;
        esac
        _settings_record_failure "$label" "expected to contain '$expected'"
        return 1
        ;;
    absent)
        case "$actual" in
        *"$expected"*)
            _settings_record_failure "$label" "expected not to contain '$expected'"
            return 1
            ;;
        esac
        return 0
        ;;
    exact)
        if [ "$(_settings_normalize_bool "$actual")" = "$(_settings_normalize_bool "$expected")" ]; then
            return 0
        fi
        _settings_record_failure "$label" "expected '$expected', read back '$actual'"
        return 1
        ;;
    *)
        _settings_record_failure "$label" "unknown verify mode '$mode'"
        return 1
        ;;
    esac
}

verify_setting() {
    local domain="$1" key="$2" expected="$3" mode="${4:-exact}"

    verify_value "$domain $key" "$expected" "$(_settings_read "$domain" "$key")" "$mode"
}

settings_report() {
    if [ "$SETTINGS_FAILED_COUNT" -eq 0 ]; then
        printf '%b\n' "All settings applied and verified."
        return 0
    fi

    printf '%b\n' "$SETTINGS_FAILED_COUNT setting(s) did not apply:"
    printf '%s' "$SETTINGS_FAILED_KEYS"
    return 0
}

apply_settings() {
    local rows_total=0 applied=0
    local failed_before="$SETTINGS_FAILED_COUNT"
    local keys_before="$SETTINGS_FAILED_KEYS"
    local owners=" "
    local needs_sudo=0
    local line domain key type value owner flag expected actual
    local failed_now=0

    local rows=""
    while IFS= read -r line <&3 || [ -n "$line" ]; do
        line="$(_settings_trim "$line")"
        case "$line" in
        "" | \#*)
            line=""
            continue
            ;;
        esac
        rows="${rows}${line}
"
        line=""
    done 3<&0 </dev/null

    if [ -z "$rows" ]; then
        return 0
    fi

    while IFS= read -r line <&3; do
        [ -n "$line" ] || continue
        IFS='|' read -r domain key type value owner <<EOF
$line
EOF
        domain="$(_settings_strip_scope "$(_settings_trim "$domain")")"
        if _settings_needs_sudo "$domain"; then
            needs_sudo=1
            break
        fi
    done 3<<EOF
$rows
EOF

    if [ "$needs_sudo" -eq 1 ] && command -v sudo_keepalive >/dev/null 2>&1; then
        sudo_keepalive || printf '%b\n' "Continuing without a held sudo session; system-scoped keys may fail."
    fi

    while IFS= read -r line <&3; do
        [ -n "$line" ] || continue

        IFS='|' read -r domain key type value owner <<EOF
$line
EOF
        domain="$(_settings_trim "$domain")"
        key="$(_settings_trim "$key")"
        type="$(_settings_trim "$type")"
        value="$(_settings_trim "$value")"
        owner="$(_settings_trim "$owner")"

        rows_total=$((rows_total + 1))

        if [ -z "$domain" ] || [ -z "$key" ] || [ -z "$type" ]; then
            _settings_record_failure "${domain:-?} ${key:-?}" "malformed row '$line'"
            continue
        fi

        if [ -z "$value" ]; then
            _settings_record_failure "$domain $key" "empty value, which cannot be verified"
            continue
        fi

        case "$type" in
        bool | boolean) flag="-bool" ;;
        int | integer) flag="-int" ;;
        float) flag="-float" ;;
        string) flag="-string" ;;
        *)
            _settings_record_failure "$domain $key" "unknown type '$type'"
            continue
            ;;
        esac

        _settings_write "$domain" "$key" "$flag" "$value"

        actual="$(_settings_read "$domain" "$key")"
        expected="$value"
        if [ "$flag" = "-bool" ]; then
            actual="$(_settings_normalize_bool "$actual")"
            expected="$(_settings_normalize_bool "$expected")"
        fi

        if [ "$actual" = "$expected" ]; then
            applied=$((applied + 1))
            if [ -n "$owner" ]; then
                case "$owners" in
                *" $owner "*) ;;
                *) owners="${owners}${owner} " ;;
                esac
            fi
        else
            _settings_record_failure "$domain $key" "wrote '$value', read back '$actual'"
        fi
    done 3<<EOF </dev/null
$rows
EOF

    for owner in $owners; do
        _settings_restart_owner "$owner"
    done

    printf '%b\n' "Applied $applied of $rows_total setting(s)."

    failed_now=$((SETTINGS_FAILED_COUNT - failed_before))
    if [ "$failed_now" -gt 0 ]; then
        printf '%b\n' "$failed_now setting(s) did not apply:"
        printf '%s' "${SETTINGS_FAILED_KEYS#"$keys_before"}"
    fi

    return 0
}
