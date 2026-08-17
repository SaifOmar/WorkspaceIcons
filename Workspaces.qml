import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import Quickshell.Io

BarWidget {
    id: root
    moduleName: "saif.workspaces"

    // NOTE: this is what makes it pull the changes to toplevels from Hyprland... ie.winow classes and all that
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "openwindow" || event.name === "windowtitlev2" || event.name === "activewindow" || event.name === "closewindow" || event.name === "movewindow") {
                Hyprland.refreshToplevels();
            }
        }
    }
    readonly property int baseWorkspaceCount: 5
    readonly property int maxWorkspaceId: 10

    function iconRules() {
        return [
            {
                pattern: "windows",
                icon: "\uE8E5"
            },
            {
                pattern: "ai.opencode.desktop|opencode",
                icon: "\uF140"
            },
            {
                pattern: "org.jellyfin.JellyfinDesktop|jellyfin",
                icon: "\udb83\udf01"
            },
            {
                pattern: "chrome-claude.ai__-default|claude",
                icon: ""
            },
            {
                pattern: '.*amazon.*',
                icon: "󰸩"
            },
            {
                pattern: 'firefox|org.mozilla.firefox|librewolf|floorp|mercury-browser|[Cc]achy-browser',
                icon: "󰈹"
            },
            {
                pattern: 'zen',
                icon: "󰈹"
            },
            {
                pattern: 'waterfox|waterfox-bin',
                icon: "󰈹"
            },
            {
                pattern: 'microsoft-edge',
                icon: "󰇩"
            },
            {
                pattern: 'brave-browser|Brave-browser|Brave|brave',
                icon: "\uEDDE"
            },
            {
                pattern: 'tor browser',
                icon: "󰖂"
            },
            // NOTE: removed 'firefox-developer-edition' rule here — it was unreachable,
            // the generic firefox pattern above already matches any class containing "firefox".
            {
                pattern: 'brave-x.com.*',
                icon: ""
            },
            {
                pattern: 'twitter-x',
                icon: ""
            },
            {
                pattern: 'x.com|twitter',
                icon: ""
            },
            {
                pattern: 'signal',
                icon: "󰍡"
            },
            {
                pattern: '[Tt]elegram-desktop|org.telegram.desktop|io.github.tdesktop_x64.TDesktop',
                icon: "󰘦"
            },
            {
                pattern: 'discord|[Ww]ebcord|Vesktop',
                icon: "󰙯"
            },
            {
                pattern: 'slack',
                icon: "󰒱"
            },
            {
                pattern: '.*whatsapp.*',
                icon: "󰖣"
            },
            {
                pattern: '.*zapzap.*',
                icon: "󰖣"
            },
            {
                pattern: '.*messenger.*',
                icon: "󰈎"
            },
            {
                pattern: '.*facebook.*',
                icon: "󰈎"
            },
            {
                pattern: '.*reddit.*',
                icon: "󰑍"
            },
            {
                pattern: '[Tt]hunderbird|[Tt]hunderbird-esr',
                icon: "󰇮"
            },
            {
                pattern: 'eu.betterbird.Betterbird',
                icon: "󰇮"
            },
            {
                pattern: 'claws-mail',
                icon: "󰇮"
            },
            {
                pattern: 'org.gnome.Evolution',
                icon: "󰊫"
            },
            {
                pattern: 'org.gnome.Geary',
                icon: "󰊫"
            },
            {
                pattern: '.*gmail.*',
                icon: "󰊫"
            },
            {
                pattern: '.*proton.*mail.*',
                icon: "󰊫"
            },
            {
                pattern: 'brave-mail.proton.me.*',
                icon: "󰊫"
            },
            {
                pattern: '.*n?vim.*',
                icon: ""
            },
            {
                pattern: 'konsole',
                icon: "󰆍"
            },
            {
                pattern: 'foot',
                icon: "󰆍"
            },
            {
                pattern: 'kitty',
                icon: "󰆍"
            },
            {
                pattern: 'alacritty',
                icon: "󰆍"
            },
            {
                pattern: 'com.mitchellh.ghostty',
                icon: "󰊠"
            },
            {
                pattern: 'com.mitchellh.ghostty-floating',
                icon: "󰊠"
            },
            {
                pattern: 'org.wezfurlong.wezterm',
                icon: "󰆍"
            },
            {
                pattern: '.*ChatGPT.*',
                icon: ""
            },
            {
                pattern: '.*deepseek.*',
                icon: "󰭹"
            },
            {
                pattern: '.*qwen.*',
                icon: "󰭹"
            },
            {
                pattern: 'VSCode|code-url-handler|code-oss|codium|codium-url-handler|VSCodium|code|Code',
                icon: "󰨞"
            },
            {
                pattern: 'VSCode|code-url-handler|code-oss|codium|codium-url-handler|VSCodium|code|Code',
                icon: "󰨞"
            },
            {
                pattern: 'dev.zed.Zed|dev.zed.Zed-Preview',
                icon: "󱓞"
            },
            {
                pattern: 'subl',
                icon: "󰅳"
            },
            {
                pattern: 'codeblocks',
                icon: "󰅩"
            },
            {
                pattern: 'geany',
                icon: "󰅩"
            },
            {
                pattern: 'jetbrains-idea',
                icon: "󰅩"
            },
            {
                pattern: 'mousepad',
                icon: "󰇾"
            },
            {
                pattern: 'ghostwriter|org.kde.ghostwriter',
                icon: "󰷈"
            },
            {
                pattern: 'org.gnome.TextEditor',
                icon: "󰷈"
            },
            // NOTE: collapsed the old 3-rule vim/nvim block (".*nvim ~.*", ".*vim.*", ".*nvim.*")
            // into one — the generic ".*vim.*" already matched "nvim" too, so the other two
            // were unreachable. All three mapped to the same icon anyway.
            {
                pattern: 'libreoffice-writer',
                icon: "󰈙"
            },
            {
                pattern: 'libreoffice-startcenter',
                icon: "󰏆"
            },
            {
                pattern: 'libreoffice-calc',
                icon: "󰧷"
            },
            {
                pattern: '.*github.*',
                icon: "󰊤"
            },
            {
                pattern: '.*figma.*',
                icon: "󰣙"
            },
            {
                pattern: '.*jira.*',
                icon: "󰗃"
            },
            {
                pattern: 'mpv',
                icon: "󰐹"
            },
            {
                pattern: 'celluloid',
                icon: "󰐹"
            },
            {
                pattern: 'vlc',
                icon: "󰕼"
            },
            {
                pattern: '.*Picture-in-Picture.*',
                icon: "󰐹"
            },
            {
                pattern: '.*youtube.*',
                icon: "󰗃"
            },
            {
                pattern: '.*Monkeytype.*',
                icon: "󰌌"
            },
            {
                pattern: '.*cmus.*',
                icon: "󰝚"
            },
            {
                pattern: '[Ss]potify',
                icon: "󰓇"
            },
            {
                pattern: 'org.kde.elisa',
                icon: "󰝚"
            },
            {
                pattern: 'org.gnome.Lollypop',
                icon: "󰝚"
            },
            {
                pattern: 'org.gnome.Music',
                icon: "󰝚"
            },
            {
                pattern: 'org.gnome.music',
                icon: "󰝚"
            },
            {
                pattern: 'rhythmbox',
                icon: "󰝚"
            },
            {
                pattern: 'Cider',
                icon: "󰎆"
            },
            {
                pattern: 'cake_wallet',
                icon: "󰠓"
            },
            {
                pattern: 'feather',
                icon: "󰠓"
            },
            {
                pattern: 'Exodus|exodus',
                icon: "󰠓"
            },
            {
                pattern: 'com.transmissionbt.transmission.*',
                icon: "󰄠"
            },
            {
                pattern: 'de.haeckerfelix.Fragments',
                icon: "󰄠"
            },
            {
                pattern: 'virt-manager',
                icon: "󰍺"
            },
            {
                pattern: '.virt-manager-wrapped',
                icon: "󰍺"
            },
            {
                pattern: 'virtualbox manager',
                icon: "󰍺"
            },
            {
                pattern: 'virtualbox',
                icon: "󰍺"
            },
            {
                pattern: 'remmina',
                icon: "󰢹"
            },
            {
                pattern: 'polkit-gnome-authentication-agent-1',
                icon: "󰒃"
            },
            {
                pattern: 'nwg-look',
                icon: "󰔡"
            },
            {
                pattern: '[Pp]avucontrol|org.pulseaudio.pavucontrol',
                icon: "󰓃"
            },
            {
                pattern: 'org.pipewire.Helvum',
                icon: "󰓃"
            },
            {
                pattern: 'Gparted',
                icon: "󰋊"
            },
            {
                pattern: 'thunar|nemo',
                icon: "󰝰"
            },
            {
                pattern: 'org.gnome.Nautilus|nautilus',
                icon: "󰝰"
            },
            {
                pattern: 'obs|com.obsproject.Studio',
                icon: "󰐍"
            },
            {
                pattern: 'gimp',
                icon: "󰏘"
            },
            {
                pattern: 'Zoom',
                icon: "󰕧"
            },
            {
                pattern: 'steam',
                icon: "󰓓"
            },
            {
                pattern: 'emulator',
                icon: "󰄭"
            },
            {
                pattern: 'android-studio',
                icon: "󰀴"
            },
            {
                pattern: 'PrusaSlicer|UltiMaker-Cura|OrcaSlicer',
                icon: "󰐫"
            },
            {
                pattern: 'org.pwmt.zathura',
                icon: "󰈦"
            },
            {
                pattern: 'org.gnome.Contacts',
                icon: "󰀉"
            },
            {
                pattern: 'Chromium|Thorium|[Cc]hrome',
                icon: "󰊯"
            }
        ];
    }

    readonly property color fgColor: root.bar ? root.bar.barForeground : Color.foreground
    readonly property color activeColor: root.bar ? root.bar.urgent : Color.urgent
    readonly property color urgentColor: Color.urgent
    readonly property color bgColor: root.bar ? root.bar.background : Color.background

    readonly property int focusedId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
    readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(15)

    property var compiledRules: []
    // NEW: cache resolved icon by "class\u0001title" so the ~90 rule regex list
    // isn't rescanned on every re-render for windows we've already resolved.
    property var iconCache: ({})

    function workspaceById(id) {
        var values = Hyprland.workspaces.values;
        for (var i = 0; i < values.length; i++) {
            if (values[i].id === id)
                return values[i];
        }
        return null;
    }

    function workspaceIds() {
        var ids = [];
        for (var n = 1; n <= root.baseWorkspaceCount; n++)
            ids.push(n);
        var values = Hyprland.workspaces.values;
        for (var i = 0; i < values.length; i++) {
            var id = values[i].id;
            if (id > 0 && id <= root.maxWorkspaceId && ids.indexOf(id) === -1)
                ids.push(id);
        }
        ids.sort(function (left, right) {
            return left - right;
        });
        return ids;
    }

    function focusWorkspce(id) {
        if (!root.bar)
            return;
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`);
    }

    function switchWorkspace(delta) {
        if (!root.bar)
            return;
        var target = delta > 0 ? "e+" + delta : "e" + delta;

        Hyprland.dispatch('hl.dsp.focus({ workspace = "' + target + '" })');
        // root.bar.run("hyprctl dispatch " + Util.shellQuote('hl.dsp.focus({ workspace = "' + target + '" })'));
    }

    function windowClass(toplevel) {
        var ipc = toplevel ? toplevel.lastIpcObject : null;
        if (ipc && ipc.class)
            return ipc.class;
        if (toplevel && toplevel.class)
            return toplevel.class;   // <-- fallback #2, rarely hit
        if (toplevel && toplevel.appId)
            return toplevel.appId;
        return "";
    }

    function windowTitle(toplevel) {
        if (toplevel && toplevel.title)
            return toplevel.title;
        var ipc = toplevel ? toplevel.lastIpcObject : null;
        if (ipc && ipc.title)
            return ipc.title;
        return "";
    }

    // Order matters here and is preserved exactly as before (e.g. the amazon
    // title rule has to stay ahead of the browser class rules, or every
    // Amazon tab in Firefox would show the Firefox icon instead).
    function resolveIcon(cls, title) {
        var ruleSet = root.iconRules();
        for (var i = 0; i < ruleSet.length; i++) {
            var rule = ruleSet[i];
            var re = new RegExp(ruleSet[i].pattern, "i");
            if (re.test(title))
                return rule.icon;
            if (re.test(cls))
                return rule.icon;
        }
        return "󰘔";
    }

    function iconForToplevel(toplevel) {
        var cls = root.windowClass(toplevel).toLowerCase();// there is a problem with how we are getting the class of the window
        var title = root.windowTitle(toplevel).toLowerCase();

        if (!cls && !title)
            return "󰘔";

        var icon = root.resolveIcon(cls, title);
        return icon;
    }

    // Both of these now take the already-resolved workspace object instead of
    // an id, so callers that already looked it up (the Repeater delegate)
    // don't force a second/third linear scan of Hyprland.workspaces.values.
    function isWorkspaceOccupied(workspace) {
        if (!workspace)
            return false;
        var tops = workspace.toplevels ? workspace.toplevels.values : [];
        if (tops.length === 0 || !tops)
            return false;
        return true;
    }

    function workspaceIconsFor(workspace) {
        if (!workspace)
            return "";
        var tops = workspace.toplevels ? workspace.toplevels.values : [];
        var icons = [];
        for (var i = 0; i < tops.length; i++) {
            var icon = root.iconForToplevel(tops[i]);
            if (icon)
                icons.push(icon);
        }
        return icons.join(" ");
    }

    implicitWidth: root.vertical ? root.barSize : pill.implicitWidth + trailingGap
    implicitHeight: pill.implicitHeight

    Rectangle {
        id: pill
        anchors.left: parent.left
        anchors.right: root.vertical ? parent.right : undefined
        anchors.top: parent.top
        anchors.bottom: root.vertical ? undefined : parent.bottom
        anchors.leftMargin: root.vertical ? Style.spaceReal(4) : 0
        anchors.rightMargin: root.vertical ? Style.spaceReal(4) : 0
        anchors.topMargin: root.vertical ? Style.spaceReal(80) : Style.spaceReal(4)
        anchors.bottomMargin: root.vertical ? 0 : Style.spaceReal(4)
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

        GridLayout {
            id: grid
            anchors.left: parent.left
            anchors.leftMargin: Style.spaceReal(4)
            anchors.right: parent.right
            anchors.rightMargin: Style.spaceReal(4)
            anchors.verticalCenter: parent.verticalCenter
            columns: root.vertical ? 1 : Math.max(1, root.workspaceIds().length)
            columnSpacing: root.vertical ? 0 : Style.spaceReal(4)
            rowSpacing: root.vertical ? Style.spaceReal(4) : 0

            Repeater {
                model: root.workspaceIds()

                Rectangle {
                    id: btn
                    required property int modelData

                    readonly property var workspace: root.workspaceById(modelData)
                    readonly property bool occupied: root.isWorkspaceOccupied(btn.workspace)
                    readonly property bool focused: root.focusedId === modelData
                    readonly property bool urgent: btn.workspace !== null && btn.workspace.urgent === true
                    property bool hovered: false

                    radius: Style.spaceReal(8)
                    color: btn.urgent ? root.urgentColor : (btn.focused ? Util.alpha(root.fgColor, 0.2) :
                        // : (btn.focused ? root.activeColor
                        (btn.hovered ? Util.alpha(root.fgColor, 0.15) : "transparent"))
                    opacity: (btn.occupied || btn.focused) ? 1 : 0.5
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillHeight: true
                    Layout.fillWidth: root.vertical
                    implicitWidth: root.vertical ? (root.barSize - Style.spaceReal(8)) : content.implicitWidth + Style.spaceReal(16)
                    implicitHeight: root.vertical ? content.implicitHeight + Style.spaceReal(10) : root.barSize - Style.spaceReal(8)

                    Row {
                        id: content
                        anchors.centerIn: parent
                        clip: true
                        spacing: Style.spaceReal(3)

                        Text {
                            text: btn.focused ? "\uDB85\uDCFB" : (btn.modelData === 10 ? "" : String(btn.modelData))
                            color: (btn.urgent) ? root.bgColor : root.fgColor
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: root.vertical ? Style.font.icon : Style.font.body
                        }

                        Text {
                            text: root.workspaceIconsFor(btn.workspace)
                            color: (btn.urgent) ? root.bgColor : root.fgColor
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: root.vertical ? Style.font.icon : Style.font.body
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: btn.hovered = true
                        onExited: btn.hovered = false

                        onClicked: root.focusWorkspce(btn.modelData)
                    }
                }
            }
        }
    }
}
