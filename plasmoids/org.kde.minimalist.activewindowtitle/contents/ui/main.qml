// SPDX-License-Identifier: MIT

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager

import "chimera" as Chimera

PlasmoidItem {
    id: root

    readonly property int preferredTitleWidth: Kirigami.Units.gridUnit * 18
    readonly property int configuredMinimumUnits: boundedNumber(
        Plasmoid.configuration.minimumWidthUnits, 8, 4, 40)
    readonly property int configuredMaximumUnits: Math.max(
        configuredMinimumUnits, boundedNumber(
            Plasmoid.configuration.maximumWidthUnits, 20, 4, 80))
    readonly property int configuredPreferredUnits: Math.max(
        configuredMinimumUnits, Math.min(configuredMaximumUnits,
            boundedNumber(Plasmoid.configuration.preferredWidthUnits,
                18, 4, 60)))
    readonly property int widthMode: boundedNumber(
        Plasmoid.configuration.widthMode, 1, 0, 2)
    readonly property int boundedMinimumWidth: Kirigami.Units.gridUnit
        * configuredMinimumUnits
    readonly property int boundedPreferredWidth: Kirigami.Units.gridUnit
        * configuredPreferredUnits
    readonly property int boundedMaximumWidth: Kirigami.Units.gridUnit
        * configuredMaximumUnits
    readonly property int contentTitleWidth: Math.ceil(titleMetrics.advanceWidth)
        + (Plasmoid.configuration.showIcon ? Kirigami.Units.iconSizes.small
            + tokens.space2 : 0)
        + tokens.contentInset * 2
    readonly property int effectiveMinimumWidth: widthMode === 0
        ? Math.min(contentTitleWidth, boundedMaximumWidth)
        : widthMode === 2 ? boundedPreferredWidth : boundedMinimumWidth
    readonly property int effectivePreferredWidth: widthMode === 0
        ? Math.max(boundedMinimumWidth,
            Math.min(contentTitleWidth, boundedMaximumWidth))
        : boundedPreferredWidth
    readonly property int effectiveMaximumWidth: widthMode === 2
        ? boundedPreferredWidth : boundedMaximumWidth
    readonly property bool titleVisible: activeTitle !== ""
        && (!Plasmoid.configuration.maximizedOnly || activeMaximized)
    readonly property string renderedTitle: titleVisible
        ? formatTitle(Plasmoid.configuration.titleTemplate, activeAppName, activeTitle)
        : ""
    property string activeTitle: ""
    property string activeAppName: ""
    property var activeIcon: ""
    property bool activeMaximized: false

    preferredRepresentation: fullRepresentation

    Layout.minimumWidth: effectiveMinimumWidth
    Layout.preferredWidth: widthMode === 1
        && configuredPreferredUnits === 18 ? preferredTitleWidth : effectivePreferredWidth
    Layout.maximumWidth: effectiveMaximumWidth
    Layout.minimumHeight: tokens.controlHeight
    Layout.preferredHeight: tokens.controlHeight
    Layout.maximumHeight: tokens.controlHeight
    Layout.fillHeight: false

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    toolTipMainText: renderedTitle
    toolTipSubText: renderedTitle === "" ? "" : qsTr("Active window")

    function boundedNumber(value, fallback, minimum, maximum) {
        const numericValue = Number(value);
        const finiteValue = Number.isFinite(numericValue)
            ? numericValue : fallback;
        return Math.max(minimum, Math.min(maximum, Math.round(finiteValue)));
    }

    function formatTitle(template, appName, title) {
        const candidate = String(template || "{title}");
        const unknown = candidate.split("{app}").join("")
            .split("{title}").join("");
        if (unknown.indexOf("{") !== -1 || unknown.indexOf("}") !== -1) {
            return String(title || "");
        }
        const formatted = candidate.split("{app}").join(String(appName || ""))
            .split("{title}").join(String(title || "")).trim();
        return formatted === "" ? String(title || "") : formatted;
    }

    function refreshActiveTitle() {
        const activeIndex = tasksModel.activeTask;
        if (!activeIndex.valid) {
            activeTitle = "";
            activeAppName = "";
            activeIcon = "";
            activeMaximized = false;
            return;
        }
        activeTitle = String(tasksModel.data(activeIndex, 0) || "");
        activeAppName = String(tasksModel.data(activeIndex,
            TaskManager.AbstractTasksModel.AppName) || "");
        activeIcon = tasksModel.data(activeIndex, Qt.DecorationRole) || "";
        activeMaximized = Boolean(tasksModel.data(activeIndex,
            TaskManager.AbstractTasksModel.IsMaximized));
    }

    function activeWindowIndexes() {
        const indexes = [];
        for (let row = 0; row < tasksModel.rowCount(); ++row) {
            const candidate = tasksModel.index(row, 0);
            if (candidate.valid && Boolean(tasksModel.data(candidate,
                    TaskManager.AbstractTasksModel.IsWindow))) {
                indexes.push(candidate);
            }
        }
        return indexes;
    }

    function cycleWindow(direction) {
        if (!Plasmoid.configuration.wheelSwitch || direction === 0) {
            return;
        }
        const indexes = activeWindowIndexes();
        if (indexes.length < 2) {
            return;
        }
        const activeIndex = tasksModel.activeTask;
        let activePosition = 0;
        for (let index = 0; index < indexes.length; ++index) {
            if (indexes[index].row === activeIndex.row) {
                activePosition = index;
                break;
            }
        }
        const target = (activePosition + direction + indexes.length) % indexes.length;
        tasksModel.requestActivate(indexes[target]);
    }

    function toggleActiveMaximized() {
        const activeIndex = tasksModel.activeTask;
        if (Plasmoid.configuration.doubleClickMaximize && activeIndex.valid
                && Boolean(tasksModel.data(activeIndex,
                    TaskManager.AbstractTasksModel.IsMaximizable))) {
            tasksModel.requestToggleMaximized(activeIndex);
        }
    }

    function closeActiveWindow() {
        const activeIndex = tasksModel.activeTask;
        if (Plasmoid.configuration.middleClickClose && activeIndex.valid
                && Boolean(tasksModel.data(activeIndex,
                    TaskManager.AbstractTasksModel.IsClosable))) {
            tasksModel.requestClose(activeIndex);
        }
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

    TextMetrics {
        id: titleMetrics

        font.family: "Noto Sans"
        text: root.renderedTitle
    }

    TaskManager.TasksModel {
        id: tasksModel

        groupMode: TaskManager.TasksModel.GroupDisabled
        sortMode: TaskManager.TasksModel.SortLastActivated

        onActiveTaskChanged: root.refreshActiveTitle()
        onDataChanged: root.refreshActiveTitle()
        onModelReset: root.refreshActiveTitle()
        onRowsInserted: root.refreshActiveTitle()
        onRowsRemoved: root.refreshActiveTitle()

        Component.onCompleted: root.refreshActiveTitle()
    }

    fullRepresentation: Item {
        implicitWidth: root.effectivePreferredWidth
        implicitHeight: tokens.controlHeight

        Chimera.ChimeraFrame {
            id: titleFrame

            anchors.fill: parent

            tokens: tokens
            active: root.titleVisible
            hovered: !tokens.flatSurface && titleMouseArea.containsMouse
            pressed: !tokens.flatSurface && titleMouseArea.pressed
            focused: titleMouseArea.activeFocus
            showStateRail: false

            RowLayout {
                anchors.fill: parent
                spacing: tokens.space2

                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    Layout.alignment: Qt.AlignVCenter

                    visible: Boolean(Plasmoid.configuration.showIcon)
                        && root.activeIcon !== ""
                    source: root.activeIcon
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    text: root.renderedTitle
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                    maximumLineCount: 1

                    font.family: "Noto Sans"
                    color: tokens.textColor
                }
            }
        }

        MouseArea {
            id: titleMouseArea

            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            hoverEnabled: true
            activeFocusOnTab: true
            cursorShape: Qt.PointingHandCursor

            Accessible.name: root.renderedTitle === ""
                ? qsTr("No active window")
                : qsTr("Active window: %1").arg(root.renderedTitle)
            Accessible.description: qsTr("Double-click to maximize or restore")
            Accessible.role: Accessible.Button

            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton) {
                    root.closeActiveWindow();
                }
            }
            onDoubleClicked: mouse => {
                if (mouse.button === Qt.LeftButton) {
                    root.toggleActiveMaximized();
                }
            }
            onWheel: wheel => {
                const delta = wheel.angleDelta.y || wheel.angleDelta.x;
                root.cycleWindow(delta > 0 ? -1 : delta < 0 ? 1 : 0);
            }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return
                        || event.key === Qt.Key_Space) {
                    root.toggleActiveMaximized();
                    event.accepted = true;
                }
            }
        }
    }
}
