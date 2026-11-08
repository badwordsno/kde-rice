    readonly property real stableLabelWidth: Math.ceil(labelMetrics.advanceWidth)
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
TextMetrics {
        id: labelMetrics

        font.family: root.metricsFontFamily
        text: "CPU 100%"
    }
