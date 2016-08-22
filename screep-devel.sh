#!/bin/bash
# this script is intended to be the RetroPie's runcommand-onend.sh
# please, rename it to /opt/retropie/configs/all/runcommand-onend.sh

function echo_xml_safe() {
    output=$(sed 's#\&#\&amp;#g' <<< "$@")
    output=$(
        sed "
            s#\"#\&quot;#g
            s#'#\&apos;#g
            s#<#\&lt;#g
            s#>#\&gt;#g" <<< "$@"
    )
    echo "$output"
}


echo "--- start of $(basename $0) ---" >&2

readonly system="$1"
readonly full_path_rom="$3"
readonly retroarch_cfg="/opt/retropie/configs/all/retroarch.cfg"
readonly system_ra_cfg="/opt/retropie/configs/$system/retroarch.cfg"
readonly gamelist="$HOME/RetroPie/roms/$system/gamelist.xml"
readonly gamelist_user="$HOME/.emulationstation/gamelists/$system/gamelist.xml"
readonly gamelist_global="/etc/emulationstation/gamelists/$system/gamelist.xml"

rom="${full_path_rom##*/}"
rom="${rom%.*}"
image="$rom.png"

source "/opt/retropie/lib/inifuncs.sh"

iniConfig ' = ' '"'

# only go on if the auto_screenshot_filename is false
iniGet "auto_screenshot_filename" "$retroarch_cfg"
if ! [[ "$ini_value" =~ ^(false|0)$ ]]; then
    echo "Auto scraper is off. Exiting..." >&2
    exit 0
fi

# getting the screenshots directory
# try system specific retroarch.cfg, if not found try the global one
iniGet "screenshot_directory" "$system_ra_cfg"
screenshot_dir="$ini_value"
if [[ -z "$screenshot_dir" ]]; then
    iniGet "screenshot_directory" "$retroarch_cfg"
    screenshot_dir="$ini_value"
    if [[ -z "$screenshot_dir" ]]; then
        echo "You must set a path for 'screenshot_directory' in \"retroarch.cfg\"." >&2
        echo "Aborting..." >&2
        exit 1
    fi
fi

# if there is no screenshot named "ROM Name.png", we have nothing to do here
if ! [[ -f "$screenshot_dir/$image" ]]; then
    echo "There is no screenshot for \"$rom\". Exiting..." >&2
    exit 0
fi

# if there is no "customized gamelist.xml", try the user specific,
# if it fails, get the global one
if ! [[ -f "$gamelist" ]]; then
    echo "Copying \"$gamelist_user\" to \"$gamelist\"." >&2

    if ! cp "$gamelist_user" "$gamelist" 2>/dev/null; then
        echo "Failed to copy \"$gamelist_user\"." >&2
        echo "Copying \"$gamelist_global\" to \"$gamelist\"." >&2

        if ! cp "$gamelist_global" "$gamelist" 2>/dev/null; then
            echo "Failed to copy \"$gamelist_global\"." >&2
            echo "Aborting..." >&2
            exit 1
        fi
    fi
fi

# the <image> entry MUST be on a single line and match the pattern:
# anything followed by rom name followed or not by "-image" followed by dot followed by 3 chars
old_img_regex="<image>.*$rom\(-image\)\?\....</image>"

new_img_regex="<image>$(echo_xml_safe "$screenshot_dir/$image")</image>"

# if there is an entry, update the <image> entry
if grep -q "$old_img_regex" "$gamelist"; then
    sed -i "s|$old_img_regex|$new_img_regex|" "$gamelist"

else
    # there is no entry for this game yet, let's create it
    gamelist_entry="
    <game id=\"\" source=\"\">
        <path>$(echo_xml_safe "$full_path_rom")</path>
        <name>$(echo_xml_safe "$rom")</name>
        <desc></desc>
        $new_img_regex
        <releasedate></releasedate>
        <developer></developer>
        <publisher></publisher>
        <genre></genre>
    </game>"
    # escaping it for a safe sed use
    gamelist_entry=$(
        sed '
            s#[&\]#\\&#g
            s#\^#\\^#g
            s#$#\\#' <<< "$gamelist_entry"
    )
    # in the substitution below the trailing n& takes advantage of the
    # backslash in the end of gamelist_entry (OK, this is inelegant, but works)
    sed -i "/<\/gameList>/ s|.*|${gamelist_entry}n&|" "$gamelist"
fi

echo "--- end of $(basename $0) ---" >&2
