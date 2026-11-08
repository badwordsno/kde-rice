// SPDX-License-Identifier: MIT

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    property alias cfg_metricOrder: metricOrder.text
    property alias cfg_showCpu: showCpu.checked
    property alias cfg_showMemory: showMemory.checked
    property alias cfg_showGpu: showGpu.checked
    property alias cfg_showVolume: showVolume.checked
    property alias cfg_updateRateMs: updateRate.value
    property alias cfg_warningPercent: warningPercent.value
    property alias cfg_criticalPercent: criticalPercent.value
    property alias cfg_showStateRails: showStateRails.checked
    property alias cfg_density: density.currentIndex
    property alias cfg_surfaceStyle: surfaceStyle.currentIndex
    property alias cfg_bevelDepth: bevelDepth.value
    property alias cfg_motionEnabled: motionEnabled.checked

    Kirigami.FormLayout {
        anchors.fill: parent

        QQC2.TextField {
            id: metricOrder

            Kirigami.FormData.label: qsTr("Metric order:")
            placeholderText: "CPU,RAM,GPU,VOL"
        }

        QQC2.CheckBox {
            id: showCpu

            text: qsTr("Show CPU")
        }

        QQC2.CheckBox {
            id: showMemory

            text: qsTr("Show memory")
        }

        QQC2.CheckBox {
            id: showGpu

            text: qsTr("Show GPU when a sensor is available")
        }

        QQC2.CheckBox {
            id: showVolume

            text: qsTr("Show output volume")
        }

        QQC2.SpinBox {
            id: updateRate

            Kirigami.FormData.label: qsTr("Sensor interval (ms):")
            from: 250
            to: 10000
            stepSize: 250
        }

        QQC2.SpinBox {
            id: warningPercent

            Kirigami.FormData.label: qsTr("Warning threshold:")
            from: 1
            to: 99
            textFromValue: value => value + "%"
        }

        QQC2.SpinBox {
            id: criticalPercent

            Kirigami.FormData.label: qsTr("Critical threshold:")
            from: 2
            to: 100
            textFromValue: value => value + "%"
        }

        QQC2.CheckBox {
            id: showStateRails

            text: qsTr("Show threshold rails")
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
