// SPDX-License-Identifier: MIT

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.workspace.dbus as DBus
import org.kde.taskmanager as TaskManager

import "chimera" as Chimera

PlasmoidItem {
    id: root

    readonly property real horizontalPadding: tokens.space2
    readonly property real buttonSpacing: tokens.flatSurface ? 0 : tokens.cellGap
    readonly property real buttonWidth: Math.round(Kirigami.Units.gridUnit * 1.25)
    readonly property real configuredButtonWidth: Number(
        Plasmoid.configuration.labelMode) === 1
        ? Math.round(Kirigami.Units.gridUnit * 6)
        : Number(Plasmoid.configuration.density) === 1
            ? Math.round(Kirigami.Units.gridUnit * 1.5) : buttonWidth
    readonly property real preferredSwitcherWidth: horizontalPadding * 2
        + configuredButtonWidth * desktopInfo.numberOfDesktops
        + buttonSpacing * Math.max(0, desktopInfo.numberOfDesktops - 1)
    readonly property bool hiddenByPolicy: Boolean(Plasmoid.configuration.hideWhenSingle)
        && desktopInfo.numberOfDesktops <= 1
    property int wheelDelta: 0

    preferredRepresentation: fullRepresentation

    Layout.minimumWidth: hiddenByPolicy ? 0 : preferredSwitcherWidth
    Layout.preferredWidth: hiddenByPolicy ? 0 : preferredSwitcherWidth
    Layout.maximumWidth: hiddenByPolicy ? 0 : preferredSwitcherWidth
    Layout.minimumHeight: tokens.controlHeight
    Layout.preferredHeight: tokens.controlHeight
    Layout.maximumHeight: tokens.controlHeight
    Layout.fillHeight: false

    visible: !hiddenByPolicy
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.status: !hiddenByPolicy && desktopInfo.numberOfDesktops > 1
        ? PlasmaCore.Types.ActiveStatus
        : PlasmaCore.Types.PassiveStatus

    toolTipMainText: qsTr("Virtual desktops")
    toolTipSubText: qsTr("Desktop %1 of %2")
        .arg(currentDesktopIndex() + 1)
        .arg(desktopInfo.numberOfDesktops)

    function currentDesktopIndex() {
        const currentId = String(desktopInfo.currentDesktop);
        for (let index = 0; index < desktopInfo.desktopIds.length; ++index) {
            if (String(desktopInfo.desktopIds[index]) === currentId) {
                return index;
            }
        }
        return 0;
    }

    function desktopName(index) {
        const candidate = desktopInfo.desktopNames[index];
        return candidate === undefined || String(candidate) === ""
            ? qsTr("Desktop %1").arg(index + 1)
            : String(candidate);
    }

    function desktopLabel(index) {
        switch (Math.max(0, Math.min(2,
                Number(Plasmoid.configuration.labelMode)))) {
        case 1:
            return desktopName(index);
        case 2:
            return "•";
        default:
            return String(index + 1);
        }
    }

    function switchDesktopSteps(member, remaining) {
        if (remaining <= 0) {
            return;
        }

        const pendingReply = DBus.SessionBus.asyncCall({
            "service": "org.kde.KWin",
            "path": "/KWin",
            "iface": "org.kde.KWin",
            "member": member
        });
        pendingReply.finished.connect(function () {
            if (pendingReply.isError) {
                console.warn("Minimalist Workspaces could not switch desktop:",
                    pendingReply.error.message);
            } else if (remaining > 1) {
                root.switchDesktopSteps(member, remaining - 1);
            }
            pendingReply.destroy();
        });
    }

    function switchToDesktop(index) {
        if (index < 0 || index >= desktopInfo.numberOfDesktops) {
            return;
        }
        const difference = index - currentDesktopIndex();
        if (difference === 0) {
            return;
        }
        switchDesktopSteps(difference > 0 ? "nextDesktop" : "previousDesktop",
            Math.abs(difference));
    }

    function stepDesktop(direction) {
        const count = desktopInfo.numberOfDesktops;
        if (count < 2) {
            return;
        }
        let target = currentDesktopIndex() + direction;
        if (Plasmoid.configuration.wrapWheel) {
            target = (target + count) % count;
        } else {
            target = Math.max(0, Math.min(count - 1, target));
        }
        switchToDesktop(target);
    }

    Chimera.ChimeraTokens {
        id: tokens

        density: Math.max(0, Math.min(1, Number(Plasmoid.configuration.density)))
        surfaceStyle: Math.max(0, Math.min(2,
            Number(Plasmoid.configuration.surfaceStyle)))
        bevelDepth: Math.max(0, Math.min(2,
            Number(Plasmoid.configuration.bevelDepth)))
        motionEnabled: Boolean(Plasmoid.configuration.motionEnabled)
    }

    TaskManager.VirtualDesktopInfo {
        id: desktopInfo
    }

    fullRepresentation: Item {
        implicitWidth: root.preferredSwitcherWidth
        implicitHeight: tokens.controlHeight

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                const rawDelta = wheel.angleDelta.y || wheel.angleDelta.x;
                root.wheelDelta += Plasmoid.configuration.invertWheel
                    ? -rawDelta : rawDelta;

                while (root.wheelDelta >= 120) {
                    root.wheelDelta -= 120;
                    root.stepDesktop(-1);
                }
                while (root.wheelDelta <= -120) {
                    root.wheelDelta += 120;
                    root.stepDesktop(1);
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.horizontalPadding
            anchors.rightMargin: root.horizontalPadding
            spacing: root.buttonSpacing

            Repeater {
                model: desktopInfo.numberOfDesktops

                delegate: PlasmaCore.ToolTipArea {
                    id: desktopButton

                    required property int index
                    readonly property bool current: index === root.currentDesktopIndex()

                    Layout.minimumWidth: root.configuredButtonWidth
                    Layout.preferredWidth: root.configuredButtonWidth
                    Layout.maximumWidth: root.configuredButtonWidth
                    Layout.fillHeight: true

                    mainText: root.desktopName(index)
                    subText: current ? qsTr("Current desktop") : qsTr("Switch desktop")

                    Chimera.ChimeraFrame {
                        anchors.fill: parent

                        tokens: tokens
                        active: desktopButton.current
                        hovered: desktopMouseArea.containsMouse
                        pressed: desktopMouseArea.pressed
                        focused: desktopMouseArea.activeFocus
                        stateRailInset: Math.max(tokens.space2,
                            Math.floor((root.configuredButtonWidth
                                - tokens.space4) / 2))
                        fillColor: pressed ? tokens.surfaceSunken
                            : hovered ? tokens.surfaceHovered
                            : tokens.flatSurface ? "transparent"
                            : desktopButton.current
                            ? Qt.tint(tokens.surfaceRaised,
                                Qt.rgba(tokens.accent.r, tokens.accent.g,
                                    tokens.accent.b, 0.2))
                            : tokens.surfaceRaised

                        PlasmaComponents.Label {
                            anchors.fill: parent

                            text: root.desktopLabel(desktopButton.index)
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            maximumLineCount: 1
                            font.family: "Noto Sans"
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            // Selection is carried by the fill and rail;
                            // small labels retain the normal text contrast.
                            color: tokens.textColor
                        }
                    }

                    MouseArea {
                        id: desktopMouseArea

                        anchors.fill: parent
                        hoverEnabled: true
                        activeFocusOnTab: true
                        cursorShape: Qt.PointingHandCursor

                        Accessible.name: qsTr("Desktop %1").arg(desktopButton.index + 1)
                        Accessible.description: desktopButton.current
                            ? qsTr("Current desktop")
                            : qsTr("Switch to desktop %1").arg(desktopButton.index + 1)
                        Accessible.role: Accessible.Button

                        onClicked: root.switchToDesktop(desktopButton.index)
                        Keys.onPressed: event => {
                            switch (event.key) {
                            case Qt.Key_Space:
                            case Qt.Key_Enter:
                            case Qt.Key_Return:
                            case Qt.Key_Select:
                                root.switchToDesktop(desktopButton.index);
                                event.accepted = true;
                                break;
                            }
                        }
                    }
                }
            }
        }
    }
}
