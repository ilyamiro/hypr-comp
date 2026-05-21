import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: window
    focus: true

    implicitWidth: Screen.width
    implicitHeight: Screen.height

    Caching { id: paths }

    Scaler {
        id: scaler
        currentWidth: window.width
    }

    function s(val) {
        let res = scaler.s(val);
        return res > 0 ? res : val;
    }

    MatugenColors { id: _theme }

    readonly property color base:      _theme.base
    readonly property color mantle:   _theme.mantle    || _theme.base
    readonly property color crust:    _theme.crust
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2
    readonly property color text:     _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color blue:      _theme.blue      || "#89b4fa"
    readonly property color mauve:     _theme.mauve     || "#cba6f7"
    readonly property color teal:      _theme.teal      || "#94e2d5"
    readonly property color overlay0: _theme.overlay0 || "#6c7086"
    readonly property color peach:    _theme.peach     || "#fab387"
    readonly property color yellow:   _theme.yellow    || "#f9e2af"
    readonly property color sapphire: _theme.sapphire || "#74c7ec"

    property real baseSphereRadius: window.s(368) 
    property real sphereZoom: 1.0
    Behavior on sphereZoom { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
    
    property real sphereRadius: baseSphereRadius

    property real rotX: -0.2
    property real rotY: 0

    NumberAnimation { id: searchRotXAnim; target: window; property: "rotX"; duration: 700; easing.type: Easing.OutCubic }
    NumberAnimation { id: searchRotYAnim; target: window; property: "rotY"; duration: 700; easing.type: Easing.OutCubic }

    Timer {
        interval: 16
        running: !sceneMouse.pressed && !searchRotXAnim.running && !searchRotYAnim.running
        repeat: true
        onTriggered: window.rotY -= 0.002
    }

    function project3D(bx, by, bz) {
        let rx = window.rotX;
        let ry = window.rotY;

        let y1 = by * Math.cos(rx) - bz * Math.sin(rx);
        let z1 = by * Math.sin(rx) + bz * Math.cos(rx);

        let x2 = bx * Math.cos(ry) + z1 * Math.sin(ry);
        let z2 = -bx * Math.sin(ry) + z1 * Math.cos(ry);

        return { x: x2, y: y1, z: z2 };
    }

    function centerOnApp(index) {
        if (index < 0 || index >= appModel.count) return;

        let phi = Math.PI * (3 - Math.sqrt(5));
        let total = appModel.count;
        let b_y = 1.0 - (index / Math.max(1, total - 1)) * 2.0;
        let b_radius = Math.sqrt(1.0 - b_y * b_y);
        let b_theta = phi * index;
        let b_x = Math.cos(b_theta) * b_radius;
        let b_z = Math.sin(b_theta) * b_radius;

        let targetRotX = Math.atan2(b_y, b_z);
        let z1 = Math.sqrt(b_y * b_y + b_z * b_z);
        let targetRotY = Math.atan2(-b_x, z1);

        let currentRotYMod = ((window.rotY % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2);
        let targetRotYNorm = ((targetRotY % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2);
        
        let diff = targetRotYNorm - currentRotYMod;
        if (diff > Math.PI) diff -= Math.PI * 2;
        if (diff < -Math.PI) diff += Math.PI * 2;

        searchRotXAnim.to = Math.max(-1.45, Math.min(1.45, targetRotX));
        searchRotYAnim.to = window.rotY + diff;

        searchRotXAnim.restart();
        searchRotYAnim.restart();
    }

    property real introPhase: 0.0
    NumberAnimation on introPhase {
        id: introPhaseAnim
        from: 0.0; to: 1.0; duration: 800; easing.type: Easing.OutExpo; running: true
    }

    Connections {
        target: window
        function onVisibleChanged() {
            if (window.visible) {
                searchInput.text = "";
                window.searchQuery = "";
                window.selectedAppIndex = -1;
                window.sphereZoom = 1.0;
                searchInput.forceActiveFocus();
                introPhaseAnim.restart();
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: closeSequence.start()
    }

    SequentialAnimation {
        id: closeSequence
        NumberAnimation { target: window; property: "introPhase"; to: 0.0; duration: 400; easing.type: Easing.OutQuint }
        ScriptAction { script: Quickshell.execDetached(["bash", paths.serpantinumDir + "/scripts/qs_manager.sh", "close"]) }
    }

    property var allApps: []
    property string searchQuery: ""
    property int selectedAppIndex: -1

    property string selectedAppName: ""
    property string selectedAppIcon: ""
    property string selectedAppExec: ""

    Process {
        id: appFetcher
        running: true
        command: ["bash", "-c", "python3 " + paths.qsDir + "/applauncher/app_fetcher.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (this.text && this.text.trim().length > 0) {
                        window.allApps = JSON.parse(this.text);
                        appModel.clear();
                        for (let i = 0; i < window.allApps.length; i++) {
                            appModel.append(window.allApps[i]);
                        }
                    }
                } catch(e) { console.log(e); }
            }
        }
    }

    ListModel { id: appModel }

    function handleSearch(query) {
        window.searchQuery = query.toLowerCase();
        if (window.searchQuery === "") {
            window.selectedAppIndex = -1;
            window.selectedAppName = "";
            window.selectedAppIcon = "";
            window.selectedAppExec = "";
            window.sphereZoom = 1.0;
            return;
        }
        let found = false;
        for (let i = 0; i < appModel.count; i++) {
            if (appModel.get(i).name.toLowerCase().includes(window.searchQuery)) {
                window.selectedAppIndex = i;
                window.selectedAppName = appModel.get(i).name;
                window.selectedAppIcon = appModel.get(i).icon || "";
                window.selectedAppExec = appModel.get(i).exec || "";
                centerOnApp(i);
                window.sphereZoom = 1.65; 
                found = true;
                break;
            }
        }
        if (!found) {
            window.selectedAppIndex = -1;
            window.sphereZoom = 1.0;
        }
    }

    function launchApp(appName, execStr) {
        Quickshell.execDetached(["python3", paths.qsDir + "/applauncher/app_fetcher.py", "--log", appName]);
        Quickshell.execDetached(["hyprctl", "dispatch", "exec", "--", execStr]);
        closeSequence.start();
    }

    Item {
        anchors.fill: parent
        opacity: window.introPhase

        Repeater {
            model: 50
            Rectangle {
                property real seed: Math.random()
                x: seed * window.width
                y: Math.random() * window.height
                width: window.s(2) + Math.random() * window.s(2)
                height: width
                radius: width / 2
                color: window.text
                opacity: 0.08 + Math.random() * 0.12
            }
        }
    }

    Item {
        id: scene3D
        anchors.fill: parent
        opacity: window.introPhase
        scale: 0.8 + (0.2 * window.introPhase)

        MouseArea {
            id: sceneMouse
            anchors.fill: parent
            property real lastX: 0
            property real lastY: 0
            onPressed: mouse => {
                searchRotXAnim.stop();
                searchRotYAnim.stop();
                lastX = mouse.x;
                lastY = mouse.y;
            }
            onPositionChanged: mouse => {
                if (!pressed) return;
                let dx = mouse.x - lastX;
                let dy = mouse.y - lastY;
                window.rotY += dx * 0.005;
                
                let newRotX = window.rotX - dy * 0.005;
                window.rotX = Math.max(-1.45, Math.min(1.45, newRotX));
                
                lastX = mouse.x;
                lastY = mouse.y;
            }
            onClicked: searchInput.forceActiveFocus()
        }

        Item {
            id: origin
            anchors.centerIn: parent
            width:  window.baseSphereRadius * 2
            height: window.baseSphereRadius * 2

            Rectangle {
                id: moonBase
                anchors.centerIn: parent
                width: window.s(310.5) * 2 
                height: window.s(310.5) * 2
                radius: width / 2
                z: 0
                color: "#111"

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: moonBase.width
                        height: moonBase.height
                        radius: width / 2
                    }
                }

                Item {
                    anchors.fill: parent

                    Image {
                        id: moonTexture
                        width: parent.width * 2
                        height: parent.height * 2
                        x: {
                            let norm = ((window.rotY % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2)
                            return (norm / (Math.PI * 2)) * parent.width
                        }
                        y: {
                            let t = window.rotX / (Math.PI * 0.5)
                            t = Math.max(-1, Math.min(1, t))
                            return -parent.height * 0.25 - t * parent.height * 0.25
                        }
                        source: "file:///home/ilyamiro/Downloads/moon.jpg"
                        fillMode: Image.Stretch
                        smooth: true
                        asynchronous: true
                    }

                    Image {
                        width: parent.width * 2
                        height: parent.height * 2
                        x: moonTexture.x - moonTexture.width
                        y: moonTexture.y
                        source: "file:///home/ilyamiro/Downloads/moon.jpg"
                        fillMode: Image.Stretch
                        smooth: true
                        asynchronous: true
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    z: 1
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.50) }
                        GradientStop { position: 0.18; color: "transparent" }
                        GradientStop { position: 0.82; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    z: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.55) }
                        GradientStop { position: 0.18; color: "transparent" }
                        GradientStop { position: 0.82; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    rotation: -25
                    z: 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.60; color: Qt.rgba(window.mantle.r, window.mantle.g, window.mantle.b, 0.25) }
                        GradientStop { position: 1.0;  color: Qt.rgba(window.crust.r,  window.crust.g,  window.crust.b,  0.70) }
                    }
                }
            }

            Repeater {
                id: appRepeater
                model: appModel

                delegate: Item {
                    id: appNode

                    property real phi: Math.PI * (3 - Math.sqrt(5))
                    property int totalApps: Math.max(1, appRepeater.count)
                    property real b_y: 1.0 - (index / Math.max(1, totalApps - 1)) * 2.0
                    property real b_radius: Math.sqrt(1.0 - b_y * b_y)
                    property real b_theta: phi * index

                    property real b_x: Math.cos(b_theta) * b_radius
                    property real b_z: Math.sin(b_theta) * b_radius

                    property var proj: window.project3D(b_x, b_y, b_z)

                    property real zoomFactor: 1.0 + (window.sphereZoom - 1.0) * 0.45
                    
                    x: (origin.width / 2)  + (proj.x * window.sphereRadius * zoomFactor) - width/2
                    y: (origin.height / 2) + (proj.y * window.sphereRadius * zoomFactor) - height/2

                    z: Math.round(proj.z * 1000)
                    property real depthFactor: (proj.z + 1) / 2

                    property bool isMatch: window.searchQuery === "" || model.name.toLowerCase().includes(window.searchQuery)
                    property bool isSelected: index === window.selectedAppIndex

                    property real horizonFade: Math.max(0.0, Math.min(1.0, proj.z * 4.0))
                    property real targetOpacity: proj.z > 0.0 ? (isMatch ? horizonFade : horizonFade * 0.15) : 0.0
                    
                    opacity: targetOpacity
                    Behavior on opacity {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }

                    visible: opacity > 0.01

                    property real hoverScale: (nodeMa.containsMouse && !isSelected) ? 1.12 : 1.0
                    
                    property real targetScale: isSelected ? 1.0 : (0.78 + (Math.max(0.0, proj.z) * 0.22)) * hoverScale
                    scale: targetScale
                    Behavior on scale {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }

                    property real xNorm: proj.x / (window.sphereRadius / window.s(310.5))
                    property real yNorm: proj.y / (window.sphereRadius / window.s(310.5))

                    transform: [
                        Rotation {
                            axis { x: 1; y: 0; z: 0 }
                            angle: isSelected ? 0 : -appNode.yNorm * 45
                            origin.x: appNode.width / 2
                            origin.y: appNode.height / 2
                        },
                        Rotation {
                            axis { x: 0; y: 1; z: 0 }
                            angle: isSelected ? 0 : appNode.xNorm * 35
                            origin.x: appNode.width / 2
                            origin.y: appNode.height / 2
                        }
                    ]

                    width:  window.s(74)
                    height: window.s(104)

                    Rectangle {
                        anchors.fill: parent
                        radius: window.s(12) 
                        color: "transparent"
                        border.color: nodeMa.containsMouse && !appNode.isSelected ? window.surface2 : "transparent"
                        border.width: window.s(2)
                        Behavior on color { ColorAnimation { duration: 200 } }
                        
                        opacity: appNode.isSelected ? 0.0 : 1.0

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: window.s(5) 
                            spacing: window.s(5)

                            Image {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth:  window.s(55) 
                                Layout.preferredHeight: window.s(55)
                                source: model.icon
                                    ? (model.icon.startsWith("/") ? "file://" + model.icon : "image://icon/" + model.icon)
                                    : "image://icon/application-x-executable"
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: labelText.implicitHeight + window.s(4)
                                radius: window.s(4)
                                color: Qt.rgba(window.crust.r, window.crust.g, window.crust.b, 0.60)

                                Text {
                                    id: labelText
                                    anchors.fill: parent
                                    anchors.leftMargin:  window.s(3)
                                    anchors.rightMargin: window.s(3)
                                    text: model.name
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: window.s(11) 
                                    font.weight: Font.DemiBold
                                    color: window.text
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment:   Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    Item {
                        id: miniSat
                        anchors.centerIn: parent
                        opacity: appNode.isSelected ? 1.0 : 0.0
                        
                        scale: appNode.isSelected ? 2.5 : 0.4
                        
                        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 450; easing.type: Easing.OutBack } }
                        visible: opacity > 0.01

                        property real ss: window.s(0.54)

                        property real msHullW:    110 * ss
                        property real msHullH:     68 * ss
                        property real msPanelW:    32 * ss
                        property real msPanelH:    26 * ss
                        property real msStrutW:     6 * ss
                        property real msStrutH:     3 * ss
                        property real msAntennaH:    9 * ss
                        property real msThrusterH:  6 * ss

                        width:  msPanelW + msStrutW + msHullW + msStrutW + msPanelW
                        height: msHullH + msAntennaH + msThrusterH + window.s(4)

                        Item {
                            id: satelliteFloatingHull
                            anchors.fill: parent
                            
                            SequentialAnimation on y {
                                loops: Animation.Infinite
                                running: appNode.isSelected
                                NumberAnimation { from: -window.s(3); to: window.s(3); duration: 2000; easing.type: Easing.InOutSine }
                                NumberAnimation { from: window.s(3);  to: -window.s(3); duration: 2000; easing.type: Easing.InOutSine }
                            }

                            Rectangle {
                                id: msLPanel
                                width: miniSat.msPanelW; height: miniSat.msPanelH
                                anchors.right: msLStrut.left
                                anchors.verticalCenter: msHull.verticalCenter
                                color:  Qt.darker(window.base, 1.35)
                                border.color: Qt.alpha(window.blue, 0.50); border.width: 1
                                radius: 3
                                Grid {
                                    anchors.fill: parent; anchors.margins: 3*miniSat.ss
                                    columns: 3; rows: 3; spacing: 1.5*miniSat.ss
                                    Repeater { model: 9
                                        Rectangle {
                                            width:  (msLPanel.width  - 6*miniSat.ss - 2*1.5*miniSat.ss) / 3
                                            height: (msLPanel.height - 6*miniSat.ss - 2*1.5*miniSat.ss) / 3
                                            color: Qt.darker(index%2===0 ? window.surface0 : window.surface1, 1.45)
                                            border.color: Qt.alpha(window.overlay0, 0.35); border.width: 0.7; radius: 1
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: msLStrut
                                width: miniSat.msStrutW; height: miniSat.msStrutH
                                anchors.right: msHull.left
                                anchors.verticalCenter: msHull.verticalCenter
                                color: Qt.alpha(window.blue, 0.60)
                            }

                            Rectangle {
                                id: msHull
                                width: miniSat.msHullW; height: miniSat.msHullH
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: (miniSat.msAntennaH - miniSat.msThrusterH) * 0.5
                                color: Qt.darker(window.base, 1.55)
                                border.color: Qt.alpha(window.mauve, 0.55); border.width: 1.5
                                radius: 6 * miniSat.ss

                                Rectangle {
                                    width: 2*miniSat.ss; height: miniSat.msAntennaH
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.horizontalCenterOffset: -8*miniSat.ss
                                    anchors.bottom: parent.top; anchors.bottomMargin: -1
                                    color: Qt.alpha(window.blue, 0.70); radius: 1
                                    Rectangle {
                                        width: 6*miniSat.ss; height: 4*miniSat.ss; radius: width/2
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.top; anchors.bottomMargin: -1
                                        color: window.yellow
                                        SequentialAnimation on opacity { loops: Animation.Infinite; running: appNode.isSelected
                                            PauseAnimation { duration: 1700 }
                                            NumberAnimation { from: 1.0; to: 0.05; duration: 85 }
                                            NumberAnimation { from: 0.05; to: 1.0; duration: 85 }
                                        }
                                    }
                                }

                                Rectangle {
                                    id: msScreen
                                    anchors.fill: parent
                                    anchors.margins: 5 * miniSat.ss
                                    color: Qt.darker(window.base, 1.95)
                                    radius: 4 * miniSat.ss
                                    border.color: Qt.alpha(window.surface1, 0.75); border.width: 1
                                    clip: true

                                    Repeater { model: 8
                                        Rectangle {
                                            y: index * (msScreen.height / 8)
                                            width: msScreen.width; height: 0.5
                                            color: Qt.alpha(window.text, 0.025)
                                        }
                                    }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 3 * miniSat.ss

                                        Image {
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.preferredWidth:  28 * miniSat.ss
                                            Layout.preferredHeight: 28 * miniSat.ss
                                            source: window.selectedAppIcon
                                                ? (window.selectedAppIcon.startsWith("/")
                                                   ? "file://" + window.selectedAppIcon
                                                   : "image://icon/" + window.selectedAppIcon)
                                                : "image://icon/application-x-executable"
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.preferredWidth: msScreen.width - 8*miniSat.ss
                                            text: window.selectedAppName
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: 7 * miniSat.ss
                                            font.weight: Font.Bold
                                            color: window.mauve
                                            horizontalAlignment: Text.AlignHCenter
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Rectangle {
                                        width: 4*miniSat.ss; height: 4*miniSat.ss; radius: width/2
                                        anchors.fill: parent
                                        anchors { top: parent.top; right: parent.right; margins: 4*miniSat.ss }
                                        color: window.yellow
                                        SequentialAnimation on opacity { loops: Animation.Infinite; running: appNode.isSelected
                                            NumberAnimation { from: 1.0; to: 0.10; duration: 1000; easing.type: Easing.InOutSine }
                                            NumberAnimation { from: 0.10; to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
                                        }
                                    }

                                    Row {
                                        anchors { bottom: parent.bottom; right: parent.right; margins: 3*miniSat.ss }
                                        spacing: 1.2*miniSat.ss
                                        Repeater { model: 4
                                            Rectangle {
                                                width: 2*miniSat.ss
                                                height: (2 + index*2)*miniSat.ss
                                                anchors.bottom: parent ? parent.bottom : undefined
                                                radius: 1
                                                color: index < 3 ? Qt.alpha(window.mauve, 0.82) : Qt.alpha(window.surface1, 0.45)
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 10*miniSat.ss; height: miniSat.msThrusterH * 0.55
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.horizontalCenterOffset: -12*miniSat.ss
                                    anchors.top: parent.bottom; anchors.topMargin: -1
                                    color: Qt.darker(window.base, 2.1); radius: 2

                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.top: parent.bottom
                                        width: parent.width * 0.55
                                        height: miniSat.msThrusterH * 1.2
                                        radius: width / 2
                                        color: Qt.alpha(window.sapphire, 0.72)
                                        opacity: 0.0
                                        SequentialAnimation on opacity { loops: Animation.Infinite; running: appNode.isSelected
                                            NumberAnimation { from: 0.0; to: 0.75; duration: 90 }
                                            NumberAnimation { from: 0.75; to: 0.25; duration: 60 }
                                            NumberAnimation { from: 0.25; to: 0.62; duration: 85 }
                                            NumberAnimation { from: 0.62; to: 0.0; duration: 110 }
                                            PauseAnimation { duration: 270 }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: msRStrut
                                width: miniSat.msStrutW; height: miniSat.msStrutH
                                anchors.left: msHull.right
                                anchors.verticalCenter: msHull.verticalCenter
                                color: Qt.alpha(window.blue, 0.60)
                            }

                            Rectangle {
                                id: msRPanel
                                width: miniSat.msPanelW; height: miniSat.msPanelH
                                anchors.left: msRStrut.right
                                anchors.verticalCenter: msHull.verticalCenter
                                color: Qt.darker(window.base, 1.35)
                                border.color: Qt.alpha(window.blue, 0.50); border.width: 1
                                radius: 3
                                Grid {
                                    anchors.fill: parent; anchors.margins: 3*miniSat.ss
                                    columns: 3; rows: 3; spacing: 1.5*miniSat.ss
                                    Repeater { model: 9
                                        Rectangle {
                                            width:  (msRPanel.width  - 6*miniSat.ss - 2*1.5*miniSat.ss) / 3
                                            height: (msRPanel.height - 6*miniSat.ss - 2*1.5*miniSat.ss) / 3
                                            color: Qt.darker(index%2===0 ? window.surface0 : window.surface1, 1.45)
                                            border.color: Qt.alpha(window.overlay0, 0.35); border.width: 0.7; radius: 1
                                        }
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: nodeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.launchApp(model.name, model.exec)
                    }
                }
            }
        }
    }

    Rectangle {
        id: searchContainer
        width:  window.s(518) 
        height: window.s(52) 
        anchors.bottom: parent.bottom
        anchors.bottomMargin: window.s(63) 
        anchors.horizontalCenter: parent.horizontalCenter

        radius: window.s(16) 
        color: Qt.rgba(window.mantle.r, window.mantle.g, window.mantle.b, 0.88)
        border.color: searchInput.activeFocus ? window.mauve : window.surface1
        border.width: window.s(2)

        opacity: window.introPhase
        transform: Translate { y: (1 - window.introPhase) * window.s(40) }
        Behavior on border.color { ColorAnimation { duration: 200 } }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.5
            shadowBlur: 1.0
            shadowVerticalOffset: window.s(5)
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins:      window.s(10) 
            anchors.leftMargin:   window.s(15)
            anchors.rightMargin:  window.s(15)
            spacing: window.s(10)

            Text {
                text: ""
                font.family: "Iosevka Nerd Font"
                font.pixelSize: window.s(15)
                color: searchInput.activeFocus ? window.mauve : window.subtext0
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            TextField {
                id: searchInput
                Layout.fillWidth: true
                Layout.fillHeight: true
                background: Item {}
                color: window.text
                font.family: "JetBrains Mono"
                font.pixelSize: window.s(14)

                placeholderText: "Search"
                placeholderTextColor: window.overlay0
                verticalAlignment: TextInput.AlignVCenter

                onTextChanged: window.handleSearch(text)

                Keys.onDownPressed: {
                    for (let i = window.selectedAppIndex + 1; i < appModel.count; i++) {
                        if (appModel.get(i).name.toLowerCase().includes(window.searchQuery)) {
                            window.selectedAppIndex = i;
                            window.selectedAppName = appModel.get(i).name;
                            window.selectedAppIcon = appModel.get(i).icon || "";
                            window.selectedAppExec = appModel.get(i).exec || "";
                            window.centerOnApp(i);
                            window.sphereZoom = 1.65;
                            break;
                        }
                    }
                    event.accepted = true;
                }
                Keys.onUpPressed: {
                    for (let i = window.selectedAppIndex - 1; i >= 0; i--) {
                        if (appModel.get(i).name.toLowerCase().includes(window.searchQuery)) {
                            window.selectedAppIndex = i;
                            window.selectedAppName = appModel.get(i).name;
                            window.selectedAppIcon = appModel.get(i).icon || "";
                            window.selectedAppExec = appModel.get(i).exec || "";
                            window.centerOnApp(i);
                            window.sphereZoom = 1.65;
                            break;
                        }
                    }
                    event.accepted = true;
                }
                Keys.onReturnPressed: {
                    if (window.selectedAppIndex >= 0 && window.selectedAppIndex < appModel.count) {
                        window.launchApp(
                            appModel.get(window.selectedAppIndex).name,
                            appModel.get(window.selectedAppIndex).exec
                        );
                    }
                    event.accepted = true;
                }
                Keys.onEscapePressed: {
                    closeSequence.start();
                    event.accepted = true;
                }
            }
        }
    }
}
