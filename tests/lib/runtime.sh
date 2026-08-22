#!/usr/bin/env bash

require_test_node() {
    local candidate
    local resolved

    if [[ -n ${KDE_RICE_TEST_NODE:-} ]]; then
        candidate=$KDE_RICE_TEST_NODE
        [[ $candidate == /* && -f $candidate && -x $candidate ]] || {
            printf 'FAIL: KDE_RICE_TEST_NODE must name an executable absolute path\n' >&2
            exit 1
        }
        NODE_BIN=$(realpath -e -- "$candidate") || exit 1
        return 0
    fi

    for candidate in node nodejs; do
        resolved=$(command -v -- "$candidate" 2>/dev/null) || continue
        [[ -x $resolved ]] || continue
        NODE_BIN=$(realpath -e -- "$resolved") || exit 1
        return 0
    done

    printf 'FAIL: Node.js is required only for the repository JavaScript test harness; set KDE_RICE_TEST_NODE or install a test runtime\n' >&2
    exit 1
}

require_test_qmllint() {
    local candidate
    local qtpaths_bin
    local reported
    local resolved

    QMLLINT_BIN=
    QML_IMPORT_ROOT=

    if [[ -n ${KDE_RICE_TEST_QMLLINT:-} ]]; then
        candidate=$KDE_RICE_TEST_QMLLINT
        [[ $candidate == /* && -f $candidate && -x $candidate ]] || {
            printf 'FAIL: KDE_RICE_TEST_QMLLINT must name an executable absolute path\n' >&2
            exit 1
        }
        QMLLINT_BIN=$(realpath -e -- "$candidate") || exit 1
    else
        for candidate in qmllint qmllint-qt6 qmllint6; do
            resolved=$(command -v -- "$candidate" 2>/dev/null) || continue
            [[ -f $resolved && -x $resolved ]] || continue
            QMLLINT_BIN=$(realpath -e -- "$resolved") || exit 1
            break
        done
    fi

    [[ -n $QMLLINT_BIN ]] || {
        printf 'FAIL: Qt 6 qmllint is required for the repository QML release gate; set KDE_RICE_TEST_QMLLINT or install a test runtime\n' >&2
        exit 1
    }

    if [[ -n ${KDE_RICE_TEST_QML_IMPORT_PATH:-} ]]; then
        candidate=$KDE_RICE_TEST_QML_IMPORT_PATH
        [[ $candidate == /* && -d $candidate ]] || {
            printf 'FAIL: KDE_RICE_TEST_QML_IMPORT_PATH must name an existing absolute directory\n' >&2
            exit 1
        }
        QML_IMPORT_ROOT=$(realpath -e -- "$candidate") || exit 1
        return 0
    fi

    resolved=$(command -v -- qtpaths6 2>/dev/null) || resolved=
    if [[ -n $resolved && -f $resolved && -x $resolved ]]; then
        qtpaths_bin=$(realpath -e -- "$resolved") || exit 1
        reported=$("$qtpaths_bin" --query QT_INSTALL_QML 2>/dev/null) || reported=
        if [[ $reported == /* && -d $reported ]]; then
            QML_IMPORT_ROOT=$(realpath -e -- "$reported") || exit 1
            return 0
        fi
    fi

    for candidate in /usr/lib64/qt6/qml /usr/lib/qt6/qml; do
        [[ -d $candidate ]] || continue
        QML_IMPORT_ROOT=$(realpath -e -- "$candidate") || exit 1
        return 0
    done

    printf 'FAIL: the Qt 6 QML import root could not be resolved; set KDE_RICE_TEST_QML_IMPORT_PATH\n' >&2
    exit 1
}
