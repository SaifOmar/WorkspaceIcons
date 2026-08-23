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
            return;   // keep last good snapshot rather than blanking the bar
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
            map[id].push({ cls: String(c.class || ""), title: String(c.title || "") });
        }
        root.wsWindows = map;
    }

    Timer {
        id: clientRefreshTimer
        interval: 120
        repeat: false
        onTriggered: clientsProc.running = true
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "openwindow" || event.name === "windowtitlev2" || event.name === "activewindow" || event.name === "closewindow" || event.name === "movewindow" || event.name === "moveworkspacev2")
                clientRefreshTimer.restart();
        }
    }

    Process {
        id: clientsProc
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.applyClients(text)
        }
    }

    Component.onCompleted: clientsProc.running = true

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
        try { p = decodeURIComponent(p); } catch (e) {}
        return p;
    }
    readonly property string overrideRulesPath: Quickshell.env("HOME") + "/.config/omarchy/workspaces-icons.json"

    // Minimal fallback so the widget still works if neither file parses.
    readonly property var fallbackRules: [
        { pattern: "firefox|zen|chrom|brave|chrome", icon: "󰈹" },
        { pattern: "kitty|foot|alacritty|ghostty|wezterm|konsole", icon: "󰆍" },
        { pattern: "code|codium|zed", icon: "󰨞" }
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
                    return r
                        && typeof r.pattern === "string"
                        && r.pattern.length > 0
                        && r.pattern.length <= root.maxRulePatternLength
                        && typeof r.icon === "string"
                        && r.icon.length > 0
                        && r.icon.length <= root.maxIconLength;
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
                out.push({ re: new RegExp(list[i].pattern, "i"), icon: list[i].icon });
            } catch (e) {} // skip invalid regexes rather than breaking the bar
        }
        root.compiledRules = out;
    }

    // -----------------------------------------------------------------------

    readonly property color fgColor: root.bar ? root.bar.barForeground : Color.foreground
    readonly property color urgentColor: Color.urgent
    readonly property color bgColor: root.bar ? root.bar.background : Color.background

    readonly property int focusedId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
    readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(15)

    function workspaceById(id) {
        var values = Hyprland.workspaces.values;
        for (var i = 0; i < values.length; i++) {
            if (values[i].id === id)
                return values[i];
        }
        return null;
    }

    // Computed once per workspaces change instead of twice per layout pass
    // (it used to be called separately for grid columns AND Repeater model).
    readonly property var workspaceIdList: {
        var ids = [];
        for (var n = 1; n <= root.baseWorkspaceCount; n++)
            ids.push(n);
        var values = Hyprland.workspaces.values;
        for (var i = 0; i < values.length; i++) {
            var id = values[i].id;
            if (id > 0 && id <= root.maxWorkspaceId && ids.indexOf(id) === -1)
                ids.push(id);
        }
        ids.sort(function (left, right) { return left - right; });
        return ids;
    }

    function focusWorkspace(id) {
        if (!root.bar)
            return;
        id = Math.floor(Number(id));
        if (!isFinite(id) || id < 1)
            return;
        // The id must be a quoted string: this Hyprland ignores
        // hl.dsp.focus({ workspace = <number> }) silently.
        Hyprland.dispatch(`hl.dsp.focus({ workspace = "${id}" })`);
    }

    function switchWorkspace(delta) {
        if (!root.bar)
            return;
        delta = Math.floor(Number(delta));
        if (!isFinite(delta) || delta === 0)
            return;
        var target = delta > 0 ? "e+" + delta : "e" + delta;

        Hyprland.dispatch('hl.dsp.focus({ workspace = "' + target + '" })');
    }

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
                break;   // always show ≥1
            acc += step;
            count++;
        }
        return Math.max(count, 1);   // never a bare "…"
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
                if (wheel.angleDelta.y > 0)
                    root.switchWorkspace(1);
                else
                    root.switchWorkspace(-1);
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

                    readonly property var workspace: root.workspaceById(modelData)
                    readonly property bool occupied: root.isWorkspaceOccupied(btn.modelData)
                    readonly property bool focused: root.focusedId === modelData
                    readonly property bool urgent: btn.workspace !== null && btn.workspace.urgent === true
                    // Reactive icon list — refires on client/rule changes.
                    readonly property var iconList: root.workspaceIconList(btn.modelData)
                    // Authoritative count (hyprctl clients) — drives sizing.
                    readonly property int windowCount: root.workspaceWindowCount(btn.modelData)
                    // Icons shrink as windows pile up — vertical bars only.
                    // (The label no longer counts as an item: occupied pills
                    // are icons-only on vertical bars.)
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
                        btn.fittedIcons = btn.iconList.slice(
                            0, root.fittedIconCount(btn.iconList, btn.contentAvail, Style.font.icon));
                    }
                    onIconListChanged: btn.refit()
                    onContentAvailChanged: btn.refit()
                    Component.onCompleted: btn.refit()
                    property bool hovered: false

                    radius: Style.spaceReal(8)
                    color: btn.urgent ? root.urgentColor : (btn.focused ? Util.alpha(root.fgColor, 0.2) :
                        (btn.hovered ? Util.alpha(root.fgColor, 0.15) : "transparent"))
                    opacity: (btn.occupied || btn.focused) ? 1 : 0.5
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
                            // Horizontal: unchanged — focused glyph or the
                            // plain number. Vertical: numbers only for empty
                            // workspaces (including the focused one — a bare
                            // highlight pill would be invisible); occupied
                            // ones are icons-only.
                            text: {
                                if (!root.vertical)
                                    return btn.focused ? "\uDB85\uDCFB" : (btn.modelData === 10 ? "" : String(btn.modelData));
                                if (!btn.occupied)
                                    return btn.modelData === 10 ? "" : String(btn.modelData);
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

                        onClicked: root.focusWorkspace(btn.modelData)
                    }
                }
            }
        }
    }
}
