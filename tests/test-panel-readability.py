#!/usr/bin/env python3
"""Exercise actual QML excerpts with synthetic data in an isolated Qt session.

Requires PySide6 and the installed KDE QML imports. --render also writes the
review image and measurements; it never reads a live panel or sensor.
"""
import configparser
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / 'tests/fixtures/readability'
OUTPUT = ROOT / 'research/ricing/experiments/readability-study'
UNAVAILABLE = 77


def unavailable(reason):
    print('NOT RUN: readability dependencies unavailable: ' + reason, file=sys.stderr)
    raise SystemExit(UNAVAILABLE)


def workspace_excerpt(source):
    start = source.index('                    Chimera.ChimeraFrame {')
    return source[start:source.index('\n\n                    MouseArea {', start)]


def metrics_excerpt(source):
    parts = [re.search(r'    readonly property real stableLabelWidth:[\s\S]*?(?=\n    readonly property)', source).group()]
    for begin, end in [('    function percentage(sensor)', '    function outputVolumeValue()'),
                       ('    FontMetrics {', '    Sensors.Sensor {')]:
        parts.append(source[source.index(begin):source.index(end)].strip())
    return '\n'.join(parts)


def build_qml():
    workspace = (ROOT / 'plasmoids/org.kde.minimalist.workspaces/contents/ui/main.qml').read_text()
    resources = (ROOT / 'plasmoids/org.kde.minimalist.resources/contents/ui/main.qml').read_text()
    # The same measured font must drive every rendered metric label.
    assert resources.count('font: labelMetrics.font') == 4
    definitions = []
    instances = []
    for revision, frame, metrics in [
        ('Before', (FIXTURES / 'workspace-frame-before.qml.inc').read_text(),
         (FIXTURES / 'resource-metrics-before.qml.inc').read_text()),
        ('After', workspace_excerpt(workspace), metrics_excerpt(resources))]:
        frame = frame.replace('Chimera.ChimeraFrame {', 'Chimera.ChimeraFrame { id: testedFrame;', 1)
        frame = frame.replace('PlasmaComponents.Label {', 'PlasmaComponents.Label { id: testedLabel;', 1)
        definitions.append('''
component WorkspaceREV: Item {
    id: root
    width: 132; height: 24
    property int sample: 0
    readonly property int configuredButtonWidth: 132
    function desktopLabel(index) { return String(index + 1); }
    QtObject { id: desktopButton; readonly property bool current: true; readonly property int index: 1 }
    QtObject { id: desktopMouseArea; readonly property bool containsMouse: root.sample === 1;
        readonly property bool pressed: root.sample === 2; readonly property bool activeFocus: root.sample === 3 }
    Chimera.ChimeraTokens { id: tokens; surfaceStyle: 1; motionEnabled: false }
    FRAME
    readonly property string report: JSON.stringify({
        fill: String(testedFrame.fillColor), text: String(testedLabel.color),
        accent: String(tokens.accent), rail: testedFrame.showStateRail,
        focus: testedFrame.focused, fontPixels: testedLabel.font.pixelSize
    })
}
'''.replace('REV', revision).replace('FRAME', frame))
        definitions.append('''
component MetricsREV: Item {
    id: root
    width: 760; height: 150
    readonly property string metricsFontFamily: "Noto Sans"
    METRICS
    FontMetrics { id: measure; font: labelMetrics.font }
    readonly property string report: {
        const widths = [];
        let overflow = 0;
        for (const code of ["CPU", "RAM", "GPU", "VOL"]) {
            for (let n = 0; n <= (code === "VOL" ? 999 : 100); ++n) {
                // VOL uses the same figure-space padding; its bounds are
                // covered separately by test-minimalist-v03.sh.
                let value = n <= 100 ? root.paddedPercentage({status: Sensors.Sensor.Ready, value: n}) : n + "%";
                const width = measure.advanceWidth(code + " " + value);
                overflow = Math.max(overflow, width - root.stableLabelWidth);
                if (code === "CPU" && [9, 10, 100].indexOf(n) >= 0) widths.push(width);
            }
        }
        return JSON.stringify({reserved: root.stableLabelWidth, cpuWidths: widths,
            maxOverflow: overflow, fontPointSize: labelMetrics.font.pointSize,
            ram100: measure.advanceWidth("RAM 100%")});
    }
    Row {
        spacing: 42
        Repeater {
            model: [9, 10, 100]
            Column {
                required property int modelData
                spacing: 8
                Text { text: parent.modelData + "%"; color: "#b7b5be"; font.pointSize: 10 }
                Chimera.ChimeraFrame {
                    width: root.stableLabelWidth + 8; height: 24
                    tokens: Chimera.ChimeraTokens { surfaceStyle: 1; motionEnabled: false }
                    Text {
                        anchors.fill: parent
                        text: "CPU " + root.paddedPercentage({status: Sensors.Sensor.Ready, value: modelData})
                        font: labelMetrics.font; color: "#e8e8eb"
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }
}
'''.replace('REV', revision).replace('METRICS', metrics))
        row_y = 138 if revision == 'Before' else 201
        metric_y = 304 if revision == 'Before' else 399
        for state, label in enumerate(['idle', 'hover', 'pressed', 'focus']):
            instances.append(f'Workspace{revision} {{ objectName: "{revision.lower()}-{label}"; x: {174 + state * 167}; y: {row_y}; sample: {state} }}')
        instances.append(f'Metrics{revision} {{ objectName: "{revision.lower()}-metrics"; x: 174; y: {metric_y} }}')
    return '''
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.ksysguard.sensors as Sensors
import "CHIMERA" as Chimera
Rectangle {
    width: 884; height: 527; color: "#000000"
    DEFINITIONS
    Text { x: 28; y: 22; text: "Soft cells · 가독성과 상태 피드백"; color: "#f0f0f2"; font.pointSize: 18 }
    Text { x: 28; y: 63; text: "실제 QML 발췌 + 합성 입력 · live 데스크톱 사진이 아닙니다"; color: "#b7b5be"; font.pointSize: 11 }
    Row { x: 174; y: 103; spacing: 35
        Repeater { model: ["선택", "선택 + hover", "선택 + pressed", "선택 + focus"]
            Text { required property string modelData; width: 132; text: modelData; color: "#b7b5be"; font.pointSize: 10 }
        }
    }
    Text { x: 28; y: 141; text: "변경 전"; color: "#b7b5be" }
    Text { x: 28; y: 204; text: "개선안"; color: "#e8e8eb" }
    Text { x: 28; y: 265; text: "자릿수 전환 · 동일한 폰트 / 셀 높이 24px"; color: "#b7b5be"; font.pointSize: 11 }
    Text { x: 28; y: 334; text: "변경 전"; color: "#b7b5be" }
    Text { x: 28; y: 429; text: "개선안"; color: "#e8e8eb" }
    INSTANCES
    Text { x: 28; y: 494; text: "선택 rail과 포커스 유지 · 글자 대비 개선 · 숫자 자리와 최대 폭 안정화"; color: "#b7b5be"; font.pointSize: 10 }
}
'''.replace('CHIMERA', (ROOT / 'design/chimera').as_uri()).replace('DEFINITIONS', '\n'.join(definitions)).replace('INSTANCES', '\n'.join(instances))


def child(render):
    # Refuse accidental direct execution in the user's normal desktop home.
    target = Path(os.environ.get('HOME', '/')).resolve()
    isolated = target.parent == Path('/tmp') and target.name.startswith('kde-rice-readability-')
    expected = {
        'XDG_CONFIG_HOME': str(target / '.config'),
        'XDG_DATA_HOME': str(target / '.local/share'),
        'XDG_STATE_HOME': str(target / '.local/state'),
        'XDG_CACHE_HOME': str(target / '.cache'),
        'XDG_RUNTIME_DIR': str(target / 'runtime'),
        'DBUS_SESSION_BUS_ADDRESS': 'unix:path=' + str(target / 'no-session-bus'),
        'QT_QPA_PLATFORM': 'offscreen', 'QT_QUICK_BACKEND': 'software',
    }
    if not isolated or any(os.environ.get(key) != value for key, value in expected.items()):
        raise SystemExit('FAIL: child requires the isolated test launcher')
    try:
        from PySide6.QtCore import QObject, QTimer, QUrl
        from PySide6.QtGui import QColor, QFont, QFontDatabase, QGuiApplication, QPalette
        from PySide6.QtQml import QQmlComponent
        from PySide6.QtQuick import QQuickView
    except (ImportError, OSError) as error:
        unavailable('PySide6/Qt: ' + str(error))
    app = QGuiApplication([])
    if 'Noto Sans' not in QFontDatabase.families():
        unavailable('Noto Sans font')
    app.setFont(QFont('Noto Sans', 11))
    palette = QPalette()
    scheme = configparser.ConfigParser(interpolation=None)
    scheme.read(ROOT / 'config/color-schemes/BlackMinimal.colors')
    for role, section, key in [('Window', 'Window', 'BackgroundNormal'),
        ('WindowText', 'Window', 'ForegroundNormal'), ('Button', 'Button', 'BackgroundNormal'),
        ('ButtonText', 'Button', 'ForegroundNormal'), ('Highlight', 'Selection', 'BackgroundNormal'),
        ('HighlightedText', 'Selection', 'ForegroundNormal')]:
        palette.setColor(getattr(QPalette.ColorRole, role), QColor(*map(int, scheme['Colors:' + section][key].split(','))))
    app.setPalette(palette)
    qml = Path(os.environ['HOME']) / 'readability.qml'
    qml.write_text(build_qml())
    view = QQuickView()
    # Probe only known dependency imports. Errors in the actual tested QML
    # remain failures, never a dependency skip that could hide a regression.
    probe = QQmlComponent(view.engine())
    probe.setData(b'''import QtQuick
import QtQuick.Layouts
import org.kde.kirigami
import org.kde.plasma.components
import org.kde.ksysguard.sensors
Item {}''', QUrl())
    if probe.isError():
        descriptions = [error.description() for error in probe.errors()]
        if descriptions and all(re.fullmatch(r'module "[^"]+" is not installed', error) for error in descriptions):
            unavailable('; '.join(descriptions))
        raise SystemExit('FAIL: readability dependency probe: ' + '; '.join(descriptions))
    view.setSource(QUrl.fromLocalFile(str(qml)))
    if view.status() == QQuickView.Error:
        raise SystemExit('FAIL: readability QML could not load: ' + '; '.join(e.toString() for e in view.errors()))
    view.show()
    outcome = []

    def inspect():
        try:
            result = {}
            for revision in ['before', 'after']:
                for state in ['idle', 'hover', 'pressed', 'focus', 'metrics']:
                    name = revision + '-' + state
                    obj = view.rootObject().findChild(QObject, name)
                    result[name] = json.loads(obj.property('report'))
            def luminance(color):
                c = QColor(color)
                v = [c.redF(), c.greenF(), c.blueF()]
                v = [x / 12.92 if x <= .04045 else ((x + .055) / 1.055) ** 2.4 for x in v]
                return sum(a*b for a, b in zip(v, [.2126, .7152, .0722]))
            for revision in ['before', 'after']:
                for state in ['idle', 'hover', 'pressed', 'focus']:
                    row = result[revision + '-' + state]
                    low, high = sorted([luminance(row['text']), luminance(row['fill'])])
                    row['contrast'] = (high + .05) / (low + .05)
            assert result['before-idle']['contrast'] < 4.5, 'baseline no longer demonstrates low contrast'
            assert result['before-metrics']['maxOverflow'] > 0, 'baseline no longer demonstrates overflow'
            assert len(set(result['before-metrics']['cpuWidths'])) > 1, 'baseline no longer demonstrates jitter'
            for state in ['idle', 'hover', 'pressed', 'focus']:
                row = result['after-' + state]
                assert row['contrast'] >= 4.5, (state, row)
                assert row['rail'] and row['accent'] == result['before-' + state]['accent']
            assert result['after-focus']['focus']
            assert len({result['after-' + state]['fill'] for state in ['idle', 'hover', 'pressed']}) == 3
            assert result['after-metrics']['maxOverflow'] == 0
            widths = result['after-metrics']['cpuWidths']
            assert max(widths) - min(widths) < .02, widths
            if render:
                OUTPUT.mkdir(parents=True, exist_ok=True)
                assert view.grabWindow().save(str(OUTPUT / 'comparison.png'))
                (OUTPUT / 'measurements.json').write_text(json.dumps({
                    'environment': 'isolated Qt offscreen/software, Noto Sans 11pt, repository palette, synthetic input',
                    'results': result}, ensure_ascii=False, indent=2) + '\n')
            print('PASS: selected text contrast, hover/press/focus, 1303 metric values, stable digit transitions')
            print('Selected contrast: %.2f -> %.2f; reserved label width: %s -> %s' % (
                result['before-idle']['contrast'], result['after-idle']['contrast'],
                result['before-metrics']['reserved'], result['after-metrics']['reserved']))
            outcome.append(0)
        except Exception as error:
            print('FAIL:', error, file=sys.stderr)
            outcome.append(1)
        app.quit()
    QTimer.singleShot(500, inspect)
    app.exec()
    raise SystemExit(outcome[0] if outcome else 1)


if __name__ == '__main__':
    if sys.argv[1:] in (['--isolated-child'], ['--isolated-child', '--render']):
        child('--render' in sys.argv)
    elif sys.argv[1:] in ([], ['--render']):
        with tempfile.TemporaryDirectory(prefix='kde-rice-readability-', dir='/tmp') as tmp:
            target = Path(tmp)
            for relative in ['.config', '.local/share', '.local/state', '.cache', 'runtime']:
                (target / relative).mkdir(parents=True, exist_ok=True)
            (target / 'runtime').chmod(0o700)
            (target / '.config/kdeglobals').write_bytes((ROOT / 'config/color-schemes/BlackMinimal.colors').read_bytes())
            env = {'PATH': os.environ.get('PATH', '/usr/bin:/bin'), 'LANG': 'C.UTF-8',
                'HOME': tmp, 'XDG_CONFIG_HOME': tmp+'/.config', 'XDG_DATA_HOME': tmp+'/.local/share',
                'XDG_STATE_HOME': tmp+'/.local/state', 'XDG_CACHE_HOME': tmp+'/.cache',
                'XDG_RUNTIME_DIR': tmp+'/runtime', 'DBUS_SESSION_BUS_ADDRESS': 'unix:path='+tmp+'/no-session-bus',
                'QT_QPA_PLATFORM': 'offscreen', 'QT_QUICK_BACKEND': 'software', 'QT_SCALE_FACTOR': '1',
                'QML_DISABLE_DISK_CACHE': '1'}
            try:
                result = subprocess.run([sys.executable, str(Path(__file__).resolve()), '--isolated-child', *sys.argv[1:]], env=env, timeout=60)
            except subprocess.TimeoutExpired:
                raise SystemExit('FAIL: readability test timed out')
            # Preserve 77 so automation can distinguish unperformed checks
            # from regressions. Native crashes still count as failures.
            raise SystemExit(result.returncode if result.returncode >= 0 else 1)
    else:
        raise SystemExit('Usage: python3 tests/test-panel-readability.py [--render]')
