// SPDX-License-Identifier: MIT
// Generated copies of this file live inside each project Plasmoid package.

import QtQuick
import org.kde.kirigami as Kirigami

QtObject {
    id: root

    readonly property int schemaVersion: 2
    property int density: 0
    // 0: flat strip, 1: soft cells, 2: beveled cells.
    property int surfaceStyle: 0
    property int bevelDepth: 2
    property bool motionEnabled: true

    readonly property int unit: 2
    readonly property int space1: unit
    readonly property int space2: unit * 2
    readonly property int space3: unit * 3
    readonly property int space4: unit * 4
    readonly property int edgeWidth: 1
    readonly property int focusWidth: 2
    readonly property int radius: 0
    readonly property int motionFast: motionEnabled ? 110 : 0
    readonly property int contentInset: density === 0 ? space2 : space3
    readonly property int cellGap: density === 0 ? 1 : space1
    readonly property int panelHeight: 32
    readonly property int controlHeight: 24
    readonly property bool flatSurface: surfaceStyle === 0
    readonly property bool softSurface: surfaceStyle === 1
    readonly property bool beveledSurface: surfaceStyle === 2

    readonly property color canvas: Kirigami.Theme.backgroundColor
    readonly property color textColor: Kirigami.Theme.textColor
    readonly property color textMuted: Kirigami.Theme.disabledTextColor
    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color accentText: Kirigami.Theme.highlightedTextColor
    readonly property color warning: Kirigami.Theme.neutralTextColor
    readonly property color danger: Kirigami.Theme.negativeTextColor
    readonly property color surface: Qt.tint(canvas,
        Qt.rgba(textColor.r, textColor.g, textColor.b, 0.035))
    readonly property color surfaceRaised: Qt.tint(canvas,
        Qt.rgba(textColor.r, textColor.g, textColor.b, 0.075))
    readonly property color surfaceHovered: Qt.tint(surfaceRaised,
        Qt.rgba(accent.r, accent.g, accent.b, 0.12))
    readonly property color surfaceSunken: Qt.tint(canvas,
        Qt.rgba(0, 0, 0, 0.14))
    readonly property color edgeLight: Qt.tint(surfaceRaised,
        Qt.rgba(textColor.r, textColor.g, textColor.b, 0.28))
    readonly property color edgeDark: Qt.tint(surfaceRaised,
        Qt.rgba(0, 0, 0, 0.5))
    readonly property color edgeMiddle: Qt.tint(textColor,
        Qt.rgba(canvas.r, canvas.g, canvas.b, 0.68))

    function stateColor(severity) {
        if (severity >= 2) {
            return danger;
        }
        if (severity === 1) {
            return warning;
        }
        return accent;
    }
}
