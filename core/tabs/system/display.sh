#!/usr/bin/env bash

# menu: Display
# desc: Switch the built-in display to More Space

. "$COMMON_SCRIPT"
. "$SETTINGS_LIB"

main_display_block() {
    displayplacer list 2>/dev/null | awk '
        function emit() {
            if (block ~ /main display/) printf "%s", block
            block = ""
        }
        /^Persistent screen id:/ { emit(); block = $0 "\n"; in_block = 1; next }
        /^Execute the command below/ { emit(); in_block = 0; next }
        in_block { block = block $0 "\n" }
        END { emit() }
    '
}

display_count() {
    displayplacer list 2>/dev/null | grep -c '^Persistent screen id:'
}

block_field() {
    local block="$1" pattern="$2" field="$3"
    printf '%s\n' "$block" | awk -v p="$pattern" -v f="$field" '$0 ~ p { print $f; exit }'
}

widest_scaled_mode() {
    printf '%s\n' "$1" | awk '
        /^ *mode [0-9]+:/ && /scaling:on/ {
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^res:/) {
                    res = substr($i, 5)
                    split(res, d, "x")
                    if (d[1] + 0 > best + 0) { best = d[1]; widest = res }
                }
            }
        }
        END { if (widest != "") print widest }
    '
}

ensure_displayplacer() {
    if command_exists displayplacer; then
        return 0
    fi

    printf "%b\n" "displayplacer is not installed; installing it..."
    install_package displayplacer || return 1
    command_exists displayplacer
}

set_more_space() {
    local block count id origin degree target current scaling

    if ! ensure_displayplacer; then
        printf "%b\n" "Could not install displayplacer; leaving the display mode alone."
        return 1
    fi

    count="$(display_count)"

    if [ "$count" -gt 1 ]; then
        printf "%b\n" "$count displays are connected; set More Space by hand in System Settings."
        printf "%b\n" "This tab only configures a Mac with a single built-in display."
        return 1
    fi

    block="$(main_display_block)"
    if [ -z "$block" ]; then
        printf "%b\n" "displayplacer reported no main display; leaving the display mode alone."
        return 1
    fi

    id="$(block_field "$block" '^Persistent screen id:' 4)"
    origin="$(block_field "$block" '^Origin:' 2)"
    degree="$(block_field "$block" '^Rotation:' 2)"
    current="$(block_field "$block" '^Resolution:' 2)"
    scaling="$(block_field "$block" '^Scaling:' 2)"
    target="$(widest_scaled_mode "$block")"

    if [ -z "$id" ] || [ -z "$target" ]; then
        printf "%b\n" "Could not read the display modes from displayplacer; leaving the mode alone."
        return 1
    fi

    if [ "$current" = "$target" ] && [ "$scaling" = "on" ]; then
        printf "%b\n" "The display is already at $target scaled, the largest scaled mode."
    else
        printf "%b\n" "Setting the display to $target scaled, up from $current..."
        displayplacer "id:$id res:$target scaling:on origin:$origin degree:$degree" ||
            printf "%b\n" "displayplacer reported a failure; checking what took effect anyway."
    fi

    block="$(main_display_block)"
    verify_value "display resolution" "$target" "$(block_field "$block" '^Resolution:' 2)" exact || true
    verify_value "display scaling" "on" "$(block_field "$block" '^Scaling:' 2)" exact || true
}

display() {
    printf "%b\n" "Configuring the display..."

    if set_more_space; then
        settings_report
    fi
}

display
