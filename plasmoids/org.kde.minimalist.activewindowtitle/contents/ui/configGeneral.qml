// SPDX-License-Identifier: MIT

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    property alias cfg_titleTemplate: titleTemplate.text
    property alias cfg_showIcon: showIcon.checked
    property alias cfg_widthMode: widthMode.currentIndex
    property alias cfg_minimumWidthUnits: minimumWidth.value
    property alias cfg_preferredWidthUnits: preferredWidth.value
    property alias cfg_maximumWidthUnits: maximumWidth.value
    property alias cfg_maximizedOnly: maximizedOnly.checked
    property alias cfg_wheelSwitch: wheelSwitch.checked
    property alias cfg_doubleClickMaximize: doubleClickMaximize.checked
    property alias cfg_middleClickClose: middleClickClose.checked
    property alias cfg_density: density.currentIndex
    property alias cfg_surfaceStyle: surfaceStyle.currentIndex
    property alias cfg_bevelDepth: bevelDepth.value
    property alias cfg_motionEnabled: motionEnabled.checked

    Kirigami.FormLayout {
        anchors.fill: parent

        QQC2.TextField {
            id: titleTemplate

            Kirigami.FormData.label: qsTr("Title template:")
            placeholderText: "{app} · {title}"
        }

        QQC2.CheckBox {
            id: showIcon

            text: qsTr("Show the active application icon")
        }

        QQC2.ComboBox {
            id: widthMode

            Kirigami.FormData.label: qsTr("Width policy:")
            model: [qsTr("Fit contents"), qsTr("Bounded"), qsTr("Fixed")]
        }

        QQC2.SpinBox {
            id: minimumWidth

            Kirigami.FormData.label: qsTr("Minimum grid units:")
            from: 4
            to: 40
        }

        QQC2.SpinBox {
            id: preferredWidth

            Kirigami.FormData.label: qsTr("Preferred grid units:")
            from: 4
            to: 60
        }

        QQC2.SpinBox {
            id: maximumWidth

            Kirigami.FormData.label: qsTr("Maximum grid units:")
            from: 4
            to: 80
        }

        QQC2.CheckBox {
            id: maximizedOnly

            text: qsTr("Show a title only for maximized windows")
        }

        QQC2.CheckBox {
            id: wheelSwitch

            text: qsTr("Switch windows with the mouse wheel")
        }

        QQC2.CheckBox {
            id: doubleClickMaximize

            text: qsTr("Double-click to maximize or restore")
        }

        QQC2.CheckBox {
            id: middleClickClose

            text: qsTr("Middle-click closes the active window")
        }

        QQC2.ComboBox {
            id: density

            Kirigami.FormData.label: qsTr("Density:")
            model: [qsTr("Dense"), qsTr("Comfortable")]
        }

        QQC2.ComboBox {
            id: surfaceStyle

            Kirigami.FormData.label: qsTr("Surface style:")
            model: [qsTr("Flat strip"), qsTr("Soft cells"),
                qsTr("Beveled cells")]
        }

        QQC2.SpinBox {
            id: bevelDepth

            Kirigami.FormData.label: qsTr("Bevel depth:")
            enabled: surfaceStyle.currentIndex === 2
            from: 0
            to: 2
        }

        QQC2.CheckBox {
            id: motionEnabled

            text: qsTr("Use short state transitions")
        }
    }
}
