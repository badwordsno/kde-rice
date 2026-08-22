// SPDX-License-Identifier: MIT

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root

    readonly property int preferredTitleWidth: Kirigami.Units.gridUnit * 18
    property string activeTitle: ""

    preferredRepresentation: fullRepresentation

    Layout.minimumWidth: Kirigami.Units.gridUnit * 8
    Layout.preferredWidth: preferredTitleWidth
    Layout.maximumWidth: Kirigami.Units.gridUnit * 20
    Layout.fillHeight: true

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.constraintHints: Plasmoid.CanFillArea

    toolTipMainText: activeTitle
    toolTipSubText: activeTitle === "" ? "" : qsTr("Active window")

    function refreshActiveTitle() {
        const activeIndex = tasksModel.activeTask;
        activeTitle = activeIndex.valid
            ? String(tasksModel.data(activeIndex, 0) || "")
            : "";
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
        implicitWidth: root.preferredTitleWidth
        implicitHeight: Kirigami.Units.gridUnit

        PlasmaComponents.Label {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing

            text: root.activeTitle
            textFormat: Text.PlainText
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            maximumLineCount: 1

            font.family: "Noto Sans"

            Accessible.name: root.activeTitle === ""
                ? qsTr("No active window")
                : qsTr("Active window: %1").arg(root.activeTitle)
        }
    }
}
