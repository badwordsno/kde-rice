// SPDX-License-Identifier: MIT

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.workspace.dbus as DBus
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root

    readonly property real horizontalPadding: Kirigami.Units.smallSpacing
    readonly property real buttonSpacing: 1
    readonly property real buttonWidth: Math.round(Kirigami.Units.gridUnit * 1.25)
    readonly property real preferredSwitcherWidth: horizontalPadding * 2
        + buttonWidth * desktopInfo.numberOfDesktops
        + buttonSpacing * Math.max(0, desktopInfo.numberOfDesktops - 1)
    property int wheelDelta: 0

    preferredRepresentation: fullRepresentation

    Layout.minimumWidth: preferredSwitcherWidth
    Layout.preferredWidth: preferredSwitcherWidth
    Layout.maximumWidth: preferredSwitcherWidth
    Layout.fillHeight: true

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.status: desktopInfo.numberOfDesktops > 1
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
        const target = Math.max(0, Math.min(count - 1,
            currentDesktopIndex() + direction));
        switchToDesktop(target);
    }

    TaskManager.VirtualDesktopInfo {
        id: desktopInfo
    }

    fullRepresentation: Item {
        implicitWidth: root.preferredSwitcherWidth
        implicitHeight: Kirigami.Units.gridUnit

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                root.wheelDelta += wheel.angleDelta.y || wheel.angleDelta.x;

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

                    Layout.minimumWidth: root.buttonWidth
                    Layout.preferredWidth: root.buttonWidth
                    Layout.maximumWidth: root.buttonWidth
                    Layout.fillHeight: true

                    mainText: root.desktopName(index)
                    subText: current ? qsTr("Current desktop") : qsTr("Switch desktop")

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: Kirigami.Units.smallSpacing / 2
                        anchors.bottomMargin: Kirigami.Units.smallSpacing / 2
                        anchors.leftMargin: 1
                        anchors.rightMargin: 1

                        radius: 2
                        color: desktopButton.current
                            ? Kirigami.Theme.highlightColor
                            : Kirigami.Theme.textColor
                        opacity: desktopButton.current ? 0.72
                            : desktopMouseArea.containsMouse ? 0.12 : 0

                        Behavior on opacity {
                            NumberAnimation { duration: Kirigami.Units.shortDuration }
                        }
                    }

                    PlasmaComponents.Label {
                        anchors.fill: parent

                        text: String(desktopButton.index + 1)
                        textFormat: Text.PlainText
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.family: "Noto Sans"
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        color: desktopButton.current
                            ? Kirigami.Theme.highlightedTextColor
                            : Kirigami.Theme.textColor
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
