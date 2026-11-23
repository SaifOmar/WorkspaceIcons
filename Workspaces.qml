import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
    id: root
    moduleName: "saif.workspaces"

    // -----------------------------------------------------------------------
    // Per-monitor workspace blocks (ported from omarchy.workspaces)
    //
    // Every monitor has workspaces 1-10 of its own, which Hyprland numbers in a
    // block of ten per monitor: 1-10, 11-20, and so on (see
    // default/hypr/monitor-workspaces.lua). Each bar shows its own monitor's
    // block, numbered 1-10, whatever monitor shows it.
    readonly property int slots: 10

    readonly property var monitor: {
        var window = root.QsWindow.window;
        var screen = window ? window.screen : null;
        return screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor;
    }
    readonly property string monitorName: root.monitor ? root.monitor.name : ""

    // Connector -> block, from the file Hyprland keeps them in.
    property var blocks: ({})

    function readBlocks(text) {
        var next = {};
        var lines = String(text || "").split("\n");
        for (var i = 0; i < lines.length; i++) {
            var fields = lines[i].split("\t");
            if (fields.length >= 2 && fields[1] !== "")
                next[fields[1]] = parseInt(fields[0], 10);
        }
        root.blocks = next;
    }

    FileView {
        id: blocksFile
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/monitor-workspaces"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.readBlocks(blocksFile.text())
        onLoadFailed: root.readBlocks("")
    }

    function blockOf(id) {
        return Math.floor((id - 1) / root.slots);
    }

    function slotOf(id) {
        return (id - 1) % root.slots + 1;
    }

    // The connector that owns a block, from the same file: guest workspaces
    // are sent home through it. Empty when the file names no monitor for that
    // block — a block whose monitor is unplugged, for one.
    function monitorOfBlock(block) {
        for (var connector in root.blocks) {
            if (root.blocks[connector] === block)
                return connector;
        }
        return "";
    }

    // Per-bar focus, not the globally focused workspace: on this system each
    // monitor lives in its own block, so a bar lights its own monitor's slot.
    function activeWorkspaceId() {
        return root.monitor && root.monitor.activeWorkspace ? root.monitor.activeWorkspace.id : -1;
    }

    // Until Hyprland has written the file, the workspace a monitor shows is in
    // its own block.
    readonly property int block: {
        var block = root.blocks[root.monitorName];
        if (block !== undefined)
            return block;
        var active = root.activeWorkspaceId();
        return active > 0 ? root.blockOf(active) : 0;
    }

    // -----------------------------------------------------------------------
    // NOTE: this is what keeps the widget in sync with Hyprland windows.
    // Window lists are read straight from `hyprctl clients` (the same data
    // hyprctl itself reports) instead of Quickshell's tracked toplevels,
    // which can retain stale/duplicate entries when window titles churn —
    // inflating window counts (phantom "…", wrong icon scaling).
    // Events are debounced so typing-driven title spam doesn't spawn a
    // hyprctl process per keystroke.
    property var wsWindows: ({})   // wsId -> [{ cls, title }]

    function applyClients(jsonText) {
        var arr;
        try {
            arr = JSON.parse(String(jsonText || "[]"));
        } catch (e) {
            return; // keep last good snapshot rather than blanking the bar
        }
        if (!(arr instanceof Array))
            return;
        var map = {};
        for (var i = 0; i < arr.length; i++) {
            var c = arr[i];
            if (!c || c.hidden === true || !c.workspace || !(c.workspace.id > 0))
                continue;
            var id = c.workspace.id;
            if (!(id in map))
                map[id] = [];
            map[id].push({
                cls: String(c.class || ""),
                title: String(c.title || "")
            });
        }
        root.wsWindows = map;
    }

    Timer {
        id: clientRefreshTimer
        interval: 120
        repeat: false
        onTriggered: clientsProc.running = true
    }

    Process {
        id: clientsProc
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.applyClients(text)
        }
    }

    readonly property string defaultIcon: "󰘔"

    readonly property int maxRulePatternLength: 1024
    readonly property int maxMatchInputLength: 512
    readonly property int maxIconLength: 16
    readonly property int maxCompiledRules: 1000

    function intSetting(key, fallback) {
        var v = Math.floor(Number(root.setting(key, fallback)));
        return isFinite(v) ? Math.min(99, Math.max(1, v)) : fallback;
    }

    // User-configurable via this widget's inline shell.json entry, e.g.
    //   { "id": "saif.workspaces", "baseWorkspaceCount": 7, "maxWorkspaceId": 12 }
    // Counts are of slots inside this monitor's block now, not global ids:
    // the bar always shows the first baseWorkspaceCount slots of its own
    // block, plus any others of the block that already exist up to
    // maxWorkspaceId. A count above ten simply reaches the block's end.
    readonly property int baseWorkspaceCount: intSetting("baseWorkspaceCount", 5)
    readonly property int maxWorkspaceId: intSetting("maxWorkspaceId", 10)

    // ---- Icon rule loading -------------------------------------------------
    // Rules live in icons.json next to the plugin (the file users edit), with
    // an optional user override file that survives `omarchy plugin update`.
    // Override rules are matched BEFORE base rules. Both files are watched,
    // so edits apply live without restarting the bar.
    readonly property string baseRulesPath: {
        var url = Qt.resolvedUrl("icons.json").toString();
        if (url.indexOf("file://") !== 0)
            return url;
        var p = url.substring(7);
        try {
            p = decodeURIComponent(p);
        } catch (e) {}
        return p;
    }
    readonly property string overrideRulesPath: Quickshell.env("HOME") + "/.config/omarchy/workspaces-icons.json"

    // Minimal fallback so the widget still works if neither file parses.
    readonly property var fallbackRules: [
        {
            pattern: "firefox|zen|chrom|brave|chrome",
            icon: "󰈹"
        },
        {
            pattern: "kitty|foot|alacritty|ghostty|wezterm|konsole",
            icon: "󰆍"
        },
        {
            pattern: "code|codium|zed",
            icon: "󰨞"
        }
    ]

    property var baseRules: []
    property var overrideRules: []

    // Compiled once per rules change instead of building ~137 RegExp objects
    // per window per render pass like before.
    property var compiledRules: []
    // NOTE: icon resolution must stay free of property writes — every icon
    // list is evaluated inside bindings, and a write there self-invalidates
    // the evaluating binding ("binding loop"), after which Qt disables it
    // and the UI freezes (stuck "…", frozen scaling). Hence no icon cache.

    FileView {
        id: baseIconsFile
        path: root.baseRulesPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.parseRuleText(baseIconsFile.text(), false)
        onLoadFailed: root.parseRuleText("", false)
    }

    FileView {
        id: overrideIconsFile
        path: root.overrideRulesPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.parseRuleText(overrideIconsFile.text(), true)
        onLoadFailed: root.parseRuleText("", true)
    }

    function parseRuleText(text, isOverride) {
        var arr = [];
        try {
            var parsed = JSON.parse(String(text || "[]"));
            if (parsed instanceof Array)
                arr = parsed.filter(function (r) {
                    return r && typeof r.pattern === "string" && r.pattern.length > 0 && r.pattern.length <= root.maxRulePatternLength && typeof r.icon === "string" && r.icon.length > 0 && r.icon.length <= root.maxIconLength;
                });
        } catch (e) {}
        if (isOverride)
            root.overrideRules = arr;
        else
            root.baseRules = arr;
        root.compileRules();
    }

    function compileRules() {
        var list = root.overrideRules.concat(root.baseRules);
        if (list.length === 0)
            list = root.fallbackRules;
        list = list.slice(0, root.maxCompiledRules);
        var out = [];
        for (var i = 0; i < list.length; i++) {
            try {
                out.push({
                    re: new RegExp(list[i].pattern, "i"),
                    icon: list[i].icon
                });
            } catch (e) {} // skip invalid regexes rather than breaking the bar
        }
        root.compiledRules = out;
    }

    // -----------------------------------------------------------------------

    readonly property color fgColor: root.bar ? root.bar.barForeground : Color.foreground
    readonly property color urgentColor: Color.urgent
    readonly property color bgColor: root.bar ? root.bar.background : Color.background

    readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(15)

    function workspaceById(id) {
        var values = Hyprland.workspaces.values;
        for (var i = 0; i < values.length; i++) {
            if (values[i].id === id)
                return values[i];
        }
        return null;
    }

    // This monitor's block, shown as slots: the first baseWorkspaceCount slots,
    // then any others of the block that already exist within maxWorkspaceId.
    // After them come guest workspaces — ones of a monitor that is unplugged,
    // which had no room to join their own block again, that are being shown
    // here. Empty ones are left out: Hyprland is loose with the monitor field
    // of an empty, parked workspace (it reports whichever monitor last touched
    // it), and a phantom entry with no windows on it would otherwise paint a
    // second number on the bar for a workspace that isn't really visiting.
    // Computed once per workspaces change instead of twice per layout
    // pass (it used to be called separately for grid columns AND Repeater
    // model).
    readonly property var workspaceIdList: {
        var ids = [];
        var base = root.block * root.slots;
        for (var n = 1; n <= Math.min(root.baseWorkspaceCount, root.slots); n++)
            ids.push(base + n);
        var values = Hyprland.workspaces.values;
        var guests = [];
        for (var i = 0; i < values.length; i++) {
            var id = values[i].id;
            if (id <= 0)
                continue;
            if (root.blockOf(id) === root.block) {
                if (root.slotOf(id) <= root.maxWorkspaceId && ids.indexOf(id) === -1)
                    ids.push(id);
            } else if (values[i].monitor && values[i].monitor.name === root.monitorName && root.isWorkspaceOccupied(id)) {
                guests.push(id);
            }
        }
        ids.sort(function (left, right) {
            return left - right;
        });
        guests.sort(function (left, right) {
            return left - right;
        });
        return ids.concat(guests);
    }

    function dispatch(expression) {
        if (root.bar)
            root.bar.run("hyprctl dispatch " + Util.shellQuote(expression));
    }

    function focusWorkspace(id) {
        if (!root.bar)
            return;
        id = Math.floor(Number(id));
        if (!isFinite(id) || id < 1)
            return;
        // Everything goes through the omarchy action, which focuses the
        // monitor it names, pulls the workspace home if a move or an unplug
        // left it elsewhere, and then focuses it. That must run through
        // hyprctl — the o.workspaces expressions are omarchy bind actions,
        // and Hyprland.dispatch cannot run them.
        // Sending guests to their own monitor matters: a plain
        // hl.dsp.focus({ workspace = id }) is resolved against whatever
        // monitor is focused, and Hyprland then swaps the view over — stealing
        // a workspace onto the wrong screen, which is how empty slot-five
        // workspaces ended up visiting. THE ID MUST BE A QUOTED STRING in the
        // plain fallback, as this Hyprland silently ignores
        // hl.dsp.focus({ workspace = <number> }).
        if (root.blockOf(id) === root.block)
            root.dispatch("o.workspaces.focus(" + root.slotOf(id) + ", \"" + root.monitorName + "\")");
        else {
            var home = root.monitorOfBlock(root.blockOf(id));
            if (home)
                root.dispatch("o.workspaces.focus(" + root.slotOf(id) + ", \"" + home + "\")");
            else
                root.dispatch("hl.dsp.focus({ workspace = \"" + id + "\" })");
        }
    }

    // A wheel notch moves one entry along the row, and a touchpad adds up its
    // smaller deltas until they make a notch's worth. Holds at either end
    // rather than wrapping, so a touchpad swipe that runs long stops on the
    // last workspace — and a relative e+/e- dispatch is no longer used at all,
    // since it would hop across monitor blocks now that workspaces are per
    // monitor.
    property real scrollAccumulator: 0

    function scrollWorkspaces(delta) {
        if (!root.bar)
            return;
        var wheel = Util.wheelSteps(root.scrollAccumulator, delta);
        root.scrollAccumulator = wheel.remainder;
        if (wheel.steps === 0)
            return;
        var ids = root.workspaceIdList;
        var index = ids.indexOf(root.activeWorkspaceId());
        if (index === -1)
            return;
        var target = ids[Util.clamp(index - wheel.steps, 0, ids.length - 1)];
        if (target !== ids[index])
            root.focusWorkspace(target);
    }

    // ---- Layout mode (ported from omarchy.workspaces) ----------------------
    // The workspace each monitor shows carries its layout: a square tiles, a
    // circle scrolls, and a triangle floats. Clicking the focused one cycles to
    // the next, as Super + L does.

    property string activeMode: "dwindle"
    property bool modeStale: false

    function modeGlyph(mode) {
        if (mode === "scrolling")
            return "󰝥";
        if (mode === "floating")
            return "󰔶";
        return "󱓻";
    }

    // A layout only changes through the layout commands, which ask for a
    // refresh, or a config reload, so each workspace's mode is read once and
    // cached rather than running the script on every workspace switch.
    property var modeCache: ({})
    property int modeGeneration: 0
    property int modeProcWorkspace: -1
    property int modeProcGeneration: 0

    function showActiveMode() {
        var mode = root.modeCache[root.activeWorkspaceId()];
        if (mode !== undefined)
            root.activeMode = mode;
        else
            root.readMode();
    }

    function readMode() {
        if (modeProc.running) {
            root.modeStale = true;
            return;
        }
        var id = root.activeWorkspaceId();
        if (id === -1)
            return;
        root.modeProcWorkspace = id;
        root.modeProcGeneration = root.modeGeneration;
        modeProc.command = ["omarchy-hyprland-workspace-layout-current", String(id)];
        modeProc.running = true;
    }

    function refresh() {
        root.modeCache = ({});
        root.modeGeneration++;
        root.readMode();
    }

    // The layout commands act on the focused workspace, so a click on another
    // monitor's bar focuses that monitor first.
    function cycleLayout() {
        if (!root.bar)
            return;
        var command = "omarchy-hyprland-workspace-layout-toggle";
        if (root.monitor && !root.monitor.focused) {
            command = "hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ monitor = \"" + root.monitorName + "\" })") + " >/dev/null && " + command;
        }
        root.bar.run(command);
    }

    // -----------------------------------------------------------------------
    // Order matters and is preserved exactly as loaded (e.g. the amazon title
    // rule has to stay ahead of the browser class rules, or every Amazon tab
    // in Firefox would show the Firefox icon instead).
    function resolveIcon(cls, title) {
        var rules = root.compiledRules;
        // Titles/classes are attacker-influenced (e.g. webpage <title>) and
        // regexes here run on the UI thread — cap input length so a hostile
        // title can't amplify a pathological pattern into a frozen bar.
        if (title.length > root.maxMatchInputLength)
            title = title.substring(0, root.maxMatchInputLength);
        if (cls.length > root.maxMatchInputLength)
            cls = cls.substring(0, root.maxMatchInputLength);
        for (var i = 0; i < rules.length; i++) {
            if (rules[i].re.test(title))
                return rules[i].icon;
            if (rules[i].re.test(cls))
                return rules[i].icon;
        }
        return root.defaultIcon;
    }

    // Window data comes from the hyprctl clients snapshot (wsWindows) —
    // exactly what Hyprland itself reports, so stale tracker entries can
    // never inflate counts, sizes, or the ellipsis. Pure reads only.
    // (id-keyed: wsWindows is written solely by the clientsProc handler.)
    function workspaceWindowCount(id) {
        var wins = root.wsWindows[id];
        return wins ? wins.length : 0;
    }

    function isWorkspaceOccupied(id) {
        return root.workspaceWindowCount(id) > 0;
    }

    function workspaceIconList(id) {
        var wins = root.wsWindows[id];
        if (!wins)
            return [];
        var icons = [];
        for (var i = 0; i < wins.length; i++) {
            var cls = String(wins[i].cls || "").toLowerCase();
            var title = String(wins[i].title || "").toLowerCase();
            if (!cls && !title)
                icons.push(root.defaultIcon);
            else
                icons.push(root.resolveIcon(cls, title));
        }
        return icons;
    }

    // Horizontal renderer — kept exactly as before (joined string, grows
    // wide, never capped or shrunk).
    function workspaceIconsFor(id) {
        return root.workspaceIconList(id).join(" ");
    }

    // ---- Progressive icon sizing (vertical bars only) ----------------------

    // 1–2 windows: full size, then step down per extra window, floor 0.5.
    function iconScale(count) {
        if (count <= 2)
            return 1.0;
        return Math.max(0.5, 1.0 - 0.15 * (count - 2));
    }

    // Gap between icons rendered at px — proportional to the icon scale.
    function spacingFor(px) {
        return Math.round(Style.spaceReal(3) * px / Style.font.icon);
    }

    TextMetrics {
        id: iconMetrics
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
    }

    // Largest k ≤ icons.length such that k icons at their scaled size plus
    // spacing — reserving room for a trailing "…" when k < length — fits
    // avail. Measured with real glyph advances via TextMetrics (Nerd Font
    // glyphs vary in width), so nothing clips at any font scale. Always
    // allows at least one icon (never a bare "…"). Horizontal bars
    // short-circuit to "all icons".
    // NOTE: this mutates iconMetrics, so it must only ever be called from
    // signal handlers — calling it from a binding would self-trigger
    // (binding loop) because advanceWidth depends on what it writes.
    function fittedIconCount(icons, avail, basePx) {
        if (!root.vertical || avail <= 0)
            return icons.length;
        var px = Math.floor(basePx * root.iconScale(icons.length));
        var gap = root.spacingFor(px);
        iconMetrics.font.pixelSize = px;

        var ellReserve = 0;
        if (icons.length > 1) {
            iconMetrics.text = "…";
            ellReserve = gap + iconMetrics.advanceWidth;
        }

        var acc = 0;
        var count = 0;
        for (var i = 0; i < icons.length; i++) {
            iconMetrics.text = icons[i];
            var step = iconMetrics.advanceWidth + gap;
            var reserve = (i < icons.length - 1) ? ellReserve : 0;
            if (acc + step + reserve > avail && i > 0)
                break; // always show ≥1
            acc += step;
            count++;
        }
        return Math.max(count, 1); // never a bare "…"
    }

    Component.onCompleted: {
        clientsProc.running = true;
        root.refresh();
    }

    onMonitorChanged: root.showActiveMode()

    Connections {
        target: root.monitor
        function onActiveWorkspaceChanged() {
            root.showActiveMode();
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            var name = event ? String(event.name) : "";

            // Window-list refresh, debounced so title churn doesn't spawn a
            // hyprctl process per keystroke.
            if (name === "openwindow" || name === "windowtitlev2" || name === "activewindow" || name === "closewindow" || name === "movewindow" || name === "moveworkspacev2")
                clientRefreshTimer.restart();

            // Quickshell credits every workspace switch to the focused
            // monitor, as the event doesn't say which one switched, and misses
            // the workspace a monitor falls back to when its own is moved
            // away. Moving workspaces between monitors switches the others, so
            // ask Hyprland for the truth. A workspace that changes number is
            // only learned by asking too. Every bar shares what Hyprland
            // answers, so one asks after a plain switch.
            var switched = name === "workspacev2" && root.monitor !== null && root.monitor.focused;
            if (switched || name === "moveworkspacev2" || name === "changeworkspaceid") {
                Hyprland.refreshMonitors();
                Hyprland.refreshWorkspaces();
            }

            // A config reload can switch modes, blocks, or both.
            if (name === "configreloaded")
                root.refresh();
        }
    }

    Process {
        id: modeProc
        stdout: StdioCollector {
            onStreamFinished: {
                var mode = text.trim();
                // A read that started before a refresh may predate the change.
                if (!mode || root.modeProcGeneration !== root.modeGeneration)
                    return;
                root.modeCache[root.modeProcWorkspace] = mode;
                if (root.modeProcWorkspace === root.activeWorkspaceId())
                    root.activeMode = mode;
            }
        }
        onExited: {
            if (!root.modeStale)
                return;
            root.modeStale = false;
            // Deferred: the process still reports running while it signals exit.
            Qt.callLater(root.showActiveMode);
        }
    }

    // Super + L and the default layout change the mode without a focus change,
    // so they ask every bar to read it again. The target is omarchy's, on
    // purpose: the scripts announce `omarchy-shell -q omarchy.workspaces
    // refresh`, and only one widget at a time is in the bar to answer it.
    ShellIpc {
        target: "omarchy.workspaces"

        function refresh(): void {
            root.broadcast("refresh");
        }
    }

    // Size per orientation: the host slot forces width to barSize in vertical
    // mode and takes height from implicitHeight (Bar.qml ModuleSlot), so the
    // widget must own its full extent — no anchor-margin hacks.
    implicitWidth: root.vertical ? root.barSize : pill.implicitWidth + trailingGap
    implicitHeight: root.vertical ? pill.implicitHeight : root.barSize

    Rectangle {
        id: pill
        anchors.fill: parent
        color: Util.alpha(root.fgColor, 0.0)
        radius: Style.spaceReal(10)
        implicitWidth: grid.implicitWidth + Style.spaceReal(8)
        implicitHeight: grid.implicitHeight + Style.spaceReal(8)

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: function (wheel) {
                root.scrollWorkspaces(wheel.angleDelta.y);
            }
        }

        // Anchored left+right so the grid has an explicit width: in vertical
        // mode the fillWidth buttons then stretch to the full bar width,
        // while horizontal cells keep their content width.
        GridLayout {
            id: grid
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Style.spaceReal(4)
            anchors.rightMargin: Style.spaceReal(4)
            anchors.verticalCenter: parent.verticalCenter
            columns: root.vertical ? 1 : Math.max(1, root.workspaceIdList.length)
            columnSpacing: root.vertical ? 0 : Style.spaceReal(4)
            rowSpacing: root.vertical ? Style.spaceReal(4) : 0

            Repeater {
                model: root.workspaceIdList

                Rectangle {
                    id: btn
                    required property int modelData
                    required property int index

                    readonly property var workspace: root.workspaceById(btn.modelData)
                    readonly property bool occupied: root.isWorkspaceOccupied(btn.modelData)
                    // This bar's monitor shows this workspace, not the globally
                    // focused one: each monitor's bar lights its own slot.
                    readonly property bool shown: root.monitor !== null && root.monitor.activeWorkspace !== null && root.monitor.activeWorkspace.id === btn.modelData
                    readonly property int slot: root.slotOf(btn.modelData)
                    // A guest joins after the monitor's own; a gap sets it apart.
                    readonly property bool firstGuest: root.blockOf(btn.modelData) !== root.block && btn.index > 0 && root.blockOf(root.workspaceIdList[btn.index - 1]) === root.block
                    readonly property bool urgent: btn.workspace !== null && btn.workspace.urgent === true
                    // Reactive icon list — refires on client/rule changes.
                    readonly property var iconList: root.workspaceIconList(btn.modelData)
                    // Authoritative count (hyprctl clients) — drives sizing.
                    readonly property int windowCount: root.workspaceWindowCount(btn.modelData)
                    // Icons shrink as windows pile up — vertical bars only.
                    // (Slots show icons; the mode glyph rides with the label.)
                    readonly property real iconScaleFactor: root.vertical ? root.iconScale(btn.windowCount) : 1.0
                    // Rendered icon size — single source of truth shared by
                    // measurement (fittedIconCount) and rendering so both
                    // always agree.
                    readonly property int iconPx: Math.floor(Style.font.icon * btn.iconScaleFactor)
                    // Usable width for icon fitting (vertical); 0 disables
                    // fitting on horizontal bars.
                    readonly property real contentAvail: root.vertical ? btn.width : 0
                    // The subset of icons drawn in this pill (vertical).
                    // Computed by refit() instead of a binding because the
                    // measuring function writes to shared TextMetrics state.
                    property var fittedIcons: []
                    readonly property int fittedCount: btn.fittedIcons.length

                    function refit() {
                        btn.fittedIcons = btn.iconList.slice(0, root.fittedIconCount(btn.iconList, btn.contentAvail, Style.font.icon));
                    }
                    onIconListChanged: btn.refit()
                    onContentAvailChanged: btn.refit()
                    Component.onCompleted: btn.refit()
                    property bool hovered: false

                    // A gap sets visiting workspaces apart from the monitor's own.
                    Layout.leftMargin: btn.firstGuest && !root.vertical ? Style.space(6) : 0
                    Layout.topMargin: btn.firstGuest && root.vertical ? Style.space(6) : 0

                    radius: Style.spaceReal(8)
                    color: btn.urgent ? root.urgentColor : (btn.shown ? Util.alpha(root.fgColor, 0.2) : (btn.hovered ? Util.alpha(root.fgColor, 0.15) : "transparent"))
                    opacity: (btn.occupied || btn.shown) ? 1 : 0.5
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillHeight: true
                    Layout.fillWidth: root.vertical
                    implicitWidth: content.implicitWidth + Style.spaceReal(16)
                    implicitHeight: root.vertical ? content.implicitHeight + Style.spaceReal(10) : root.barSize - Style.spaceReal(8)

                    Row {
                        id: content
                        anchors.centerIn: parent
                        clip: true
                        spacing: Style.spaceReal(3)

                        Text {
                            // The focused slot shows its layout: a square
                            // tiles, a circle scrolls, a triangle floats;
                            // clicking it cycles (as Super + L does). Others
                            // keep the plain slot number — shown 1-10, with
                            // slot ten blank except for its icons.
                            text: {
                                if (btn.shown)
                                    return root.modeGlyph(root.activeMode);
                                if (btn.slot === root.slots)
                                    return "";
                                if (!root.vertical)
                                    return String(btn.slot);
                                if (!btn.occupied)
                                    return String(btn.slot);
                                return "";
                            }
                            color: (btn.urgent) ? root.bgColor : root.fgColor
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: Math.floor((root.vertical ? Style.font.icon : Style.font.body) * btn.iconScaleFactor)
                        }

                        // Horizontal: single joined text, grows wide as
                        // windows open — never shrunk or capped.
                        Text {
                            visible: !root.vertical
                            text: root.workspaceIconsFor(btn.modelData)
                            color: (btn.urgent) ? root.bgColor : root.fgColor
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: Style.font.body
                        }

                        // Vertical: per-icon progressive sizing, fitted to
                        // the real pill width; overflow shown as "…".
                        Row {
                            id: iconRow
                            visible: root.vertical
                            spacing: root.spacingFor(btn.iconPx)

                            Repeater {
                                model: btn.fittedIcons

                                Text {
                                    required property var modelData

                                    text: modelData
                                    color: (btn.urgent) ? root.bgColor : root.fgColor
                                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                    font.pixelSize: btn.iconPx
                                }
                            }

                            Text {
                                // Never a "…" for a single window, even if
                                // fitting is mid-update.
                                visible: btn.windowCount > 1 && btn.fittedCount < btn.windowCount
                                text: "…"
                                color: (btn.urgent) ? root.bgColor : root.fgColor
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: btn.iconPx
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: btn.hovered = true
                        onExited: btn.hovered = false

                        onClicked: function (mouse) {
                            // Clicking the focused workspace cycles its
                            // layout; clicking anything else focuses it.
                            if (btn.shown)
                                root.cycleLayout();
                            else
                                root.focusWorkspace(btn.modelData);
                        }
                    }
                }
            }
        }
    }
}
