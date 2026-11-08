                    Chimera.ChimeraFrame {
                        anchors.fill: parent

                        tokens: tokens
                        active: desktopButton.current
                        hovered: desktopMouseArea.containsMouse
                        pressed: desktopMouseArea.pressed
                        focused: desktopMouseArea.activeFocus
                        stateRailInset: Math.max(tokens.space2,
                            Math.floor((root.configuredButtonWidth
                                - tokens.space4) / 2))
                        fillColor: tokens.flatSurface
                            ? pressed ? tokens.surfaceSunken
                                : hovered ? tokens.surfaceHovered : "transparent"
                            : desktopButton.current
                            ? Qt.tint(tokens.surfaceRaised,
                                Qt.rgba(tokens.accent.r, tokens.accent.g,
                                    tokens.accent.b, 0.2))
                            : pressed ? tokens.surfaceSunken
                                : hovered ? tokens.surfaceHovered
                                    : tokens.surfaceRaised

                        PlasmaComponents.Label {
                            anchors.fill: parent

                            text: root.desktopLabel(desktopButton.index)
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            maximumLineCount: 1
                            font.family: "Noto Sans"
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            color: desktopButton.current
                                ? tokens.accent : tokens.textColor
                        }
                    }
