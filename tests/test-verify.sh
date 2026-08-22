#!/usr/bin/env bash
set -euo pipefail

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$TEST_DIR/.." && pwd)
# shellcheck source=lib/runtime.sh
source "$TEST_DIR/lib/runtime.sh"
require_test_node
TEMP_ROOT=$(mktemp -d /tmp/kde-rice-verify.XXXXXX)

cleanup() {
    case "$TEMP_ROOT" in
        /tmp/kde-rice-verify.*) rm -rf -- "$TEMP_ROOT" ;;
        *) printf 'refusing to clean unexpected test directory: %s\n' "$TEMP_ROOT" >&2 ;;
    esac
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

TARGET_HOME="$TEMP_ROOT/home"
MOCK_BIN="$TEMP_ROOT/bin"
RECEIPT="$TARGET_HOME/.local/state/kde-rice/bootstrap/test"
VERIFY="$REPO_ROOT/scripts/verify"
export XDG_CONFIG_HOME="$TARGET_HOME/.config"
export XDG_DATA_HOME="$TARGET_HOME/.local/share"
export XDG_STATE_HOME="$TARGET_HOME/.local/state"
mkdir -p -- "$TARGET_HOME/.config" "$MOCK_BIN" "$RECEIPT"
touch "$TARGET_HOME/.config/kdeglobals" "$TARGET_HOME/.config/konsolerc" \
    "$TARGET_HOME/.config/plasmarc" "$TARGET_HOME/.config/kwinrc"

bash -n "$VERIFY"
bash -n "$REPO_ROOT/scripts/lib/display-state.sh"
if grep -Eq 'kwriteconfig|plasma-apply|applywindowdecoration|new[[:space:]]+Panel|addWidget|\.remove\(' "$VERIFY" \
    "$REPO_ROOT/layouts/plasma/org.kde.minimalist-v02/contents/panel-state.js"; then
    fail "verify path contains a mutating KDE operation"
fi
if grep -Eq 'command -v node|node - ' "$VERIFY"; then
    fail "verify has an undeclared Node runtime dependency"
fi

cat > "$MOCK_BIN/kreadconfig6" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
file=
group=
key=
[[ ${MOCK_KREAD_FAIL:-0} != 1 ]] || exit 7
while (($#)); do
    case "$1" in
        --file) file=$2; shift 2 ;;
        --group) group=$2; shift 2 ;;
        --key) key=$2; shift 2 ;;
        *) shift ;;
    esac
done
if [[ ${MOCK_IMPLICIT_BREEZE:-0} == 1 ]]; then
    case "$group:$key" in
        'Theme:name' | 'org.kde.kdecoration2:library' | 'org.kde.kdecoration2:theme') exit 0 ;;
    esac
fi
case "$group:$key" in
    General:ColorScheme) printf '%s\n' "${MOCK_COLOR:-BlackMinimal}" ;;
    'Colors:Selection:BackgroundNormal') printf '%s\n' "${MOCK_SELECTION:-145,70,255}" ;;
    'Desktop Entry:DefaultProfile') printf '%s\n' "${MOCK_PROFILE:-BlackMinimal.profile}" ;;
    'Theme:name') printf '%s\n' "${MOCK_PLASMA_THEME:-default}" ;;
    'org.kde.kdecoration2:library') printf '%s\n' "${MOCK_DECORATION_LIBRARY:-org.kde.breeze}" ;;
    'org.kde.kdecoration2:theme') printf '%s\n' "${MOCK_DECORATION_THEME:-Breeze}" ;;
esac
EOF

cat > "$MOCK_BIN/qdbus6" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
script=${4:-}
if [[ $script == *KDE_RICE_PANEL_STATE_JSON* ]]; then
    if [[ ${MOCK_PANEL_MISMATCH:-0} == 1 ]]; then
        printf '%s' 'KDE_RICE_PANEL_STATE_JSON={"schema_version":1,"panel_count":2,"signature":"unknown","known_widgets":{},"target_policy":{"geometry_ok":false,"spacer_ok":false,"active_title_ok":false,"resource_ok":false,"task_manager_ok":false,"tray_ok":false,"clock_ok":false},"panels":[]}'
        printf '%s\n' 'KDE_RICE_PANEL_STATE schema=1 panelCount=2 signature=unknown transition=refuse supported=false targetComplete=false orderValid=false geometryOk=false spacerOk=false activeTitleOk=false resourceOk=false taskManagerOk=false trayOk=false clockOk=false noDuplicateTargetWidgets=false knownTargetWidgets=false knownBuiltInWidgets=false iconTasksKnown=false spacerCount=none spacerExpanding=none activeTitleRevision=none resourceRevision=none taskManagerFill=none taskManagerMaxStripes=none taskManagerIconSpacing=none widgetTypes=none geometry=none removePanelIds=none removeWidgetIds=none removeWidgetEntries=none createPanel=false targetWidgets=none'
    elif [[ ${MOCK_PANEL_SIGNATURE:-minimalist-v04} == minimalist-v04-workspaces ]]; then
        printf '%s' 'KDE_RICE_PANEL_STATE_JSON={"schema_version":1,"panel_count":1,"signature":"minimalist-v04-workspaces","known_widgets":{"org.kde.minimalist.workspaces":true},"target_policy":{"geometry_ok":true,"spacer_ok":true,"active_title_ok":true,"resource_ok":true,"task_manager_ok":true,"tray_ok":true,"clock_ok":true,"pager_ok":true,"workspace_switcher_ok":true,"spacer_count":2,"spacer_expanding":"true,true","active_title_revision":1,"resource_revision":2,"task_manager":{"fill":false,"max_stripes":1,"icon_spacing":0},"workspace_switcher":{"present":true,"package_revision":1}},"panels":[]}'
        printf '%s\n' 'KDE_RICE_PANEL_STATE schema=1 panelCount=1 signature=minimalist-v04-workspaces transition=v04-workspaces-target supported=true targetComplete=true orderValid=true geometryOk=true spacerOk=true activeTitleOk=true resourceOk=true taskManagerOk=true trayOk=true clockOk=true pagerOk=true workspaceSwitcherOk=true noDuplicateTargetWidgets=true knownTargetWidgets=true knownBuiltInWidgets=true iconTasksKnown=true pagerKnown=true workspaceSwitcherKnown=true spacerCount=2 spacerExpanding=true,true activeTitleRevision=1 resourceRevision=2 taskManagerFill=false taskManagerMaxStripes=1 taskManagerIconSpacing=0 pagerDisplayedText=none pagerShowWindowOutlines=none pagerShowWindowIcons=none workspaceSwitcherRevision=1 widgetTypes=org.kde.plasma.kickoff;org.kde.minimalist.workspaces;org.kde.minimalist.activewindowtitle;org.kde.plasma.panelspacer;org.kde.plasma.icontasks;org.kde.plasma.panelspacer;org.kde.minimalist.resources;org.kde.plasma.marginsseparator;org.kde.plasma.kimpanel;org.kde.plasma.systemtray;org.kde.plasma.digitalclock geometry=0,top,horizontal,32,opaque,fill,1920,1920,1920 removePanelIds=none removeWidgetIds=none removeWidgetEntries=none createPanel=false targetWidgets=org.kde.plasma.kickoff,org.kde.minimalist.activewindowtitle,org.kde.plasma.panelspacer,org.kde.plasma.marginsseparator,org.kde.plasma.kimpanel,org.kde.plasma.systemtray,org.kde.plasma.digitalclock'
    elif [[ ${MOCK_PANEL_SIGNATURE:-minimalist-v04} == minimalist-v04-pager ]]; then
        printf '%s' 'KDE_RICE_PANEL_STATE_JSON={"schema_version":1,"panel_count":1,"signature":"minimalist-v04-pager","known_widgets":{"org.kde.plasma.pager":true},"target_policy":{"geometry_ok":true,"spacer_ok":true,"active_title_ok":true,"resource_ok":true,"task_manager_ok":true,"tray_ok":true,"clock_ok":true,"pager_ok":true,"spacer_count":2,"spacer_expanding":"true,true","active_title_revision":1,"resource_revision":2,"task_manager":{"fill":false,"max_stripes":1,"icon_spacing":0},"pager":{"displayed_text":0,"show_window_outlines":false,"show_window_icons":false}},"panels":[]}'
        printf '%s\n' 'KDE_RICE_PANEL_STATE schema=1 panelCount=1 signature=minimalist-v04-pager transition=v04-pager-target supported=true targetComplete=true orderValid=true geometryOk=true spacerOk=true activeTitleOk=true resourceOk=true taskManagerOk=true trayOk=true clockOk=true pagerOk=true noDuplicateTargetWidgets=true knownTargetWidgets=true knownBuiltInWidgets=true iconTasksKnown=true pagerKnown=true spacerCount=2 spacerExpanding=true,true activeTitleRevision=1 resourceRevision=2 taskManagerFill=false taskManagerMaxStripes=1 taskManagerIconSpacing=0 pagerDisplayedText=0 pagerShowWindowOutlines=false pagerShowWindowIcons=false widgetTypes=org.kde.plasma.kickoff;org.kde.plasma.pager;org.kde.minimalist.activewindowtitle;org.kde.plasma.panelspacer;org.kde.plasma.icontasks;org.kde.plasma.panelspacer;org.kde.minimalist.resources;org.kde.plasma.marginsseparator;org.kde.plasma.kimpanel;org.kde.plasma.systemtray;org.kde.plasma.digitalclock geometry=0,top,horizontal,32,opaque,fill,1920,1920,1920 removePanelIds=none removeWidgetIds=none removeWidgetEntries=none createPanel=false targetWidgets=org.kde.plasma.kickoff,org.kde.minimalist.activewindowtitle,org.kde.plasma.panelspacer,org.kde.plasma.marginsseparator,org.kde.plasma.kimpanel,org.kde.plasma.systemtray,org.kde.plasma.digitalclock'
    elif [[ ${MOCK_PANEL_SIGNATURE:-minimalist-v04} == minimalist-v04 ]]; then
        known=${MOCK_WIDGETS_KNOWN:-true}
        builtins=${MOCK_BUILTINS_KNOWN:-true}
        icon_tasks_known=${MOCK_ICON_TASKS_KNOWN:-true}
        geometry_ok=${MOCK_GEOMETRY_OK:-true}
        spacer_ok=${MOCK_SPACER_OK:-true}
        spacer_count=${MOCK_SPACER_COUNT:-2}
        title_ok=${MOCK_TITLE_OK:-true}
        task_ok=${MOCK_TASK_OK:-true}
        tray_ok=${MOCK_TRAY_OK:-true}
        clock_ok=${MOCK_CLOCK_OK:-true}
        no_duplicates=${MOCK_NO_DUPLICATES:-true}
        printf '%s' 'KDE_RICE_PANEL_STATE_JSON={"schema_version":1,"panel_count":1,"signature":"minimalist-v04","known_widgets":{"a":true},"target_policy":{"geometry_ok":true,"spacer_ok":true,"active_title_ok":true,"resource_ok":true,"task_manager_ok":true,"tray_ok":true,"clock_ok":true,"spacer_count":2,"spacer_expanding":"true,true","active_title_revision":1,"resource_revision":2,"task_manager":{"fill":false,"max_stripes":1,"icon_spacing":0,"launchers":"user-owned"},"tray":{},"clock":{}},"panels":[{"location":"top","height":32,"opacity":"opaque","length_mode":"fill","minimum_length":1920,"maximum_length":1920,"length":1920,"widget_types":["org.kde.plasma.kickoff","org.kde.minimalist.activewindowtitle","org.kde.plasma.panelspacer","org.kde.plasma.icontasks","org.kde.plasma.panelspacer","org.kde.minimalist.resources","org.kde.plasma.marginsseparator","org.kde.plasma.kimpanel","org.kde.plasma.systemtray","org.kde.plasma.digitalclock"]}]}'
        printf 'KDE_RICE_PANEL_STATE schema=1 panelCount=1 signature=minimalist-v04 transition=v04-target supported=true targetComplete=true orderValid=true geometryOk=%s spacerOk=%s activeTitleOk=%s resourceOk=true taskManagerOk=%s trayOk=%s clockOk=%s noDuplicateTargetWidgets=%s knownTargetWidgets=%s knownBuiltInWidgets=%s iconTasksKnown=%s spacerCount=%s spacerExpanding=true,true activeTitleRevision=1 resourceRevision=2 taskManagerFill=false taskManagerMaxStripes=1 taskManagerIconSpacing=0 widgetTypes=org.kde.plasma.kickoff;org.kde.minimalist.activewindowtitle;org.kde.plasma.panelspacer;org.kde.plasma.icontasks;org.kde.plasma.panelspacer;org.kde.minimalist.resources;org.kde.plasma.marginsseparator;org.kde.plasma.kimpanel;org.kde.plasma.systemtray;org.kde.plasma.digitalclock geometry=0,top,horizontal,32,opaque,fill,1920,1920,1920 removePanelIds=none removeWidgetIds=none removeWidgetEntries=none createPanel=false targetWidgets=org.kde.plasma.kickoff,org.kde.minimalist.activewindowtitle,org.kde.plasma.panelspacer,org.kde.plasma.marginsseparator,org.kde.plasma.kimpanel,org.kde.plasma.systemtray,org.kde.plasma.digitalclock\n' \
            "$geometry_ok" "$spacer_ok" "$title_ok" "$task_ok" "$tray_ok" "$clock_ok" \
            "$no_duplicates" "$known" "$builtins" "$icon_tasks_known" "$spacer_count"
    elif [[ ${MOCK_PANEL_SIGNATURE:-minimalist-v04} == minimalist-v03 ]]; then
        known=${MOCK_WIDGETS_KNOWN:-true}
        builtins=${MOCK_BUILTINS_KNOWN:-true}
        geometry_ok=${MOCK_GEOMETRY_OK:-true}
        spacer_ok=${MOCK_SPACER_OK:-true}
        title_ok=${MOCK_TITLE_OK:-true}
        tray_ok=${MOCK_TRAY_OK:-true}
        clock_ok=${MOCK_CLOCK_OK:-true}
        no_duplicates=${MOCK_NO_DUPLICATES:-true}
        printf '%s' 'KDE_RICE_PANEL_STATE_JSON={"schema_version":1,"panel_count":1,"signature":"minimalist-v03","known_widgets":{"a":true},"target_policy":{"geometry_ok":true,"spacer_ok":true,"active_title_ok":true,"resource_ok":true,"tray_ok":true,"clock_ok":true,"spacer_expanding":true,"active_title_revision":1,"resource_revision":2,"tray":{},"clock":{}},"panels":[{"location":"top","height":32,"opacity":"opaque","length_mode":"fill","minimum_length":1920,"maximum_length":1920,"length":1920,"widget_types":["org.kde.plasma.kickoff","org.kde.minimalist.activewindowtitle","org.kde.plasma.panelspacer","org.kde.minimalist.resources","org.kde.plasma.marginsseparator","org.kde.plasma.kimpanel","org.kde.plasma.systemtray","org.kde.plasma.digitalclock"]}]}'
        printf 'KDE_RICE_PANEL_STATE schema=1 panelCount=1 signature=minimalist-v03 transition=v03-target supported=true targetComplete=true orderValid=true geometryOk=%s spacerOk=%s activeTitleOk=%s resourceOk=true taskManagerOk=true trayOk=%s clockOk=%s noDuplicateTargetWidgets=%s knownTargetWidgets=%s knownBuiltInWidgets=%s iconTasksKnown=true spacerCount=1 spacerExpanding=true activeTitleRevision=1 resourceRevision=2 taskManagerFill=none taskManagerMaxStripes=none taskManagerIconSpacing=none widgetTypes=org.kde.plasma.kickoff;org.kde.minimalist.activewindowtitle;org.kde.plasma.panelspacer;org.kde.minimalist.resources;org.kde.plasma.marginsseparator;org.kde.plasma.kimpanel;org.kde.plasma.systemtray;org.kde.plasma.digitalclock geometry=0,top,horizontal,32,opaque,fill,1920,1920,1920 removePanelIds=none removeWidgetIds=none removeWidgetEntries=none createPanel=false targetWidgets=org.kde.plasma.kickoff,org.kde.minimalist.activewindowtitle,org.kde.plasma.panelspacer,org.kde.plasma.marginsseparator,org.kde.plasma.kimpanel,org.kde.plasma.systemtray,org.kde.plasma.digitalclock\n' \
            "$geometry_ok" "$spacer_ok" "$title_ok" "$tray_ok" "$clock_ok" \
            "$no_duplicates" "$known" "$builtins"
    else
        known=${MOCK_WIDGETS_KNOWN:-true}
        builtins=${MOCK_BUILTINS_KNOWN:-true}
        geometry_ok=${MOCK_GEOMETRY_OK:-true}
        spacer_ok=${MOCK_SPACER_OK:-true}
        title_ok=${MOCK_TITLE_OK:-true}
        tray_ok=${MOCK_TRAY_OK:-true}
        clock_ok=${MOCK_CLOCK_OK:-true}
        no_duplicates=${MOCK_NO_DUPLICATES:-true}
        printf '%s' 'KDE_RICE_PANEL_STATE_JSON={"schema_version":1,"panel_count":1,"signature":"minimalist-v02","known_widgets":{"a":true},"target_policy":{"geometry_ok":true,"spacer_ok":true,"active_title_ok":true,"tray_ok":true,"clock_ok":true,"spacer_expanding":true,"active_title_revision":1,"tray":{},"clock":{}},"panels":[{"location":"top","height":32,"opacity":"opaque","length_mode":"fill","minimum_length":1920,"maximum_length":1920,"length":1920,"widget_types":["org.kde.plasma.kickoff","org.kde.minimalist.activewindowtitle","org.kde.plasma.panelspacer","org.kde.plasma.marginsseparator","org.kde.plasma.kimpanel","org.kde.plasma.systemtray","org.kde.plasma.digitalclock"],"widget_counts":{"org.kde.plasma.kickoff":1,"org.kde.minimalist.activewindowtitle":1,"org.kde.plasma.panelspacer":1,"org.kde.plasma.marginsseparator":1,"org.kde.plasma.kimpanel":1,"org.kde.plasma.systemtray":1,"org.kde.plasma.digitalclock":1}}]}'
        printf 'KDE_RICE_PANEL_STATE schema=1 panelCount=1 signature=minimalist-v02 transition=already-target supported=true targetComplete=true orderValid=true geometryOk=%s spacerOk=%s activeTitleOk=%s resourceOk=true taskManagerOk=true trayOk=%s clockOk=%s noDuplicateTargetWidgets=%s knownTargetWidgets=%s knownBuiltInWidgets=%s iconTasksKnown=true spacerCount=1 spacerExpanding=true activeTitleRevision=1 resourceRevision=none taskManagerFill=none taskManagerMaxStripes=none taskManagerIconSpacing=none widgetTypes=org.kde.plasma.kickoff;org.kde.minimalist.activewindowtitle;org.kde.plasma.panelspacer;org.kde.plasma.marginsseparator;org.kde.plasma.kimpanel;org.kde.plasma.systemtray;org.kde.plasma.digitalclock geometry=0,top,horizontal,32,opaque,fill,1920,1920,1920 removePanelIds=none removeWidgetIds=none removeWidgetEntries=none createPanel=false targetWidgets=org.kde.plasma.kickoff,org.kde.minimalist.activewindowtitle,org.kde.plasma.panelspacer,org.kde.plasma.marginsseparator,org.kde.plasma.kimpanel,org.kde.plasma.systemtray,org.kde.plasma.digitalclock\n' \
            "$geometry_ok" "$spacer_ok" "$title_ok" "$tray_ok" "$clock_ok" \
            "$no_duplicates" "$known" "$builtins"
    fi
else
    exit 9
fi
EOF
cat > "$MOCK_BIN/fastfetch" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ ${1:-} == --config && -f ${2:-} ]] || exit 64
grep -Fq '"key": "RAM"' "$2" || exit 65
! grep -Fqi localip "$2" || exit 66
EOF
cat > "$MOCK_BIN/busctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${!#}" in
    count) printf '%s\n' '{"type":"u","data":4}' ;;
    rows) printf '%s\n' '{"type":"u","data":1}' ;;
    *) exit 2 ;;
esac
EOF
chmod +x "$MOCK_BIN/kreadconfig6" "$MOCK_BIN/qdbus6" "$MOCK_BIN/fastfetch" "$MOCK_BIN/busctl"

required_assets=(
    .local/share/color-schemes/BlackMinimal.colors
    .local/share/konsole/BlackMinimal.colorscheme
    .local/share/konsole/BlackMinimal.profile
    .local/share/plasma/layout-templates/org.kde.minimalist-v02/metadata.json
    .local/share/plasma/plasmoids/org.kde.minimalist.activewindowtitle/metadata.json
    .local/share/plasma/plasmoids/org.kde.minimalist.activewindowtitle/contents/ui/main.qml
)
for relative in "${required_assets[@]}"; do
    mkdir -p -- "$TARGET_HOME/$(dirname -- "$relative")"
    printf 'fixture\n' > "$TARGET_HOME/$relative"
done

printf 'complete\n' > "$RECEIPT/complete"
rm -rf -- "$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.activewindowtitle"
cp -a -- "$REPO_ROOT/plasmoids/org.kde.minimalist.activewindowtitle" \
    "$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.activewindowtitle"
printf '%s\n' \
    $'.config/kwinoutputconfig.json\tabsent' \
    $'.local/share/kscreen\tabsent' \
    > "$RECEIPT/display-state.after.tsv"
cp -- "$RECEIPT/display-state.after.tsv" "$RECEIPT/display-state.before.tsv"
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    MOCK_PANEL_SIGNATURE=minimalist-v02 \
    "$VERIFY" --receipt "$RECEIPT" --panel-target minimalist-v02 --json > "$TEMP_ROOT/verified.json"
"$NODE_BIN" -e 'const v=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); if(v.status!=="verified"||!v.checks.every(c=>c.ok===true))process.exit(1)' \
    "$TEMP_ROOT/verified.json" || fail "verified JSON result is invalid"
"$NODE_BIN" -e 'const v=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));if(v.checks.some(c=>c.name.includes("wallpaper")))process.exit(1)' \
    "$TEMP_ROOT/verified.json" || fail "verification retained a wallpaper policy check"

# Pre-public receipts may still contain this retired metadata. It is inert and
# must neither gate nor reintroduce wallpaper inspection.
printf 'legacy-private-value\n' > "$RECEIPT/wallpaper-variant"
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    MOCK_PANEL_SIGNATURE=minimalist-v02 \
    "$VERIFY" --receipt "$RECEIPT" --panel-target minimalist-v02 --json \
    > "$TEMP_ROOT/legacy-wallpaper-metadata.json"
"$NODE_BIN" -e 'const v=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));if(v.status!=="verified"||v.checks.some(c=>c.name.includes("wallpaper")))process.exit(1)' \
    "$TEMP_ROOT/legacy-wallpaper-metadata.json" \
    || fail "retired receipt wallpaper metadata still affected verification"

cp -a -- "$REPO_ROOT/layouts/plasma/org.kde.minimalist-v03" \
    "$TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v03"
cp -a -- "$REPO_ROOT/plasmoids/org.kde.minimalist.resources" \
    "$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.resources"
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    MOCK_PANEL_SIGNATURE=minimalist-v03 \
    "$VERIFY" --receipt "$RECEIPT" --panel-target minimalist-v03 --json \
    > "$TEMP_ROOT/verified-v03.json"
"$NODE_BIN" -e 'const v=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); for(const n of ["panel_topology","resource_policy","resource_plasmoid"]){const c=v.checks.find(c=>c.name===n);if(!c||!c.ok)process.exit(1)}' \
    "$TEMP_ROOT/verified-v03.json" || fail "v0.3 verification omitted its resource checks"

cp -a -- "$REPO_ROOT/layouts/plasma/org.kde.minimalist-v04" \
    "$TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v04"
mkdir -p -- "$TARGET_HOME/.config/fastfetch"
cp -- "$REPO_ROOT/config/fastfetch/config.jsonc" \
    "$TARGET_HOME/.config/fastfetch/config.jsonc"
printf 'minimalist-v04\n' > "$RECEIPT/panel-target"
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    "$VERIFY" --receipt "$RECEIPT" --json > "$TEMP_ROOT/verified-v04.json"
"$NODE_BIN" -e 'const v=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); for(const n of ["panel_topology","flexible_spacers","resource_policy","task_manager_policy","resource_plasmoid","layout_template","fastfetch_config","fastfetch_render","receipt_panel_target"]){const c=v.checks.find(c=>c.name===n);if(!c||!c.ok)process.exit(1)}' \
    "$TEMP_ROOT/verified-v04.json" || fail "v0.4.1 verification omitted its centered task checks"

printf 'minimalist-v04-pager\n' > "$RECEIPT/panel-target"
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 \
    KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" KDE_RICE_KWIN_BUSCTL="$MOCK_BIN/busctl" \
    MOCK_PANEL_SIGNATURE=minimalist-v04-pager \
    "$VERIFY" --receipt "$RECEIPT" --panel-target minimalist-v04-pager --json \
    > "$TEMP_ROOT/verified-pager.json"
"$NODE_BIN" -e 'const v=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));for(const n of ["panel_topology","pager_policy","virtual_desktop_count","virtual_desktop_rows","receipt_panel_target"]){const c=v.checks.find(c=>c.name===n);if(!c||!c.ok)process.exit(1)}' \
    "$TEMP_ROOT/verified-pager.json" || fail "Pager verification omitted its panel or KWin checks"

cp -a -- "$REPO_ROOT/plasmoids/org.kde.minimalist.workspaces" \
    "$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.workspaces"
printf 'minimalist-v04-workspaces\n' > "$RECEIPT/panel-target"
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 \
    KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" KDE_RICE_KWIN_BUSCTL="$MOCK_BIN/busctl" \
    MOCK_PANEL_SIGNATURE=minimalist-v04-workspaces \
    "$VERIFY" --receipt "$RECEIPT" --panel-target minimalist-v04-workspaces --json \
    > "$TEMP_ROOT/verified-workspaces.json"
"$NODE_BIN" -e 'const v=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));for(const n of ["panel_topology","workspace_switcher_policy","workspace_plasmoid","virtual_desktop_count","virtual_desktop_rows","receipt_panel_target"]){const c=v.checks.find(c=>c.name===n);if(!c||!c.ok)process.exit(1)}' \
    "$TEMP_ROOT/verified-workspaces.json" \
    || fail "Workspaces verification omitted its package, panel, or KWin checks"
printf 'minimalist-v04\n' > "$RECEIPT/panel-target"

printf '\n// tampered\n' >> "$TARGET_HOME/.config/fastfetch/config.jsonc"
set +e
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    "$VERIFY" --receipt "$RECEIPT" --json > "$TEMP_ROOT/fastfetch-mismatch.json"
status=$?
set -e
[[ $status == 1 ]] || fail "tampered Fastfetch config did not exit 1"
"$NODE_BIN" -e 'const v=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const c=v.checks.find(c=>c.name==="fastfetch_config");if(!c||c.ok)process.exit(1)' \
    "$TEMP_ROOT/fastfetch-mismatch.json" || fail "tampered Fastfetch config was not reported"
cp -- "$REPO_ROOT/config/fastfetch/config.jsonc" "$TARGET_HOME/.config/fastfetch/config.jsonc"

printf 'tampered\n' >> \
    "$TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v04/metadata.json"
set +e
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    "$VERIFY" --receipt "$RECEIPT" --json > "$TEMP_ROOT/layout-template-mismatch.json"
status=$?
set -e
[[ $status == 1 ]] || fail "tampered v0.4.1 layout template did not exit 1"
"$NODE_BIN" -e 'const v=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const c=v.checks.find(c=>c.name==="layout_template");if(!c||c.ok)process.exit(1)' \
    "$TEMP_ROOT/layout-template-mismatch.json" \
    || fail "tampered v0.4.1 layout template was not reported"
cp -- "$REPO_ROOT/layouts/plasma/org.kde.minimalist-v04/metadata.json" \
    "$TARGET_HOME/.local/share/plasma/layout-templates/org.kde.minimalist-v04/metadata.json"

printf 'minimalist-v03\n' > "$RECEIPT/panel-target"
set +e
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    "$VERIFY" --receipt "$RECEIPT" --json > "$TEMP_ROOT/receipt-target-mismatch.json"
status=$?
set -e
[[ $status == 1 ]] || fail "receipt panel-target mismatch did not exit 1"
printf 'minimalist-v04\n' > "$RECEIPT/panel-target"

PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    MOCK_IMPLICIT_BREEZE=1 \
    "$VERIFY" --receipt "$RECEIPT" --json > "$TEMP_ROOT/verified-implicit-breeze.json"
"$NODE_BIN" -e 'const v=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); for(const n of ["plasma_style","window_decoration"]){const c=v.checks.find(c=>c.name===n);if(!c||!c.ok)process.exit(1)}' \
    "$TEMP_ROOT/verified-implicit-breeze.json" || fail "implicit KDE Breeze defaults were not accepted"

chmod 000 "$RECEIPT/display-state.before.tsv"
set +e
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    "$VERIFY" --receipt "$RECEIPT" > "$TEMP_ROOT/unreadable-display-receipt.txt" 2>&1
status=$?
set -e
chmod 600 "$RECEIPT/display-state.before.tsv"
[[ $status == 2 ]] || fail "unreadable display receipt was reported as a state mismatch"

mv -- "$RECEIPT/complete" "$RECEIPT/complete.saved"
printf 'ready\n' > "$RECEIPT/verification-ready"
set +e
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    "$VERIFY" --receipt "$RECEIPT" > "$TEMP_ROOT/external-pending.txt" 2>&1
status=$?
set -e
[[ $status == 2 ]] || fail "external verification accepted an in-progress receipt"
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    KDE_RICE_TRANSACTION_RECEIPT="$RECEIPT" \
    "$VERIFY" --receipt "$RECEIPT" --json > "$TEMP_ROOT/internal-pending.json"
mv -- "$RECEIPT/complete.saved" "$RECEIPT/complete"
rm -- "$RECEIPT/verification-ready"

printf 'verify\t1\n' > "$RECEIPT/failed"
set +e
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    "$VERIFY" --receipt "$RECEIPT" > "$TEMP_ROOT/failed-receipt.txt" 2>&1
status=$?
set -e
[[ $status == 2 ]] || fail "verify accepted a failed bootstrap receipt"
mv -- "$RECEIPT/complete" "$RECEIPT/complete.saved"
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    "$VERIFY" --resume-receipt "$RECEIPT" --json > "$TEMP_ROOT/resumable-receipt.json"
"$NODE_BIN" -e 'const v=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const c=v.checks.find(c=>c.name==="display_configuration_unchanged");if(v.status!=="verified"||!c||!c.ok||!c.actual.includes("baseline=current"))process.exit(1)' \
    "$TEMP_ROOT/resumable-receipt.json" || fail "failed receipt read-only resume verification is invalid"
printf 'changed display\n' > "$TARGET_HOME/.config/kwinoutputconfig.json"
set +e
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    "$VERIFY" --resume-receipt "$RECEIPT" > "$TEMP_ROOT/resume-display-mismatch.txt" 2>&1
status=$?
set -e
[[ $status == 1 ]] || fail "resume verification accepted a changed excluded display fingerprint"
rm -- "$TARGET_HOME/.config/kwinoutputconfig.json"
mv -- "$RECEIPT/complete.saved" "$RECEIPT/complete"
rm -- "$RECEIPT/failed"

set +e
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" MOCK_KREAD_FAIL=1 \
    "$VERIFY" --receipt "$RECEIPT" > "$TEMP_ROOT/kread-failure.txt" 2>&1
status=$?
set -e
[[ $status == 2 ]] || fail "KConfig read failure was reported as a target mismatch"

set +e
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" MOCK_COLOR=Other \
    "$VERIFY" --receipt "$RECEIPT" --json > "$TEMP_ROOT/mismatch.json"
status=$?
set -e
[[ $status == 1 ]] || fail "target mismatch exit code is not 1"
"$NODE_BIN" -e 'const v=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); if(v.status!=="mismatch"||!v.checks.some(c=>c.name==="color_scheme"&&!c.ok))process.exit(1)' \
    "$TEMP_ROOT/mismatch.json" || fail "mismatch JSON omitted the failed color check"

set +e
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" MOCK_WIDGETS_KNOWN=false \
    "$VERIFY" --receipt "$RECEIPT" --json > "$TEMP_ROOT/widget-mismatch.json"
status=$?
set -e
[[ $status == 1 ]] || fail "missing live widget capability must be a mismatch"
"$NODE_BIN" -e 'const v=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); const c=v.checks.find(c=>c.name==="required_live_widgets"); if(!c||c.ok)process.exit(1)' \
    "$TEMP_ROOT/widget-mismatch.json" || fail "missing target widget capability was not reported"

set +e
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" MOCK_BUILTINS_KNOWN=false \
    "$VERIFY" --receipt "$RECEIPT" --json > "$TEMP_ROOT/tray-capability-mismatch.json"
status=$?
set -e
[[ $status == 1 ]] || fail "missing tray service capability must be a mismatch"
"$NODE_BIN" -e 'const v=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); const c=v.checks.find(c=>c.name==="required_live_widgets"); if(!c||c.ok||!c.actual.includes("built-ins=false"))process.exit(1)' \
    "$TEMP_ROOT/tray-capability-mismatch.json" || fail "missing tray service capability was not reported"

set +e
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    MOCK_ICON_TASKS_KNOWN=false \
    "$VERIFY" --receipt "$RECEIPT" --json > "$TEMP_ROOT/icon-tasks-capability-mismatch.json"
status=$?
set -e
[[ $status == 1 ]] || fail "missing Icons-only Task Manager capability must be a mismatch"
"$NODE_BIN" -e 'const v=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const c=v.checks.find(c=>c.name==="required_live_widgets");if(!c||c.ok||!c.actual.includes("icon-tasks=false"))process.exit(1)' \
    "$TEMP_ROOT/icon-tasks-capability-mismatch.json" \
    || fail "missing Icons-only Task Manager capability was not reported"

set +e
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    MOCK_SELECTION=1,2,3 MOCK_PROFILE=Other.profile MOCK_PLASMA_THEME=other MOCK_DECORATION_THEME=Other \
    "$VERIFY" --receipt "$RECEIPT" --json > "$TEMP_ROOT/kconfig-mismatches.json"
status=$?
set -e
[[ $status == 1 ]] || fail "Konsole/Breeze mismatches did not exit 1"
"$NODE_BIN" -e 'const v=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); for(const n of ["selection_color","konsole_default_profile","plasma_style","window_decoration"]){const c=v.checks.find(c=>c.name===n);if(!c||c.ok)process.exit(1)}' \
    "$TEMP_ROOT/kconfig-mismatches.json" || fail "selection/Konsole/Breeze mismatch diagnostics are incomplete"

set +e
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    MOCK_PANEL_MISMATCH=1 "$VERIFY" --receipt "$RECEIPT" --json > "$TEMP_ROOT/panel-mismatches.json"
status=$?
set -e
[[ $status == 1 ]] || fail "panel topology mismatch did not exit 1"
"$NODE_BIN" -e 'const v=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); for(const n of ["panel_count","panel_topology","panel_geometry","flexible_spacers","task_manager_policy","tray_policy","clock_policy","no_duplicate_widgets"]){const c=v.checks.find(c=>c.name===n);if(!c||c.ok)process.exit(1)}' \
    "$TEMP_ROOT/panel-mismatches.json" || fail "panel mismatch diagnostics are incomplete"

set +e
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    MOCK_GEOMETRY_OK=false MOCK_SPACER_OK=false MOCK_SPACER_COUNT=1 MOCK_TITLE_OK=false \
    MOCK_TASK_OK=false MOCK_TRAY_OK=false \
    MOCK_CLOCK_OK=false MOCK_NO_DUPLICATES=false \
    "$VERIFY" --receipt "$RECEIPT" --json > "$TEMP_ROOT/policy-mismatches.json"
status=$?
set -e
[[ $status == 1 ]] || fail "panel policy mismatches did not exit 1"
"$NODE_BIN" -e 'const v=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); for(const n of ["panel_geometry","flexible_spacers","active_title_policy","task_manager_policy","tray_policy","clock_policy","no_duplicate_widgets"]){const c=v.checks.find(c=>c.name===n);if(!c||c.ok)process.exit(1)}' \
    "$TEMP_ROOT/policy-mismatches.json" || fail "panel policy mismatch diagnostics are incomplete"

printf 'tampered\n' >> "$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.activewindowtitle/metadata.json"
set +e
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    "$VERIFY" --receipt "$RECEIPT" --json > "$TEMP_ROOT/plasmoid-mismatch.json"
status=$?
set -e
[[ $status == 1 ]] || fail "tampered project Plasmoid did not exit 1"
"$NODE_BIN" -e 'const v=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); const c=v.checks.find(c=>c.name==="project_plasmoid");if(!c||c.ok)process.exit(1)' \
    "$TEMP_ROOT/plasmoid-mismatch.json" || fail "tampered project Plasmoid was not reported"
rm -rf -- "$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.activewindowtitle"
cp -a -- "$REPO_ROOT/plasmoids/org.kde.minimalist.activewindowtitle" \
    "$TARGET_HOME/.local/share/plasma/plasmoids/org.kde.minimalist.activewindowtitle"

set +e
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" MOCK_COLOR=$'Other\001Scheme' \
    "$VERIFY" --receipt "$RECEIPT" --json > "$TEMP_ROOT/control-character.json"
status=$?
set -e
[[ $status == 1 ]] || fail "control-character mismatch exit code is not 1"
"$NODE_BIN" -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' \
    "$TEMP_ROOT/control-character.json" || fail "verify emitted invalid JSON for a control character"

printf '%s\n' \
    $'.config/kwinoutputconfig.json\tfile:bootstrap-mutated-it' \
    $'.local/share/kscreen\tabsent' \
    > "$RECEIPT/display-state.after.tsv"
set +e
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    "$VERIFY" --receipt "$RECEIPT" --json > "$TEMP_ROOT/bootstrap-display-mismatch.json"
status=$?
set -e
[[ $status == 1 ]] || fail "bootstrap display mutation must be a verification mismatch"
"$NODE_BIN" -e 'const v=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); const c=v.checks.find(c=>c.name==="display_configuration_unchanged"); if(!c||c.ok||!c.actual.includes("bootstrap changed"))process.exit(1)' \
    "$TEMP_ROOT/bootstrap-display-mismatch.json" || fail "before/after display mutation was not reported"
cp -- "$RECEIPT/display-state.before.tsv" "$RECEIPT/display-state.after.tsv"

mkdir -p -- "$TARGET_HOME/.local/share/kscreen"
printf 'display-fixture\n' > "$TARGET_HOME/.local/share/kscreen/output.json"
display_directory_baseline=$(bash -c 'source "$1"; display_state_lines "$2"' bash \
    "$REPO_ROOT/scripts/lib/display-state.sh" "$TARGET_HOME") \
    || fail "display helper could not fingerprint a kscreen directory"
printf '%s\n' "$display_directory_baseline" > "$RECEIPT/display-state.before.tsv"
printf '%s\n' "$display_directory_baseline" > "$RECEIPT/display-state.after.tsv"
printf 'changed-display-fixture\n' > "$TARGET_HOME/.local/share/kscreen/output.json"
set +e
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    "$VERIFY" --receipt "$RECEIPT" --json > "$TEMP_ROOT/kscreen-directory-mismatch.json"
status=$?
set -e
[[ $status == 1 ]] || fail "changed kscreen directory fingerprint did not exit 1"
"$NODE_BIN" -e 'const v=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); const c=v.checks.find(c=>c.name==="display_configuration_unchanged");if(!c||c.ok||!c.actual.includes("differs"))process.exit(1)' \
    "$TEMP_ROOT/kscreen-directory-mismatch.json" || fail "changed kscreen directory was not reported"
rm -rf -- "$TARGET_HOME/.local/share/kscreen"
printf '%s\n' \
    $'.config/kwinoutputconfig.json\tabsent' \
    $'.local/share/kscreen\tabsent' \
    > "$RECEIPT/display-state.before.tsv"
cp -- "$RECEIPT/display-state.before.tsv" "$RECEIPT/display-state.after.tsv"

mkdir -p -- "$TARGET_HOME/.local/share/foreign-display"
ln -s -- foreign-display "$TARGET_HOME/.local/share/kscreen"
set +e
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    "$VERIFY" --receipt "$RECEIPT" > "$TEMP_ROOT/kscreen-symlink.txt" 2>&1
status=$?
set -e
[[ $status == 2 ]] || fail "symlinked excluded display path was not reported as unverifiable"
rm -- "$TARGET_HOME/.local/share/kscreen"

set +e
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    "$VERIFY" --receipt "$TEMP_ROOT/missing" > "$TEMP_ROOT/unable.txt" 2>&1
status=$?
set -e
[[ $status == 2 ]] || fail "unverifiable receipt exit code is not 2"

set +e
PATH="$MOCK_BIN:$PATH" HOME="$TARGET_HOME" KDE_RICE_TEST_MODE=1 KDE_RICE_DBUS_TOOL="$MOCK_BIN/qdbus6" \
    "$VERIFY" > "$TEMP_ROOT/no-receipt.txt" 2>&1
status=$?
set -e
[[ $status == 2 ]] || fail "missing receipt exit code is not 2"

set +e
HOME="$TARGET_HOME" "$VERIFY" --unknown > /dev/null 2>&1
status=$?
set -e
[[ $status == 64 ]] || fail "usage error exit code is not 64"

[[ ! -e $TARGET_HOME/.config/kwinoutputconfig.json ]] || fail "verify wrote display configuration"
printf 'PASS: read-only Minimalist v0.4.1 verification tests\n'
