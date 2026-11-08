// SPDX-License-Identifier: MIT

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

import "chimera" as Chimera

PlasmoidItem {
    id: root

    readonly property int sensorUpdateLimit: 2000
    readonly property int configuredSensorUpdateLimit: Math.max(250,
        Math.min(10000, Number(Plasmoid.configuration.updateRateMs)
            || sensorUpdateLimit))
    readonly property string metricsFontFamily: "Noto Sans"
    readonly property real metricsSpacing: tokens.flatSurface ? 0 : tokens.cellGap
    readonly property real metricsPadding: Kirigami.Units.smallSpacing
    readonly property real stableLabelWidth: Math.ceil(Math.max(
        labelMetrics.advanceWidth("CPU 100%"),
        labelMetrics.advanceWidth("RAM 100%"),
        labelMetrics.advanceWidth("GPU 100%"),
        labelMetrics.advanceWidth("VOL 999%")))
    readonly property real stableMetricCellWidth: stableLabelWidth
        + tokens.contentInset * 2
    readonly property var orderedMetricCodes: normalizedMetricOrder(
        Plasmoid.configuration.metricOrder)
    readonly property var visibleMetricCodes: orderedMetricCodes.filter(
        code => metricVisible(code))
    readonly property int visibleMetricCount: visibleMetricCodes.length
    readonly property real stableMetricsWidth: visibleMetricCount === 0 ? 0
        : stableMetricCellWidth * visibleMetricCount
            + metricsSpacing * (visibleMetricCount - 1)
            + metricsPadding * 2
    readonly property var activeGpuSensor: gpuPrimary.status === Sensors.Sensor.Ready
        ? gpuPrimary
        : gpuAggregate
    readonly property bool gpuAvailable: activeGpuSensor.status === Sensors.Sensor.Ready
    readonly property var volumeProvider: volumeProviderLoader.status === Loader.Ready
        ? volumeProviderLoader.item : null
    readonly property var outputSink: volumeProvider === null
        ? null : volumeProvider.sink
    readonly property bool volumeContextReady: volumeProvider !== null
        && Boolean(volumeProvider.contextReady)
    readonly property bool volumeAvailable: volumeProvider !== null
        && Boolean(volumeProvider.available)
    readonly property bool volumeMuted: volumeProvider !== null
        && Boolean(volumeProvider.muted)
    readonly property real normalVolume: volumeProvider === null
        ? 0 : Number(volumeProvider.normalVolume)

    preferredRepresentation: fullRepresentation

    Layout.minimumWidth: stableMetricsWidth
    Layout.preferredWidth: stableMetricsWidth
    Layout.maximumWidth: stableMetricsWidth
    Layout.minimumHeight: tokens.controlHeight
    Layout.preferredHeight: tokens.controlHeight
    Layout.maximumHeight: tokens.controlHeight
    Layout.fillHeight: false

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.status: visibleMetricCount > 0
        ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus

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

    function normalizedMetricOrder(configuredOrder) {
        const allowed = ["CPU", "RAM", "GPU", "VOL"];
        const result = [];
        const candidates = String(configuredOrder || "").toUpperCase().split(",");
        for (let index = 0; index < candidates.length; ++index) {
            const candidate = candidates[index].trim();
            if (allowed.indexOf(candidate) !== -1
                    && result.indexOf(candidate) === -1) {
                result.push(candidate);
            }
        }
        for (let index = 0; index < allowed.length; ++index) {
            if (result.indexOf(allowed[index]) === -1) {
                result.push(allowed[index]);
            }
        }
        return result;
    }

    function metricVisible(code) {
        switch (code) {
        case "CPU":
            return Boolean(Plasmoid.configuration.showCpu);
        case "RAM":
            return Boolean(Plasmoid.configuration.showMemory);
        case "GPU":
            return Boolean(Plasmoid.configuration.showGpu) && gpuAvailable;
        case "VOL":
            return Boolean(Plasmoid.configuration.showVolume);
        default:
            return false;
        }
    }

    function metricColumn(code) {
        return visibleMetricCodes.indexOf(code);
    }

    function percentageValue(sensor) {
        const numericValue = Number(sensor.value);
        if (sensor.status !== Sensors.Sensor.Ready || !Number.isFinite(numericValue)) {
            return -1;
        }
        return Math.max(0, Math.min(100, Math.round(numericValue)));
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
            // A figure space reserves one digit, unlike a normal space.
            result = "\u2007" + result;
        }
        return result;
    }

    function outputVolumeValue() {
        if (!volumeAvailable) {
            return -1;
        }
        const normalVolume = Number(root.normalVolume);
        const currentVolume = Number(outputSink.volume);
        if (!Number.isFinite(normalVolume) || normalVolume <= 0
                || !Number.isFinite(currentVolume)) {
            return -1;
        }
        return Math.max(0, Math.min(999,
            Math.round(currentVolume / normalVolume * 100)));
    }

    function outputVolumePercentage() {
        if (!volumeAvailable) {
            return "--%";
        }
        const normalVolume = Number(root.normalVolume);
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
            result = "\u2007" + result;
        }
        return result;
    }

    function severityFor(value) {
        if (value < 0) {
            return 0;
        }
        const warning = Math.max(1, Math.min(99,
            Number(Plasmoid.configuration.warningPercent) || 70));
        const critical = Math.max(warning + 1, Math.min(100,
            Number(Plasmoid.configuration.criticalPercent) || 90));
        return value >= critical ? 2 : value >= warning ? 1 : 0;
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

    Loader {
        id: volumeProviderLoader

        active: Boolean(Plasmoid.configuration.showVolume)
        asynchronous: false
        source: "providers/VolumeProvider.qml"

        onStatusChanged: {
            if (status === Loader.Error) {
                console.warn("Minimalist Resource Usage: volume provider is unavailable");
            }
        }
    }

    FontMetrics {
        id: labelMetrics

        font.family: root.metricsFontFamily
        font.pointSize: Kirigami.Theme.defaultFont.pointSize
        font.weight: Kirigami.Theme.defaultFont.weight
        font.features: { "tnum": 1 }
    }

    Sensors.Sensor {
        id: cpu
        sensorId: "cpu/all/usage"
        updateRateLimit: root.configuredSensorUpdateLimit
    }

    Sensors.Sensor {
        id: memory
        sensorId: "memory/physical/usedPercent"
        updateRateLimit: root.configuredSensorUpdateLimit
    }

    Sensors.Sensor {
        id: gpuPrimary
        sensorId: "gpu/gpu0/usage"
        updateRateLimit: root.configuredSensorUpdateLimit
    }

    Sensors.Sensor {
        id: gpuAggregate
        sensorId: "gpu/all/usage"
        updateRateLimit: root.configuredSensorUpdateLimit
    }

    fullRepresentation: GridLayout {
        anchors.fill: parent
        anchors.leftMargin: root.metricsPadding
        anchors.rightMargin: root.metricsPadding

        rows: 1
        columns: Math.max(1, root.visibleMetricCount)
        rowSpacing: 0
        columnSpacing: root.metricsSpacing
        implicitHeight: tokens.controlHeight

        Chimera.ChimeraFrame {
            id: cpuFrame

            Layout.column: root.metricColumn("CPU")
            Layout.minimumWidth: root.stableMetricCellWidth
            Layout.preferredWidth: root.stableMetricCellWidth
            Layout.maximumWidth: root.stableMetricCellWidth
            Layout.fillHeight: true

            visible: root.metricVisible("CPU")
            tokens: tokens
            severity: root.severityFor(root.percentageValue(cpu))
            stateRailInset: tokens.space2
            showLeadingSeparator: root.metricColumn("CPU") > 0
            showStateRail: !tokens.flatSurface
                && Boolean(Plasmoid.configuration.showStateRails)
                && severity > 0

            PlasmaComponents.Label {
                id: cpuLabel

                anchors.fill: parent
                text: "CPU " + root.paddedPercentage(cpu)
                textFormat: Text.PlainText
                font: labelMetrics.font
                color: cpuFrame.severity > 0
                    ? tokens.stateColor(cpuFrame.severity) : tokens.textColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                Accessible.name: qsTr("CPU usage: %1").arg(root.percentage(cpu))
            }
        }

        Chimera.ChimeraFrame {
            id: memoryFrame

            Layout.column: root.metricColumn("RAM")
            Layout.minimumWidth: root.stableMetricCellWidth
            Layout.preferredWidth: root.stableMetricCellWidth
            Layout.maximumWidth: root.stableMetricCellWidth
            Layout.fillHeight: true

            visible: root.metricVisible("RAM")
            tokens: tokens
            severity: root.severityFor(root.percentageValue(memory))
            stateRailInset: tokens.space2
            showLeadingSeparator: root.metricColumn("RAM") > 0
            showStateRail: !tokens.flatSurface
                && Boolean(Plasmoid.configuration.showStateRails)
                && severity > 0

            PlasmaComponents.Label {
                id: memoryLabel

                anchors.fill: parent
                text: "RAM " + root.paddedPercentage(memory)
                textFormat: Text.PlainText
                font: labelMetrics.font
                color: memoryFrame.severity > 0
                    ? tokens.stateColor(memoryFrame.severity) : tokens.textColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                Accessible.name: qsTr("Memory usage: %1").arg(root.percentage(memory))
            }
        }

        Chimera.ChimeraFrame {
            id: gpuFrame

            Layout.column: root.metricColumn("GPU")
            Layout.minimumWidth: root.stableMetricCellWidth
            Layout.preferredWidth: root.stableMetricCellWidth
            Layout.maximumWidth: root.stableMetricCellWidth
            Layout.fillHeight: true

            visible: root.metricVisible("GPU")
            tokens: tokens
            severity: root.severityFor(root.percentageValue(root.activeGpuSensor))
            stateRailInset: tokens.space2
            showLeadingSeparator: root.metricColumn("GPU") > 0
            showStateRail: !tokens.flatSurface
                && Boolean(Plasmoid.configuration.showStateRails)
                && severity > 0

            PlasmaComponents.Label {
                id: gpuLabel

                anchors.fill: parent
                text: "GPU " + root.paddedPercentage(root.activeGpuSensor)
                textFormat: Text.PlainText
                font: labelMetrics.font
                color: gpuFrame.severity > 0
                    ? tokens.stateColor(gpuFrame.severity) : tokens.textColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                Accessible.name: qsTr("GPU usage: %1")
                    .arg(root.percentage(root.activeGpuSensor))
            }
        }

        Chimera.ChimeraFrame {
            id: volumeFrame

            Layout.column: root.metricColumn("VOL")
            Layout.minimumWidth: root.stableMetricCellWidth
            Layout.preferredWidth: root.stableMetricCellWidth
            Layout.maximumWidth: root.stableMetricCellWidth
            Layout.fillHeight: true

            visible: root.metricVisible("VOL")
            tokens: tokens
            enabled: root.volumeAvailable
            showLeadingSeparator: root.metricColumn("VOL") > 0

            PlasmaComponents.Label {
                id: volumeLabel

                anchors.fill: parent
                text: "VOL " + root.paddedOutputVolume()
                textFormat: Text.PlainText
                font: labelMetrics.font
                color: tokens.textColor
                opacity: root.volumeMuted ? 0.55 : 1
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                Accessible.name: root.volumeMuted
                    ? qsTr("Output muted at %1").arg(root.outputVolumePercentage())
                    : qsTr("Output volume: %1").arg(root.outputVolumePercentage())
            }
        }
    }
}
