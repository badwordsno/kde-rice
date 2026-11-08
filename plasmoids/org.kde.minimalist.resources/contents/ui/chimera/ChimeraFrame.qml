// SPDX-License-Identifier: MIT
// Generated copies of this file live inside each project Plasmoid package.

import QtQuick

Item {
    id: root

    required property var tokens
    property bool active: false
    property bool hovered: false
    property bool pressed: false
    property bool focused: false
    property int severity: 0
    property bool showStateRail: active || severity > 0
    property int stateRailInset: 0
    property bool showLeadingSeparator: false
    property color fillColor: pressed
        ? tokens.surfaceSunken
        : hovered ? tokens.surfaceHovered
            : tokens.flatSurface ? "transparent" : tokens.surfaceRaised
    default property alias contentData: contentItem.data

    implicitWidth: contentItem.childrenRect.width + tokens.contentInset * 2
    implicitHeight: contentItem.childrenRect.height + tokens.contentInset * 2
    opacity: enabled ? 1 : 0.48

    Rectangle {
        anchors.fill: parent
        radius: root.tokens.radius
        color: root.fillColor

        Behavior on color {
            ColorAnimation { duration: root.tokens.motionFast }
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.tokens.edgeWidth
        visible: root.tokens.beveledSurface && root.tokens.bevelDepth > 0
        color: root.pressed ? root.tokens.edgeDark : root.tokens.edgeLight
    }

    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: root.tokens.edgeWidth
        visible: root.tokens.beveledSurface && root.tokens.bevelDepth > 0
        color: root.pressed ? root.tokens.edgeDark : root.tokens.edgeLight
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.tokens.edgeWidth
        visible: root.tokens.beveledSurface && root.tokens.bevelDepth > 0
        color: root.pressed ? root.tokens.edgeLight : root.tokens.edgeDark
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: root.tokens.edgeWidth
        visible: root.tokens.beveledSurface && root.tokens.bevelDepth > 0
        color: root.pressed ? root.tokens.edgeLight : root.tokens.edgeDark
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.tokens.edgeWidth
        color: "transparent"
        radius: root.tokens.radius
        border.width: root.tokens.beveledSurface
            && root.tokens.bevelDepth > 1 ? root.tokens.edgeWidth : 0
        border.color: root.tokens.edgeMiddle
    }

    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.tokens.edgeWidth
        height: Math.max(root.tokens.space4,
            parent.height - root.tokens.space3 * 2)
        color: root.tokens.edgeMiddle
        opacity: 0.55
        visible: root.tokens.flatSurface && root.showLeadingSeparator
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.stateRailInset
        anchors.rightMargin: root.stateRailInset
        height: root.tokens.focusWidth
        color: root.tokens.stateColor(root.severity)
        opacity: root.showStateRail ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: root.tokens.motionFast }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.tokens.space1
        color: "transparent"
        radius: root.tokens.radius
        border.width: root.tokens.focusWidth
        border.color: root.tokens.accent
        opacity: root.focused ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: root.tokens.motionFast }
        }
    }

    Item {
        id: contentItem

        anchors.fill: parent
        anchors.margins: root.tokens.contentInset
    }
}
