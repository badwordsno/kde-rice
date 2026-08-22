// SPDX-License-Identifier: MIT

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.private.volume

PlasmoidItem {
    id: root

    readonly property int sensorUpdateLimit: 2000
    readonly property string metricsFontFamily: "Noto Sans"
    readonly property real metricsSpacing: Kirigami.Units.smallSpacing
    readonly property real metricsPadding: Kirigami.Units.smallSpacing
    readonly property real stableLabelWidth: Math.ceil(labelMetrics.advanceWidth)
    readonly property int visibleMetricCount: gpuAvailable ? 4 : 3
    readonly property real stableMetricsWidth: stableLabelWidth * visibleMetricCount
        + metricsSpacing * (visibleMetricCount - 1)
        + metricsPadding * 2
    readonly property var activeGpuSensor: gpuPrimary.status === Sensors.Sensor.Ready
        ? gpuPrimary
        : gpuAggregate
    readonly property bool gpuAvailable: activeGpuSensor.status === Sensors.Sensor.Ready
    readonly property var outputSink: PreferredDevice.sink
    readonly property bool volumeContextReady: Context.state === Context.State.Ready
    readonly property bool volumeAvailable: volumeContextReady
        && outputSink !== null
        && outputSink !== undefined
        && outputSink.name !== "auto_null"
    readonly property bool volumeMuted: volumeAvailable && Boolean(outputSink.muted)

    preferredRepresentation: fullRepresentation

    Layout.minimumWidth: stableMetricsWidth
    Layout.preferredWidth: stableMetricsWidth
    Layout.maximumWidth: stableMetricsWidth
    Layout.fillHeight: true

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    toolTipMainText: qsTr("Resource usage")
    toolTipSubText: {
        const resources = gpuAvailable
            ? qsTr("CPU, RAM, and GPU utilization")
            : qsTr("CPU and RAM utilization; no GPU sensor is available");
        if (!volumeAvailable) {
            return resources + "; " + qsTr("output volume is unavailable");
        }
        if (volumeMuted) {
            return resources + "; " + qsTr("output muted at %1").arg(outputVolumePercentage());
        }
        return resources + "; " + qsTr("output volume %1").arg(outputVolumePercentage());
    }

    function percentage(sensor) {
        const numericValue = Number(sensor.value);
        if (sensor.status !== Sensors.Sensor.Ready || !Number.isFinite(numericValue)) {
            return "--";
        }
        return Math.max(0, Math.min(100, Math.round(numericValue))) + "%";
    }

    function paddedPercentage(sensor) {
        let result = percentage(sensor);
        while (result.length < 4) {
            result = " " + result;
        }
        return result;
    }

    function outputVolumePercentage() {
        if (!volumeAvailable) {
            return "--%";
        }
        const normalVolume = Number(PulseAudio.NormalVolume);
        const currentVolume = Number(outputSink.volume);
        if (!Number.isFinite(normalVolume) || normalVolume <= 0
                || !Number.isFinite(currentVolume)) {
            return "--%";
        }
        return Math.max(0, Math.min(999,
            Math.round(currentVolume / normalVolume * 100))) + "%";
    }

    function paddedOutputVolume() {
        let result = outputVolumePercentage();
        while (result.length < 4) {
            result = " " + result;
        }
        return result;
    }

    TextMetrics {
        id: labelMetrics

        font.family: root.metricsFontFamily
        text: "CPU 100%"
    }

    Sensors.Sensor {
        id: cpu
        sensorId: "cpu/all/usage"
        updateRateLimit: root.sensorUpdateLimit
    }

    Sensors.Sensor {
        id: memory
        sensorId: "memory/physical/usedPercent"
        updateRateLimit: root.sensorUpdateLimit
    }

    Sensors.Sensor {
        id: gpuPrimary
        sensorId: "gpu/gpu0/usage"
        updateRateLimit: root.sensorUpdateLimit
    }

    Sensors.Sensor {
        id: gpuAggregate
        sensorId: "gpu/all/usage"
        updateRateLimit: root.sensorUpdateLimit
    }

    fullRepresentation: RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.metricsPadding
        anchors.rightMargin: root.metricsPadding

        spacing: root.metricsSpacing
        implicitHeight: Kirigami.Units.gridUnit

        PlasmaComponents.Label {
            id: cpuLabel
            Layout.minimumWidth: root.stableLabelWidth
            Layout.preferredWidth: root.stableLabelWidth
            Layout.maximumWidth: root.stableLabelWidth
            Layout.fillHeight: true

            text: "CPU " + root.paddedPercentage(cpu)
            textFormat: Text.PlainText
            font.family: root.metricsFontFamily
            verticalAlignment: Text.AlignVCenter
            Accessible.name: qsTr("CPU usage: %1").arg(root.percentage(cpu))
        }

        PlasmaComponents.Label {
            id: memoryLabel
            Layout.minimumWidth: root.stableLabelWidth
            Layout.preferredWidth: root.stableLabelWidth
            Layout.maximumWidth: root.stableLabelWidth
            Layout.fillHeight: true

            text: "RAM " + root.paddedPercentage(memory)
            textFormat: Text.PlainText
            font.family: root.metricsFontFamily
            verticalAlignment: Text.AlignVCenter
            Accessible.name: qsTr("Memory usage: %1").arg(root.percentage(memory))
        }

        PlasmaComponents.Label {
            id: gpuLabel
            Layout.minimumWidth: root.stableLabelWidth
            Layout.preferredWidth: root.stableLabelWidth
            Layout.maximumWidth: root.stableLabelWidth
            Layout.fillHeight: true

            visible: root.gpuAvailable
            text: "GPU " + root.paddedPercentage(root.activeGpuSensor)
            textFormat: Text.PlainText
            font.family: root.metricsFontFamily
            verticalAlignment: Text.AlignVCenter
            Accessible.name: qsTr("GPU usage: %1").arg(root.percentage(root.activeGpuSensor))
        }

        PlasmaComponents.Label {
            id: volumeLabel
            Layout.minimumWidth: root.stableLabelWidth
            Layout.preferredWidth: root.stableLabelWidth
            Layout.maximumWidth: root.stableLabelWidth
            Layout.fillHeight: true

            text: "VOL " + root.paddedOutputVolume()
            textFormat: Text.PlainText
            font.family: root.metricsFontFamily
            opacity: root.volumeMuted ? 0.55 : 1
            verticalAlignment: Text.AlignVCenter
            Accessible.name: root.volumeMuted
                ? qsTr("Output muted at %1").arg(root.outputVolumePercentage())
                : qsTr("Output volume: %1").arg(root.outputVolumePercentage())
        }
    }
}
