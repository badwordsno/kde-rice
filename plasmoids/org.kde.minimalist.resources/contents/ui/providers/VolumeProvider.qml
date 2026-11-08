// SPDX-License-Identifier: MIT

pragma ComponentBehavior: Bound

import QtQuick
// The module registers these singletons dynamically but omits them from its
// qmltypes file. Keep the private dependency isolated in this Loader target.
import org.kde.plasma.private.volume // qmllint disable unused-imports

QtObject {
    id: root

    readonly property var sink: PreferredDevice.sink // qmllint disable unqualified
    readonly property bool contextReady: Context.state === Context.State.Ready // qmllint disable unqualified
    readonly property real normalVolume: Number(PulseAudio.NormalVolume) // qmllint disable unqualified
    readonly property bool available: contextReady
        && sink !== null
        && sink !== undefined
        && sink.name !== "auto_null"
    readonly property bool muted: available && Boolean(sink.muted)
    readonly property real volume: available ? Number(sink.volume) : 0
}
