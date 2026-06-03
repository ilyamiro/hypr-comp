import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland


PanelWindow {
    id: root

    WlrLayershell.namespace: "stars-bg"
    WlrLayershell.layer: WlrLayer.Bottom   

    focusable: false
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}                        
    color: "transparent"

    // Cover the entire current screen
    implicitWidth: root.screen.width
    implicitHeight: root.screen.height

    Item {
        anchors.fill: parent

        Repeater {
            model: 800  

            Rectangle {
                id: starCore

                width: 2.0 + Math.random() * 4
                height: width
                radius: width / 2

                color: Qt.rgba(0.95 + Math.random() * 0.05,
                               0.9  + Math.random() * 0.1,
                               0.8  + Math.random() * 0.2,
                               1.0)

                opacity: 0

                x: Math.random() * root.screen.width
                y: Math.random() * root.screen.height

                layer.enabled: true
                layer.effect: MultiEffect {
                    autoPaddingEnabled: true
                    shadowEnabled: true
                    shadowColor: starCore.color
                    shadowBlur: 2.0 + Math.random() * 4.0   // each star has its own blur size
                    shadowOpacity: starCore.opacity * 0.8    // glow fades with the star
                }

                Timer {
                    id: blinkTimer
                    repeat: true
                    running: false

                    onTriggered: {
                        starCore.opacity = 0.05 + Math.random() * 0.95
                    }
                }

                Component.onCompleted: {
                    blinkTimer.interval = 400 + Math.random() * 3000
                    // Start with a random opacity so the sky doesn't “snap” on
                    starCore.opacity = 0.05 + Math.random() * 0.95
                    blinkTimer.running = true
                }
            }
        }
    }
}

