// SPDX-License-Identifier: MIT

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    property alias cfg_labelMode: labelMode.currentIndex
    property alias cfg_hideWhenSingle: hideWhenSingle.checked
    property alias cfg_wrapWheel: wrapWheel.checked
    property alias cfg_invertWheel: invertWheel.checked
    property alias cfg_density: density.currentIndex
    property alias cfg_surfaceStyle: surfaceStyle.currentIndex
    property alias cfg_bevelDepth: bevelDepth.value
    property alias cfg_motionEnabled: motionEnabled.checked

    Kirigami.FormLayout {
        anchors.fill: parent

        QQC2.ComboBox {
            id: labelMode

            Kirigami.FormData.label: qsTr("Button labels:")
            model: [qsTr("Numbers"), qsTr("Desktop names"), qsTr("Dots")]
        }

        QQC2.CheckBox {
            id: hideWhenSingle

            text: qsTr("Hide when only one desktop exists")
        }

        QQC2.CheckBox {
            id: wrapWheel

            text: qsTr("Wrap wheel navigation at the ends")
        }

        QQC2.CheckBox {
            id: invertWheel

            text: qsTr("Invert wheel direction")
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
