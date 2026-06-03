import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray

PanelWindow {
    id: root

    Caching { id: paths }

    WlrLayershell.namespace: "workspace-satellite-bg"
    WlrLayershell.layer: WlrLayer.Bottom

    focusable: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    implicitWidth: root.screen.width
    implicitHeight: root.screen.height

    mask: Region {
        Region {
            x: Math.round((root.width - worldCenter.width * 2) / 2)
            y: Math.round((root.height - worldCenter.height * 2) / 2)
            width: Math.round(worldCenter.width * 2)
            height: Math.round(worldCenter.height * 2)
        }
        Region {
            x: 0
            y: Math.round(root.height * 0.2)
            width: root.width
            height: Math.round(root.height * 0.8)
        }
    }

    MatugenColors { id: mocha }

    readonly property color base:       mocha.base
    readonly property color mantle:     mocha.mantle      || mocha.base
    readonly property color crust:      mocha.crust
    readonly property color text:       mocha.text
    readonly property color subtext0:   mocha.subtext0
    readonly property color overlay0:   mocha.overlay0    || "#6c7086"
    readonly property color surface0:   mocha.surface0
    readonly property color surface1:   mocha.surface1
    readonly property color surface2:   mocha.surface2
    readonly property color blue:       mocha.blue        || "#89b4fa"
    readonly property color mauve:      mocha.mauve       || "#cba6f7"
    readonly property color teal:       mocha.teal        || "#94e2d5"
    readonly property color peach:      mocha.peach       || "#fab387"
    readonly property color green:      mocha.green       || "#a6e3a1"
    readonly property color red:        mocha.red         || "#f38ba8"
    readonly property color yellow:     mocha.yellow      || "#f9e2af"
    readonly property color sapphire:   mocha.sapphire    || "#74c7ec"

    property string timeStr: ""
    property string fullDateStr: ""
    property string weatherIcon: ""
    property string weatherTemp: "--°"
    property string weatherHex: mocha.yellow

    property bool weatherRingsActive: false
    property var detailedWeatherData: null

    property real independentCometAngle: 0
    property real earthAutoRotation: 0

    property real baseSphereRadius: 260
    property real zoomFactor: 1.0

    property real sphereRadius: baseSphereRadius * zoomFactor 
    readonly property real satelliteZoom: zoomFactor 
    readonly property real earthZoom:      Math.pow(zoomFactor, 1.25)
    readonly property real earthZOffset:  -5.0 + (zoomFactor - 1.0) * 0.4
    property real earthSphereRadius: 1150 * root.earthZoom

    // Interpolated values for smooth dragging
    property real targetRotX: -0.2
    property real targetRotY: 0
    property real targetCamX: 0.0
    property real targetCamY: 0.0

    property real rotX: -0.2
    property real rotY: 0
    property real camX: 0.0
    property real camY: 0.0

    readonly property real cosRx: Math.cos(root.rotX)
    readonly property real sinRx: Math.sin(root.rotX)
    readonly property real cosRy: Math.cos(root.rotY)
    readonly property real sinRy: Math.sin(root.rotY)

    readonly property real cosCx: Math.cos(root.camX)
    readonly property real sinCx: Math.sin(root.camX)
    readonly property real cosCy: Math.cos(root.camY)
    readonly property real sinCy: Math.sin(root.camY)

    property real sunValueX: 1.0
    property real sunValueY: 0.0
    readonly property real screenSunAngleDeg: Math.atan2(sunValueY, sunValueX) * 180 / Math.PI

    Behavior on zoomFactor { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

    Shortcut {
        sequence: "Escape"
        enabled: root.weatherRingsActive
        onActivated: root.weatherRingsActive = false
    }

    Process {
        id: weatherPoller
        command: [
            "bash", "-c",
            "echo \"$(" + paths.serpantinumDir + "/scripts/weather.sh --current-icon)\"\n" +
            "echo \"$(" + paths.serpantinumDir + "/scripts/weather.sh --current-temp)\"\n" +
            "echo \"$(" + paths.serpantinumDir + "/scripts/weather.sh --current-hex)\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n");
                if (lines.length >= 3) {
                    root.weatherIcon = lines[0];
                    root.weatherTemp = lines[1];
                    root.weatherHex  = lines[2] || mocha.yellow;
                }
            }
        }
    }

    Process {
        id: detailedWeatherPoller
        command: ["bash", paths.serpantinumDir + "/scripts/weather.sh", "--json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "") {
                    try { root.detailedWeatherData = JSON.parse(txt); } catch(e) {}
                }
            }
        }
    }

    Timer {
        interval: 150000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            weatherPoller.running = false; weatherPoller.running = true;
            detailedWeatherPoller.running = false; detailedWeatherPoller.running = true;
        }
    }

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            let d = new Date();
            root.timeStr    = Qt.formatDateTime(d, "HH:mm:ss");
            root.fullDateStr = Qt.formatDateTime(d, "dddd, MMMM dd");
        }
    }

    property string kbLayout:   "us"
    property string wifiStatus: "Off"
    property string wifiIcon:   "󰤮"
    property string wifiSsid:   ""
    property string btStatus:   "Off"
    property string btIcon:     "󰂲"
    property string btDevice:   ""
    property string volPercent: "0%"
    property string volIcon:    "󰕾"
    property bool   isMuted:    false
    property string batPercent: "100%"
    property string batIcon:    "󰁹"
    property string batStatus:  "Unknown"
    property bool   isDesktop:  false
    property string ethStatus:  "Ethernet"

    property bool isWifiOn:     wifiStatus.toLowerCase() === "enabled" || wifiStatus.toLowerCase() === "on"
    property bool isBtOn:       btStatus.toLowerCase()   === "enabled" || btStatus.toLowerCase()   === "on"
    property bool showEthernet: ethStatus === "Connected" || (isDesktop && !isWifiOn)
    property bool isSoundActive: !isMuted && parseInt(volPercent) > 0
    property int   batCap:       parseInt(batPercent) || 0
    property bool isCharging:   batStatus === "Charging" || batStatus === "Full"
    property color batColor: {
        if (isCharging) return mocha.green;
        if (batCap <= 20) return mocha.red;
        return mocha.text;
    }

    Process {
        id: kbPoller; running: true
        command: ["bash", "-c", paths.qsDir + "/watchers/kb_fetch.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                let t = this.text.trim();
                if (t !== "") root.kbLayout = t;
                kbWaiter.running = false; kbWaiter.running = true;
            }
        }
    }
    Process { id: kbWaiter; command: ["bash", "-c", paths.qsDir + "/watchers/kb_wait.sh"]; onExited: { kbPoller.running = false; kbPoller.running = true; } }

    Process {
        id: audioPoller; running: true
        command: ["bash", "-c", paths.qsDir + "/watchers/audio_fetch.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                let t = this.text.trim();
                if (t !== "") {
                    try {
                        let d = JSON.parse(t);
                        root.volPercent = d.volume.toString() + "%";
                        root.volIcon    = d.icon;
                        root.isMuted    = (d.is_muted === "true");
                    } catch(e) {}
                }
                audioWaiter.running = false; audioWaiter.running = true;
            }
        }
    }
    Process { id: audioWaiter; command: ["bash", "-c", paths.qsDir + "/watchers/audio_wait.sh"]; onExited: { audioPoller.running = false; audioPoller.running = true; } }

    Process {
        id: networkPoller; running: true
        command: ["bash", "-c", paths.qsDir + "/watchers/network_fetch.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                let t = this.text.trim();
                if (t !== "") {
                    try {
                        let d = JSON.parse(t);
                        root.wifiStatus = d.status;
                        root.wifiIcon   = d.icon;
                        root.wifiSsid   = d.ssid;
                        root.ethStatus  = d.eth_status;
                    } catch(e) {}
                }
                networkWaiter.running = false; networkWaiter.running = true;
            }
        }
    }
    Process { id: networkWaiter; command: ["bash", "-c", paths.qsDir + "/watchers/network_wait.sh"]; onExited: { networkPoller.running = false; networkPoller.running = true; } }

    Process {
        id: btPoller; running: true
        command: ["bash", "-c", paths.qsDir + "/watchers/bt_fetch.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                let t = this.text.trim();
                if (t !== "") {
                    try {
                        let d = JSON.parse(t);
                        root.btStatus = d.status;
                        root.btIcon   = d.icon;
                        root.btDevice = d.connected;
                    } catch(e) {}
                }
                btWaiter.running = false; btWaiter.running = true;
            }
        }
    }
    Process { id: btWaiter; command: ["bash", "-c", paths.qsDir + "/watchers/bt_wait.sh"]; onExited: { btPoller.running = false; btPoller.running = true; } }

    Process {
        id: batteryPoller; running: true
        command: ["bash", "-c", paths.qsDir + "/watchers/battery_fetch.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                let t = this.text.trim();
                if (t !== "") {
                    try {
                        let d = JSON.parse(t);
                        root.batPercent = d.percent.toString() + "%";
                        root.batIcon    = d.icon;
                        root.batStatus  = d.status;
                    } catch(e) {}
                }
                batteryWaiter.running = false; batteryWaiter.running = true;
            }
        }
    }
    Process { id: batteryWaiter; command: ["bash", "-c", paths.qsDir + "/watchers/battery_wait.sh"]; onExited: { batteryPoller.running = false; batteryPoller.running = true; } }

    ListModel {
        id: workspacesModel
        property int activeIndex: 0
    }

    Process {
        id: wsDaemon
        command: ["bash", "-c", paths.serpantinumDir + "/scripts/workspaces.sh"]
        running: true
    }

    Process {
        id: wsReader
        running: true
        command: ["cat", paths.getRunDir("workspaces") + "/workspaces.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "") {
                    try {
                        let newData = JSON.parse(txt);
                        while (workspacesModel.count < newData.length)
                            workspacesModel.append({ "wsId": "", "wsState": "" });
                        while (workspacesModel.count > newData.length)
                            workspacesModel.remove(workspacesModel.count - 1);
                        let newActive = -1;
                        for (let i = 0; i < newData.length; i++) {
                            if (newData[i].state === "active") newActive = i;
                            if (workspacesModel.get(i).wsState !== newData[i].state)
                                workspacesModel.setProperty(i, "wsState", newData[i].state);
                            if (workspacesModel.get(i).wsId !== newData[i].id.toString())
                                workspacesModel.setProperty(i, "wsId", newData[i].id.toString());
                        }
                        if (newActive !== -1 && workspacesModel.activeIndex !== newActive)
                            workspacesModel.activeIndex = newActive;
                    } catch(e) {}
                }
            }
        }
    }

    Process {
        id: wsWatcher
        running: true
        command: ["bash", "-c", "inotifywait -qq -e close_write,modify " + paths.getRunDir("workspaces") + "/workspaces.json"]
        onExited: {
            wsReader.running = false; wsReader.running = true;
            running = false; running = true;
        }
    }

    property var musicData: { "status": "Stopped", "title": "", "artUrl": "", "timeStr": "" }
    property bool isMusicActive: musicData.status === "Playing" && musicData.title !== ""

    Process {
        id: musicPoller
        command: ["bash", "-c", "bash " + paths.qsDir + "/music/music_info.sh"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "") {
                    try {
                        let d = JSON.parse(txt);
                        if (d.title !== root.musicData.title ||
                            d.status !== root.musicData.status ||
                            d.timeStr !== root.musicData.timeStr) {
                            root.musicData = d;
                        }
                    } catch(e) {}
                }
            }
        }
    }
     
    Process {
        id: mprisWatcher
        running: true
        command: ["bash", "-c", "dbus-monitor --session \"type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.mpris.MediaPlayer2.Player'\" \"type='signal',interface='org.mpris.MediaPlayer2.Player',member='Seeked'\" 2>/dev/null | grep -m 1 'member=' > /dev/null || sleep 2"]
        onExited: {
            musicPoller.running = false;
            musicPoller.running = true;
            running = false;
            running = true;
        }
    }
     
    Component.onCompleted: { musicPoller.running = true; }

    property real easterEggAngle: 0
    property real gaugeAngle: Math.PI / 2
    property real telemetryAngle: 2 * Math.PI / 3
    property real sysInfoAngle: 4 * Math.PI / 3
    property real musicAngle: Math.PI
    property real trayAngle: Math.PI * 1.5

    property real gaugeBaseY: 0.15

    property real weatherRingPhaseOffset: 0      
    property real gaugeRepositionOffset: 0       

    Timer {
        id: globalEngine
        interval: 16
        running: true
        repeat: true
        onTriggered: {
            if (!sceneMouse.pressed) {
                root.targetCamY -= 0.00004; 
                root.targetRotY += 0.0003;
            }

            root.camX += (root.targetCamX - root.camX) * 0.12;
            root.camY += (root.targetCamY - root.camY) * 0.12;
            root.rotX += (root.targetRotX - root.rotX) * 0.12;
            root.rotY += (root.targetRotY - root.rotY) * 0.12;

            let now = new Date();
            let utcHrs = now.getUTCHours() + now.getUTCMinutes() / 60 + now.getUTCSeconds() / 3600;
            let dayOfYear = Math.floor((now - new Date(now.getFullYear(), 0, 0)) / 86400000);
            
            let solDecl = 23.44 * Math.sin((2 * Math.PI * (dayOfYear - 80)) / 365.25);
            let solLat = solDecl * Math.PI / 180;
            let solLong = (0.5 - utcHrs / 24) * 2 * Math.PI;

            let sX = Math.cos(solLat) * Math.sin(solLong);
            let sY = Math.sin(solLat);
            let sZ = Math.cos(solLat) * Math.cos(solLong);

            let sY_cam = sY * root.cosCx - sZ * root.sinCx;
            let sZ_pos = sY * root.sinCx + sZ * root.cosCx;
            root.sunValueX = sX * root.cosCy + sZ_pos * root.sinCy;
            root.sunValueY = sY_cam;

            root.earthAutoRotation = ((utcHrs / 24) * 2 * Math.PI - root.camY) % (Math.PI * 2);
            root.independentCometAngle = (root.independentCometAngle + 0.002) % (Math.PI * 2);

            let baseSpeed = 0.0012;
            let getFactor = (z) => {
                if (z < -0.5) return 3.0;
                if (z < 0) return 2.0;
                if (z > 1.0) return 0.3;
                if (z > 0.7) return 0.5;
                return 0.8;
            };

            let twoPi = Math.PI * 2;
            let g = gaugeSatellite.proj.z;
            let t = telemetrySatellite.proj.z,   s = sysInfoSatellite.proj.z;
            let m = musicSatellite.proj.z,       tr = traySatellite.proj.z;
            let e = easterEggSatellite.proj.z;
            
            root.gaugeAngle     = (root.gaugeAngle      + (baseSpeed * 0.4) * getFactor(g))  % twoPi;
            root.telemetryAngle = (root.telemetryAngle + baseSpeed * getFactor(t))  % twoPi;
            root.sysInfoAngle   = (root.sysInfoAngle   + baseSpeed * getFactor(s))  % twoPi;
            root.musicAngle     = (root.musicAngle      + baseSpeed * getFactor(m))  % twoPi;
            root.trayAngle      = (root.trayAngle      + baseSpeed * getFactor(tr)) % twoPi;
            root.easterEggAngle = (root.easterEggAngle + baseSpeed * getFactor(e))  % twoPi;
        }
    }

    function project3D(bx, by, bz, isSatellite) {
        let x = bx;
        let y = by;
        let z = bz;

        if (isSatellite) {
            let y1 = y * root.cosRx + z * root.sinRx;
            let z1 = -y * root.sinRx + z * root.cosRx;
            x = x * root.cosRy - z1 * root.sinRy;
            y = y1;
            z = bx * root.sinRy + z1 * root.cosRy;
        }

        let y2 = y * root.cosCx - z * root.sinCx;
        let z2 = y * root.sinCx + z * root.cosCx; 
        let x3 = x * root.cosCy + z2 * root.sinCy;
        let z3 = -x * root.sinCy + z2 * root.cosCy;

        return { x: x3, y: y2, z: z3 };
    }

    function repositionWeatherRing() {
        let satAngles = [
            root.gaugeAngle + root.gaugeRepositionOffset,   
            root.telemetryAngle,
            root.sysInfoAngle,
            root.musicAngle,
            root.trayAngle,
            root.easterEggAngle
        ];

        const numNodes = 8;
        const spacing = 2 * Math.PI / numNodes;
        let bestOffset = 0;
        let bestMinDist = -1;

        for (let i = 0; i < 200; i++) {
            let offset = (i / 200) * 2 * Math.PI;
            let minDist = Infinity;
            for (let j = 0; j < numNodes; j++) {
                let nodeAngle = (j * spacing + root.independentCometAngle + offset) % (2 * Math.PI);
                for (let k = 0; k < satAngles.length; k++) {
                    let diff = Math.abs(nodeAngle - satAngles[k]);
                    diff = Math.min(diff, 2 * Math.PI - diff);
                    if (diff < minDist) minDist = diff;
                }
            }
            if (minDist > bestMinDist) {
                bestMinDist = minDist;
                bestOffset = offset;
            }
        }

        root.weatherRingPhaseOffset = bestOffset;
    }
        
    function repositionGaugeSatellite() {
        const numNodes = 8;
        const spacing = 2 * Math.PI / numNodes;
        let nodes = [];
        for (let i = 0; i < numNodes; i++) {
            nodes.push((i * spacing + root.independentCometAngle + root.weatherRingPhaseOffset) % (2 * Math.PI));
        }
        nodes.sort((a, b) => a - b);

        let maxGap = 0;
        let gapMid = 0;
        for (let i = 0; i < nodes.length; i++) {
            let next = (i + 1) % nodes.length;
            let gap = (nodes[next] - nodes[i] + 2 * Math.PI) % (2 * Math.PI);
            if (gap > maxGap) {maxGap = gap;
                gapMid = (nodes[i] + gap / 2) % (2 * Math.PI);
            }
        }

        root.gaugeRepositionOffset = (gapMid - root.gaugeAngle + 2 * Math.PI) % (2 * Math.PI);
        root.gaugeBaseY = 0.35;   
    }   
    
    onWeatherRingsActiveChanged: {
        if (weatherRingsActive) {
            repositionWeatherRing();
            repositionGaugeSatellite();
        } else {
            gaugeBaseY = 0.15;
            gaugeRepositionOffset = 0;
        }
    }

    Rectangle {
        id: windowContent
        anchors.fill: parent
        color: "transparent"
        clip: true

        opacity: 0.0
        scale: 0.97

        Component.onCompleted: entranceAnimation.start()

        ParallelAnimation {
            id: entranceAnimation
            NumberAnimation { target: windowContent; property: "opacity"; to: 1.0; duration: 500; easing.type: Easing.OutExpo }
            NumberAnimation { target: windowContent; property: "scale";   to: 1.0; duration: 600; easing.type: Easing.OutExpo }
        }

        PinchArea {
            id: scenePinch
            anchors.fill: parent
            z: -105000
            property real pinchStartZoom: 1.0
            onPinchStarted: {
                pinchStartZoom = root.zoomFactor;
            }
            onPinchUpdated: pinch => {
                root.zoomFactor = Math.max(0.25, Math.min(3.0, pinchStartZoom * pinch.scale));
            }

            MouseArea {
                id: sceneMouse
                anchors.fill: parent
                property real lastX: 0
                property real lastY: 0

                onPressed: mouse => {
                    lastX = mouse.x;
                    lastY = mouse.y;
                }
                onPositionChanged: mouse => {
                    if (!pressed) return;
                    let dx = mouse.x - lastX;
                    let dy = mouse.y - lastY;
                
                    if (mouse.modifiers & Qt.ControlModifier) {
                        root.targetCamY -= dx * 0.0012;                
                        let newCamX = root.targetCamX + dy * 0.0012;  
                        root.targetCamX = Math.max(-1.45, Math.min(1.45, newCamX));
                    } else {
                        root.targetRotY += dx * 0.005;                
                        let newRotX = root.targetRotX - dy * 0.005;   
                        root.targetRotX = Math.max(-1.45, Math.min(1.45, newRotX));
                    }
                    lastX = mouse.x;
                    lastY = mouse.y;
                }
                onWheel: wheel => {
                    if (wheel.modifiers & Qt.ControlModifier) {
                        let zoomDelta = wheel.angleDelta.y > 0 ? 0.06 : -0.06;
                        root.zoomFactor = Math.max(0.25, Math.min(3.0, root.zoomFactor + zoomDelta));
                        wheel.accepted = true;
                    }
                }
            }
        }

        // Blended Atmosphere Rings
        Rectangle {
            width: earthBase.width + (140 * root.zoomFactor)
            height: earthBase.height + (140 * root.zoomFactor)
            radius: width / 2
            x: earthBase.x - (70 * root.zoomFactor)
            y: earthBase.y - (70 * root.zoomFactor)
            z: earthBase.z + 1
            color: "transparent"
            border.color: Qt.rgba(root.blue.r, root.blue.g, root.blue.b, 0.02)
            border.width: 70 * root.zoomFactor
        }
        Rectangle {
            width: earthBase.width + (80 * root.zoomFactor)
            height: earthBase.height + (80 * root.zoomFactor)
            radius: width / 2
            x: earthBase.x - (40 * root.zoomFactor)
            y: earthBase.y - (40 * root.zoomFactor)
            z: earthBase.z + 1
            color: "transparent"
            border.color: Qt.rgba(root.sapphire.r, root.sapphire.g, root.sapphire.b, 0.04)
            border.width: 40 * root.zoomFactor
        }
        Rectangle {
            width: earthBase.width + (30 * root.zoomFactor)
            height: earthBase.height + (30 * root.zoomFactor)
            radius: width / 2
            x: earthBase.x - (15 * root.zoomFactor)
            y: earthBase.y - (15 * root.zoomFactor)
            z: earthBase.z + 1
            color: "transparent"
            border.color: Qt.rgba(root.blue.r, root.blue.g, root.blue.b, 0.08)
            border.width: 15 * root.zoomFactor
        }
        Rectangle {
            width: earthBase.width + (10 * root.zoomFactor)
            height: earthBase.height + (10 * root.zoomFactor)
            radius: width / 2
            x: earthBase.x - (5 * root.zoomFactor)
            y: earthBase.y - (5 * root.zoomFactor)
            z: earthBase.z + 1
            color: "transparent"
            border.color: Qt.rgba(root.sapphire.r, root.sapphire.g, root.sapphire.b, 0.15)
            border.width: 5 * root.zoomFactor
        }

        Shape {
            id: orbitCurvePath
            anchors.fill: parent
            layer.enabled: true
            layer.samples: 4
            opacity: 0.35
            z: -50000 

            ShapePath {
                strokeColor: root.blue
                strokeWidth: 1.2 * root.zoomFactor
                strokeStyle: ShapePath.DashLine
                dashPattern: [6, 8]
                fillColor: "transparent"

                startX: parent.width / 2 - (380 * root.zoomFactor)
                startY: parent.height / 2 + (120 * root.zoomFactor)

                PathArc {
                    x: parent.width / 2 - (380 * root.zoomFactor)
                    y: parent.height / 2 + (120 * root.zoomFactor)
                    radiusX: 380 * root.zoomFactor
                    radiusY: 180 * root.zoomFactor
                    useLargeArc: false
                    direction: PathArc.Clockwise
                }
            }
        }

        Rectangle {
            id: earthBase
            
            property var earthProj: root.project3D(0.2, 1.2, root.earthZOffset, false)
            
            width: 2000 * root.earthZoom
            height: 2000 * root.earthZoom

            radius: width / 2
            color: "#01030a"
            
            x: (parent.width / 2) + (earthProj.x * root.baseSphereRadius) - width / 2
            y: (parent.height / 2) + (earthProj.y * root.baseSphereRadius) - height / 2
            
            z: -100000 

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: earthBase.width
                    height: earthBase.height
                    radius: width / 2
                }
            }

            Item {
                anchors.fill: parent
                Image {
                    id: earthTexture
                    width: parent.width * 2; height: parent.height * 2
                    x: {
                        let norm = (root.earthAutoRotation % (Math.PI * 2) + Math.PI * 2) % (Math.PI * 2);
                        return -((norm / (Math.PI * 2)) * parent.width * 2) % (parent.width * 2);
                    }
                    y: -parent.height * 0.25
                    source: "file:///home/ilyamiro/Downloads/earth.jpg" // change to relative path
                    fillMode: Image.Stretch; smooth: true; asynchronous: true
                }
                Image {
                    width: parent.width * 2; height: parent.height * 2
                    x: earthTexture.x + parent.width * 2
                    y: earthTexture.y
                    source: "file:///home/ilyamiro/Downloads/earth.jpg" // same here
                    fillMode: Image.Stretch; smooth: true; asynchronous: true
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                z: 1 
                scale: root.earthZoom
                spacing: 4

                Item {
                    id: weatherTriggerContainer
                    Layout.alignment: Qt.AlignHCenter
                    width: weatherRow.implicitWidth
                    height: weatherRow.implicitHeight

                    RowLayout {
                        id: weatherRow
                        spacing: 10
                        Text {
                            text: root.weatherIcon !== "" ? root.weatherIcon : "󰖐"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: 28
                            color: root.weatherHex
                        }
                        Text {
                            text: root.weatherTemp !== "" ? root.weatherTemp : "--°"
                            font.family: "JetBrains Mono"
                            font.weight: Font.Black
                            font.pixelSize: 28
                            color: root.text
                        }
                    }

                    MouseArea {
                        id: weatherToggleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.weatherRingsActive = !root.weatherRingsActive
                    }
                }

                Text {
                    text: root.timeStr !== "" ? root.timeStr : "00:00:00"
                    font.family: "JetBrains Mono"
                    font.weight: Font.Black
                    font.pixelSize: 160
                    color: root.text
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: root.fullDateStr !== "" ? root.fullDateStr.toUpperCase() : "----"
                    font.family: "JetBrains Mono"
                    font.weight: Font.Black
                    font.pixelSize: 42
                    color: root.text
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            RadialGradient {
                anchors.fill: parent
                z: 2
                // Center the bright point at the sun-facing side
                horizontalOffset: root.sunValueX * (parent.width * 0.45)
                verticalOffset:  -root.sunValueY * (parent.height * 0.45)
                horizontalRadius: parent.width * 0.72
                verticalRadius:   parent.height * 0.72
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.68; color: Qt.rgba(0, 0, 1/255, 0.55) }
                    GradientStop { position: 0.82; color: Qt.rgba(0, 0, 0, 0.88) }
                    GradientStop { position: 1.0;  color: Qt.rgba(0, 0, 0, 0.96) }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                z: 3
                // Rotate to place the glow band perpendicular to sun direction
                rotation: root.screenSunAngleDeg + 90
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0;  color: "transparent" }
                    GradientStop { position: 0.38; color: "transparent" }
                    GradientStop { position: 0.46; color: Qt.rgba(root.peach.r, root.peach.g, root.peach.b, 0.18) }
                    GradientStop { position: 0.50; color: Qt.rgba(root.blue.r,  root.blue.g,  root.blue.b,  0.22) }
                    GradientStop { position: 0.54; color: Qt.rgba(root.peach.r, root.peach.g, root.peach.b, 0.10) }
                    GradientStop { position: 0.62; color: "transparent" }
                    GradientStop { position: 1.0;  color: "transparent" }
                }
            }

            RadialGradient {
                anchors.fill: parent
                z: 3
                horizontalOffset: root.sunValueX * (parent.width * 0.3)
                verticalOffset: root.sunValueY * (parent.height * 0.3)
                horizontalRadius: parent.width * 0.8
                verticalRadius: parent.height * 0.8
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.2) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.85) }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                z: 4
                rotation: root.screenSunAngleDeg + 180
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(root.blue.r, root.blue.g, root.blue.b, 0.6) }
                    GradientStop { position: 0.04; color: Qt.rgba(root.sapphire.r, root.sapphire.g, root.sapphire.b, 0.35) }
                    GradientStop { position: 0.12; color: Qt.rgba(root.blue.r, root.blue.g, root.blue.b, 0.08) }
                    GradientStop { position: 0.25; color: "transparent" }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                rotation: root.screenSunAngleDeg
                z: 4
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(root.sapphire.r, root.sapphire.g, root.sapphire.b, 0.2) }
                    GradientStop { position: 0.06; color: Qt.rgba(root.blue.r, root.blue.g, root.blue.b, 0.05) }
                    GradientStop { position: 0.2; color: "transparent" }
                }
            }

            Rectangle {
                anchors.fill: parent; radius: width / 2; z: 4
                gradient: Gradient { orientation: Gradient.Vertical
                    GradientStop { position: 0.0;  color: "transparent" }
                    GradientStop { position: 0.42; color: Qt.rgba(root.teal.r, root.teal.g, root.teal.b, 0.04) }
                    GradientStop { position: 0.50; color: Qt.rgba(root.blue.r, root.blue.g, root.blue.b, 0.07) }
                    GradientStop { position: 0.58; color: Qt.rgba(root.teal.r, root.teal.g, root.teal.b, 0.04) }
                    GradientStop { position: 1.0;  color: "transparent" }
                }
            }
        }


        Repeater {
            model: (root.weatherRingsActive && root.detailedWeatherData && root.detailedWeatherData.forecast && root.detailedWeatherData.forecast[0] && root.detailedWeatherData.forecast[0].hourly)
                   ? root.detailedWeatherData.forecast[0].hourly.slice(0, 8)
                   : []

            delegate: Item {
                id: weatherNode

                property real orbitDistance: 1.65
                property real baseAngle: (index * (2 * Math.PI / 8))
                property real angle: baseAngle + root.independentCometAngle + root.weatherRingPhaseOffset
                
                property real b_x: Math.cos(angle) * orbitDistance
                property real b_z: Math.sin(angle) * orbitDistance
                property real b_y: Math.sin(index * Math.PI / 4) * 0.12 

                property var proj: root.project3D(b_x, b_y, b_z, true)

                x: (windowContent.width / 2) + (earthBase.earthProj.x * root.baseSphereRadius) + (proj.x * root.earthSphereRadius) - width / 2
                y: (windowContent.height / 2) + (earthBase.earthProj.y * root.baseSphereRadius) + (proj.y * root.earthSphereRadius) - height / 2
                z: earthBase.z + Math.round(proj.z * 1000)

                opacity: root.weatherRingsActive ? (proj.z < -0.1 ? 0.35 : 1.0) : 0.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 450 } }

                property real baselineDepthScale: 0.55 + (Math.max(0.0, proj.z) * 0.40)
                scale: (root.weatherRingsActive ? baselineDepthScale : 0.2) * root.satelliteZoom * 1.6
                Behavior on scale { 
                    enabled: !sceneMouse.pressed
                    NumberAnimation { duration: 550; easing.type: Easing.OutBack } 
                }

                width: 110; height: 48

                property real xNorm: proj.x / orbitDistance
                property real yNorm: proj.y / orbitDistance

                transform: [
                    Rotation {
                        axis { x: 1; y: 0; z: 0 }
                        angle: -weatherNode.yNorm * 55
                        origin.x: weatherNode.width / 2
                        origin.y: weatherNode.height / 2
                    },
                    Rotation {
                        axis { x: 0; y: 1; z: 0 }
                        angle: weatherNode.xNorm * 60
                        origin.x: weatherNode.width / 2
                        origin.y: weatherNode.height / 2
                    }
                ]

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: root.crust
                    border.color: modelData.hex ? Qt.rgba(parseInt(modelData.hex.slice(1,3), 16) / 255, parseInt(modelData.hex.slice(3,5), 16) / 255, parseInt(modelData.hex.slice(5,7), 16) / 255, 0.4) : Qt.rgba(root.mauve.r, root.mauve.g, root.mauve.b, 0.3)
                    border.width: 1.5
                    transform: Translate { x: -weatherNode.xNorm * 8; y: weatherNode.yNorm * 8 }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: root.mantle
                    border.color: modelData.hex ? Qt.rgba(parseInt(modelData.hex.slice(1,3), 16) / 255, parseInt(modelData.hex.slice(3,5), 16) / 255, parseInt(modelData.hex.slice(5,7), 16) / 255, 0.5) : Qt.rgba(root.mauve.r, root.mauve.g, root.mauve.b, 0.4)
                    border.width: 1.5
                    transform: Translate { x: -weatherNode.xNorm * 4; y: weatherNode.yNorm * 4 }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: Qt.rgba(root.base.r, root.base.g, root.base.b, 0.92)
                    border.color: modelData.hex
                        ? Qt.rgba(
                            parseInt(modelData.hex.slice(1,3), 16) / 255,
                            parseInt(modelData.hex.slice(3,5), 16) / 255,
                            parseInt(modelData.hex.slice(5,7), 16) / 255,
                            0.6)
                        : Qt.rgba(root.mauve.r, root.mauve.g, root.mauve.b, 0.5)
                    border.width: 1.5

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 10
                        spacing: 6
                        Text {
                            text: modelData ? modelData.time : ""
                            font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: 10
                            color: root.text
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Text {
                            text: modelData ? modelData.icon : ""
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 14
                            color: modelData.hex ? modelData.hex : root.text
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: modelData ? modelData.temp + "°" : ""
                            font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: 12
                            color: root.text
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }
            }
        }

        Item {
            id: gaugeSatellite

            property real orbitDistance: 1.55 
            property real angle: root.gaugeAngle + root.gaugeRepositionOffset
            property real b_x: Math.cos(angle) * orbitDistance
            property real b_z: Math.sin(angle) * orbitDistance
            property real b_y: gaugeBaseY + Math.sin(angle) * 0.10

            property var proj: root.project3D(b_x, b_y, b_z, true)

            x: (windowContent.width / 2) + (earthBase.earthProj.x * root.baseSphereRadius) + (proj.x * root.earthSphereRadius) - width / 2
            y: (windowContent.height / 2) + (earthBase.earthProj.y * root.baseSphereRadius) + (proj.y * root.earthSphereRadius) - height / 2
            z: earthBase.z + Math.round(proj.z * 1000)

            opacity: root.weatherRingsActive ? 1.0 : 0.0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 400 } }

            property real baselineDepthScale: 0.72 + (Math.max(0.0, proj.z) * 0.25)
            property real centerFocusFactor:  (proj.z > 0) ? Math.max(0.0, 1.0 - (Math.abs(proj.x) * 1.6)) : 0.0
            scale: (root.weatherRingsActive ? ((baselineDepthScale + (centerFocusFactor * 0.12)) * 2.2) : 1.30) * root.satelliteZoom
            Behavior on scale { 
                enabled: !sceneMouse.pressed
                NumberAnimation { duration: 500; easing.type: Easing.OutBack } 
            }

            width: 260
            height: 100

            property real xNorm: proj.x / orbitDistance
            property real yNorm: proj.y / orbitDistance

            transform: [
                Rotation {
                    axis { x: 1; y: 0; z: 0 }
                    angle: -gaugeSatellite.yNorm * 55
                    origin.x: gaugeSatellite.width / 2
                    origin.y: gaugeSatellite.height / 2
                },
                Rotation {
                    axis { x: 0; y: 1; z: 0 }
                    angle: gaugeSatellite.xNorm * 60
                    origin.x: gaugeSatellite.width / 2
                    origin.y: gaugeSatellite.height / 2
                }
            ]

            Rectangle {
                id: gaugeExhaust
                width: 70; height: 30
                anchors.horizontalCenter: gaugeCoreChassis.horizontalCenter
                anchors.top: gaugeCoreChassis.bottom
                anchors.topMargin: -2
                z: -1
                opacity: 0.25 + Math.sin(root.independentCometAngle * 4 + 1) * 0.05
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(root.teal.r, root.teal.g, root.teal.b, 0.35) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Rectangle {
                width: 190; height: 86; anchors.centerIn: parent; radius: 14
                color: root.crust; border.color: Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.2); border.width: 1.2
                transform: Translate { x: -gaugeSatellite.xNorm * 10; y: gaugeSatellite.yNorm * 10 }
            }
            Rectangle {
                width: 190; height: 86; anchors.centerIn: parent; radius: 14
                color: root.mantle; border.color: Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.35); border.width: 1.2
                transform: Translate { x: -gaugeSatellite.xNorm * 5; y: gaugeSatellite.yNorm * 5 }
            }
            Rectangle {
                id: gaugeCoreChassis
                width: 190; height: 86
                anchors.centerIn: parent
                color: Qt.rgba(root.base.r, root.base.g, root.base.b, 0.94)
                border.color: gaugeSatellite.centerFocusFactor > 0
                    ? Qt.rgba(root.peach.r, root.peach.g, root.peach.b, 0.55)
                    : Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.5)
                border.width: 1.2; radius: 14
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Rectangle {
                    width: 4; height: 4; radius: 2; color: root.peach
                    anchors.top: parent.top; anchors.topMargin: 6
                    anchors.right: parent.right; anchors.rightMargin: 8
                    SequentialAnimation on opacity { loops: Animation.Infinite; running: true
                        NumberAnimation { from: 1; to: 0.15; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.15; to: 1; duration: 900; easing.type: Easing.InOutSine }
                    }
                }

                Grid {
                    anchors.centerIn: parent
                    columns: 2; rows: 2; spacing: 6

                    Rectangle {
                        width: 82; height: 32; radius: 8
                        color: Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.5)
                        Row {
                            anchors.centerIn: parent; spacing: 6
                            Text { text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: 14; color: root.blue; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                text: ((root.detailedWeatherData && root.detailedWeatherData.forecast && root.detailedWeatherData.forecast[0]) ? root.detailedWeatherData.forecast[0].wind + "m/s" : "--")
                                font.family: "JetBrains Mono"; font.pixelSize: 11; font.weight: Font.Black; color: root.text; anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Rectangle {
                        width: 82; height: 32; radius: 8
                        color: Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.5)
                        Row {
                            anchors.centerIn: parent; spacing: 6
                            Text { text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: 14; color: root.teal; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                text: ((root.detailedWeatherData && root.detailedWeatherData.forecast && root.detailedWeatherData.forecast[0]) ? root.detailedWeatherData.forecast[0].humidity + "%" : "--")
                                font.family: "JetBrains Mono"; font.pixelSize: 11; font.weight: Font.Black; color: root.text; anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Rectangle {
                        width: 82; height: 32; radius: 8
                        color: Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.5)
                        Row {
                            anchors.centerIn: parent; spacing: 6
                            Text { text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: 14; color: root.mauve; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                text: ((root.detailedWeatherData && root.detailedWeatherData.forecast && root.detailedWeatherData.forecast[0]) ? root.detailedWeatherData.forecast[0].pop + "%" : "--")
                                font.family: "JetBrains Mono"; font.pixelSize: 11; font.weight: Font.Black; color: root.text; anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Rectangle {
                        width: 82; height: 32; radius: 8
                        color: Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.5)
                        Row {
                            anchors.centerIn: parent; spacing: 6
                            Text { text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: 14; color: root.peach; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                text: ((root.detailedWeatherData && root.detailedWeatherData.forecast && root.detailedWeatherData.forecast[0]) ? root.detailedWeatherData.forecast[0].feels_like + "°" : "--")
                                font.family: "JetBrains Mono"; font.pixelSize: 11; font.weight: Font.Black; color: root.text; anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: 26; height: 44; anchors.right: gaugeCoreChassis.left; anchors.rightMargin: 5; anchors.verticalCenter: gaugeCoreChassis.verticalCenter
                color: root.crust; border.color: Qt.rgba(root.peach.r, root.peach.g, root.peach.b, 0.15); border.width: 1; radius: 4
                transform: Translate { x: -gaugeSatellite.xNorm * 10; y: gaugeSatellite.yNorm * 10 }
            }
            Rectangle {
                width: 26; height: 44; anchors.right: gaugeCoreChassis.left; anchors.rightMargin: 5; anchors.verticalCenter: gaugeCoreChassis.verticalCenter
                color: root.mantle; border.color: Qt.rgba(root.peach.r, root.peach.g, root.peach.b, 0.25); border.width: 1; radius: 4
                transform: Translate { x: -gaugeSatellite.xNorm * 5; y: gaugeSatellite.yNorm * 5 }
            }
            Rectangle {
                width: 26; height: 44; anchors.right: gaugeCoreChassis.left; anchors.rightMargin: 5; anchors.verticalCenter: gaugeCoreChassis.verticalCenter
                color: root.mantle; border.color: Qt.rgba(root.peach.r, root.peach.g, root.peach.b, 0.35); border.width: 1; radius: 4
                Grid { anchors.fill: parent; anchors.margins: 4; columns: 2; spacing: 2
                    Repeater { model: 4; Rectangle { width: 8; height: 17; color: Qt.rgba(root.peach.r, root.peach.g, root.peach.b, 0.15); radius: 2 } }
                }
            }

            Rectangle {
                width: 26; height: 44; anchors.left: gaugeCoreChassis.right; anchors.leftMargin: 5; anchors.verticalCenter: gaugeCoreChassis.verticalCenter
                color: root.crust; border.color: Qt.rgba(root.peach.r, root.peach.g, root.peach.b, 0.15); border.width: 1; radius: 4
                transform: Translate { x: -gaugeSatellite.xNorm * 10; y: gaugeSatellite.yNorm * 10 }
            }
            Rectangle {
                width: 26; height: 44; anchors.left: gaugeCoreChassis.right; anchors.leftMargin: 5; anchors.verticalCenter: gaugeCoreChassis.verticalCenter
                color: root.mantle; border.color: Qt.rgba(root.peach.r, root.peach.g, root.peach.b, 0.25); border.width: 1; radius: 4
                transform: Translate { x: -gaugeSatellite.xNorm * 5; y: gaugeSatellite.yNorm * 5 }
            }
            Rectangle {
                width: 26; height: 44; anchors.left: gaugeCoreChassis.right; anchors.leftMargin: 5; anchors.verticalCenter: gaugeCoreChassis.verticalCenter
                color: root.mantle; border.color: Qt.rgba(root.peach.r, root.peach.g, root.peach.b, 0.35); border.width: 1; radius: 4
                Grid { anchors.fill: parent; anchors.margins: 4; columns: 2; spacing: 2
                    Repeater { model: 4; Rectangle { width: 8; height: 17; color: Qt.rgba(root.peach.r, root.peach.g, root.peach.b, 0.15); radius: 2 } }
                }
            }
        }


        Item {
            id: worldCenter
            anchors.centerIn: parent
            width:  root.sphereRadius * 2
            height: root.sphereRadius * 2
            z: 1000 

            Rectangle {
                id: moonBase
                anchors.fill: parent
                radius: width / 2
                color: "#111"
                z: 0

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width:  moonBase.width
                        height: moonBase.height
                        radius: width / 2
                    }
                }

                Item {
                    anchors.fill: parent
                    Image {
                        id: moonTexture
                        width: parent.width * 2; height: parent.height * 2
                        x: {
                            let norm = (((root.rotY + root.camY) % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2)
                            return -((norm / (Math.PI * 2)) * parent.width * 2) % (parent.width * 2)
                        }
                        y: {
                            let t = (root.rotX + root.camX) / (Math.PI * 0.5)
                            t = Math.max(-1, Math.min(1, t))
                            return -parent.height * 0.25 - t * parent.height * 0.25
                        }
                        source: "file:///home/ilyamiro/Downloads/moon.jpg"
                        fillMode: Image.Stretch; smooth: true; asynchronous: true
                    }
                    Image {
                        width: parent.width * 2; height: parent.height * 2
                        x: moonTexture.x + parent.width * 2
                        y: moonTexture.y
                        source: "file:///home/ilyamiro/Downloads/moon.jpg"
                        fillMode: Image.Stretch; smooth: true; asynchronous: true
                    }
                }

                RadialGradient {
                    anchors.fill: parent
                    z: 1
                    // Center the bright point at the sun-facing side
                    horizontalOffset: root.sunValueX * (parent.width * 0.45)
                    verticalOffset:  -root.sunValueY * (parent.height * 0.45)
                    horizontalRadius: parent.width * 0.72
                    verticalRadius:   parent.height * 0.72
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.68; color: Qt.rgba(0, 0, 1/255, 0.55) }
                        GradientStop { position: 0.82; color: Qt.rgba(0, 0, 0, 0.88) }
                        GradientStop { position: 1.0;  color: Qt.rgba(0, 0, 0, 0.96) }
                    }
                }

                RadialGradient {
                    anchors.fill: parent
                    z: 2
                    horizontalOffset: root.sunValueX * (parent.width * 0.25)
                    verticalOffset: root.sunValueY * (parent.height * 0.25)
                    horizontalRadius: parent.width * 0.85
                    verticalRadius: parent.height * 0.85
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.55; color: Qt.rgba(root.mantle.r, root.mantle.g, root.mantle.b, 0.15) }
                        GradientStop { position: 0.88; color: Qt.rgba(root.crust.r, root.crust.g, root.crust.b, 0.5) }
                        GradientStop { position: 1.0; color: "#020407" }
                    }
                }

                RadialGradient {
                    anchors.fill: parent
                    z: 3
                    horizontalOffset: root.sunValueX * (parent.width * 0.2)
                    verticalOffset: root.sunValueY * (parent.height * 0.2)
                    horizontalRadius: parent.width * 0.5
                    verticalRadius: parent.height * 0.5
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(root.yellow.r, root.yellow.g, root.yellow.b, 0.3) }
                        GradientStop { position: 0.3; color: Qt.rgba(root.peach.r, root.peach.g, root.peach.b, 0.05) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                RadialGradient {
                    anchors.fill: parent
                    z: 4
                    horizontalRadius: parent.width / 2
                    verticalRadius: parent.height / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.85; color: "transparent" }
                        GradientStop { position: 0.98; color: Qt.rgba(root.crust.r, root.crust.g, root.crust.b, 0.25) }
                        GradientStop { position: 1.0;  color: Qt.rgba(root.base.r, root.base.g, root.base.b, 0.60) }
                    }
                }
            }

            Item {
                id: telemetrySatellite

                property real orbitDistance: 1.40
                property real angle: root.telemetryAngle
                property real b_x: Math.cos(angle) * orbitDistance
                property real b_z: Math.sin(angle) * orbitDistance
                property real b_y: Math.sin(angle) * 0.08

                property var proj: root.project3D(b_x, b_y, b_z, true)

                x: (worldCenter.width / 2) + (proj.x * root.sphereRadius) - width / 2
                y: (worldCenter.height / 2) + (proj.y * root.sphereRadius) - height / 2
                z: Math.round(proj.z * 1000)

                opacity: 1.0
                visible: true

                property real baselineDepthScale: 0.75 + (Math.max(0.0, proj.z) * 0.25)
                property real centerFocusFactor:  (proj.z > 0) ? Math.max(0.0, 1.0 - (Math.abs(proj.x) * 1.6)) : 0.0
                scale: (baselineDepthScale + (centerFocusFactor * 0.18)) * 1.45 * root.satelliteZoom
                Behavior on scale { 
                    enabled: !sceneMouse.pressed
                    NumberAnimation { duration: 500; easing.type: Easing.OutBack } 
                }

                width:  165
                height: 210

                property real xNorm: proj.x / orbitDistance
                property real yNorm: proj.y / orbitDistance

                transform: [
                    Rotation {
                        axis { x: 1; y: 0; z: 0 }
                        angle: -telemetrySatellite.yNorm * 60
                        origin.x: telemetrySatellite.width / 2
                        origin.y: telemetrySatellite.height / 2
                    },
                    Rotation {
                        axis { x: 0; y: 1; z: 0 }
                        angle: telemetrySatellite.xNorm * 55
                        origin.x: telemetrySatellite.width / 2
                        origin.y: telemetrySatellite.height / 2
                    }
                ]

                Column {
                    id: satelliteVerticalChassis
                    anchors.centerIn: parent; spacing: 4

                    Item {
                        width: 36; height: 38
                        anchors.horizontalCenter: parent.horizontalCenter
                        
                        Rectangle {
                            anchors.fill: parent; radius: 4
                            color: root.crust; border.color: Qt.rgba(root.surface2.r, root.surface2.g, root.surface2.b, 0.15); border.width: 1
                            transform: Translate { x: -telemetrySatellite.xNorm * 10; y: telemetrySatellite.yNorm * 10 }
                        }
                        Rectangle {
                            anchors.fill: parent; radius: 4
                            color: root.mantle; border.color: Qt.rgba(root.surface2.r, root.surface2.g, root.surface2.b, 0.25); border.width: 1
                            transform: Translate { x: -telemetrySatellite.xNorm * 5; y: telemetrySatellite.yNorm * 5 }
                        }
                        Rectangle {
                            anchors.fill: parent; radius: 4
                            color: root.mantle
                            border.color: Qt.rgba(root.surface2.r, root.surface2.g, root.surface2.b, 0.4)
                            border.width: 1
                            Rectangle { width: parent.width; height: 1; color: Qt.rgba(root.mauve.r, root.mauve.g, root.mauve.b, 0.12); anchors.centerIn: parent }
                            Rectangle { width: 1; height: parent.height; color: Qt.rgba(root.mauve.r, root.mauve.g, root.mauve.b, 0.12); anchors.centerIn: parent }
                        }
                    }

                    Rectangle { width: 2; height: 6; anchors.horizontalCenter: parent.horizontalCenter; color: Qt.rgba(root.surface2.r, root.surface2.g, root.surface2.b, 0.5) }

                    Item {
                        width: 120; height: 64
                        anchors.horizontalCenter: parent.horizontalCenter

                        Rectangle {
                            id: telemetryExhaust
                            width: 50; height: 30
                            anchors.horizontalCenter: centralCoreChassis.horizontalCenter
                            anchors.top: centralCoreChassis.bottom
                            anchors.topMargin: -2
                            z: -1
                            opacity: 0.25 + Math.sin(root.independentCometAngle * 4 + 2) * 0.05
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(root.mauve.r, root.mauve.g, root.mauve.b, 0.35) }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }

                        Rectangle {
                            width: 120; height: 64; radius: 12
                            color: root.crust; border.color: Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.2); border.width: 1.2
                            transform: Translate { x: -telemetrySatellite.xNorm * 10; y: telemetrySatellite.yNorm * 10 }
                        }
                        Rectangle {
                            width: 120; height: 64; radius: 12
                            color: root.mantle; border.color: Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.35); border.width: 1.2
                            transform: Translate { x: -telemetrySatellite.xNorm * 5; y: telemetrySatellite.yNorm * 5 }
                        }
                        Rectangle {
                            id: centralCoreChassis
                            anchors.fill: parent
                            color: Qt.rgba(root.base.r, root.base.g, root.base.b, 0.94)
                            border.color: telemetrySatellite.centerFocusFactor > 0
                                ? Qt.rgba(root.teal.r, root.teal.g, root.teal.b, 0.5)
                                : Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.5)
                            border.width: 1.2; radius: 12
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            Row {
                                spacing: 3
                                anchors.top: parent.top; anchors.topMargin: 5
                                anchors.left: parent.left; anchors.leftMargin: 7
                                Rectangle { width: 3; height: 3; radius: 1.5; color: root.blue
                                    SequentialAnimation on opacity { loops: Animation.Infinite; running: true
                                        NumberAnimation { from: 1; to: 0.1; duration: 250 }
                                        NumberAnimation { from: 0.1; to: 1; duration: 250 }
                                        PauseAnimation { duration: 600 }
                                    }
                                }
                                Rectangle { width: 3; height: 3; radius: 1.5; color: root.teal
                                    SequentialAnimation on opacity { loops: Animation.Infinite; running: true
                                        PauseAnimation { duration: 300 }
                                        NumberAnimation { from: 1; to: 0.0; duration: 350 }
                                        NumberAnimation { from: 0.0; to: 1; duration: 350 }
                                    }
                                }
                            }

                            Grid {
                                id: workspaceBlockGrid
                                anchors.centerIn: parent; anchors.verticalCenterOffset: 1
                                columns: 4; spacing: 4

                                Repeater {
                                    model: workspacesModel
                                    delegate: Rectangle {
                                        width: 22; height: 18; radius: 4
                                        property string stateLabel: model.wsState
                                        property string wsName:     model.wsId

                                        color: stateLabel === "active"
                                            ? root.mauve
                                            : (stateLabel === "occupied"
                                                ? Qt.rgba(root.text.r, root.text.g, root.text.b, 0.12)
                                                : "transparent")
                                        border.color: stateLabel === "active"
                                            ? "transparent"
                                            : (stateLabel === "occupied"
                                                ? Qt.rgba(root.text.r, root.text.g, root.text.b, 0.3)
                                                : Qt.rgba(root.overlay0.r, root.overlay0.g, root.overlay0.b, 0.2))
                                        border.width: 1

                                        Behavior on color        { ColorAnimation { duration: 120 } }
                                        Behavior on border.color { ColorAnimation { duration: 120 } }

                                        scale: wsPressArea.pressed ? 0.88 : (wsPressArea.containsMouse && stateLabel !== "active" ? 1.12 : 1.0)
                                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: wsName
                                            font.family: "JetBrains Mono"; font.pixelSize: 10
                                            font.weight: stateLabel === "active" ? Font.Bold : Font.Normal
                                            color: stateLabel === "active"
                                                ? root.crust
                                                : (stateLabel === "occupied" ? root.text : root.overlay0)
                                        }

                                        MouseArea {
                                            id: wsPressArea
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: Quickshell.execDetached(["bash", "-c", paths.serpantinumDir + "/scripts/qs_manager.sh " + wsName])
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { width: 2; height: 6; anchors.horizontalCenter: parent.horizontalCenter; color: Qt.rgba(root.surface2.r, root.surface2.g, root.surface2.b, 0.5) }

                    Item {
                        width: 32; height: 34
                        anchors.horizontalCenter: parent.horizontalCenter

                        Rectangle {
                            width: 32; height: 34; radius: 4
                            color: root.crust; border.color: Qt.rgba(root.surface2.r, root.surface2.g, root.surface2.b, 0.15); border.width: 1
                            transform: Translate { x: -telemetrySatellite.xNorm * 10; y: telemetrySatellite.yNorm * 10 }
                        }
                        Rectangle {
                            width: 32; height: 34; radius: 4
                            color: root.mantle; border.color: Qt.rgba(root.surface2.r, root.surface2.g, root.surface2.b, 0.25); border.width: 1
                            transform: Translate { x: -telemetrySatellite.xNorm * 5; y: telemetrySatellite.yNorm * 5 }
                        }
                        Rectangle {
                            id: telemetryBottomPanel
                            anchors.fill: parent
                            color: root.mantle
                            border.color: Qt.rgba(root.surface2.r, root.surface2.g, root.surface2.b, 0.4)
                            border.width: 1; radius: 4
                            Rectangle { width: parent.width; height: 1; color: Qt.rgba(root.mauve.r, root.mauve.g, root.mauve.b, 0.12); anchors.centerIn: parent }
                            Rectangle { width: 1; height: parent.height; color: Qt.rgba(root.mauve.r, root.mauve.g, root.mauve.b, 0.12); anchors.centerIn: parent }
                        }
                    }
                }
            }

            Item {
                id: sysInfoSatellite

                property real orbitDistance: 1.60
                property real angle: root.sysInfoAngle
                property real b_x: Math.cos(angle) * orbitDistance
                property real b_z: Math.sin(angle) * orbitDistance
                property real b_y: 0.42 + Math.cos(angle * 2.1 + 3.0) * 0.05

                property var proj: root.project3D(b_x, b_y, b_z, true)

                x: (worldCenter.width / 2) + (proj.x * root.sphereRadius) - width / 2
                y: (worldCenter.height / 2) + (proj.y * root.sphereRadius) - height / 2
                z: Math.round(proj.z * 1000)

                opacity: 1.0
                visible: true

                property real baselineDepthScale: 0.72 + (Math.max(0.0, proj.z) * 0.25)
                property real centerFocusFactor:  (proj.z > 0) ? Math.max(0.0, 1.0 - (Math.abs(proj.x) * 1.6)) : 0.0
                scale: (baselineDepthScale + (centerFocusFactor * 0.12)) * 1.45 * root.satelliteZoom
                Behavior on scale { 
                    enabled: !sceneMouse.pressed
                    NumberAnimation { duration: 500; easing.type: Easing.OutBack } 
                }

                width:  340
                height: 140

                property real xNorm: proj.x / orbitDistance
                property real yNorm: proj.y / orbitDistance

                transform: [
                    Rotation {
                        axis { x: 1; y: 0; z: 0 }
                        angle: -sysInfoSatellite.yNorm * 55
                        origin.x: sysInfoSatellite.width / 2
                        origin.y: sysInfoSatellite.height / 2
                    },
                    Rotation {
                        axis { x: 0; y: 1; z: 0 }
                        angle: sysInfoSatellite.xNorm * 60
                        origin.x: sysInfoSatellite.width / 2
                        origin.y: sysInfoSatellite.height / 2
                    }
                ]

                Item {
                    anchors.centerIn: parent
                    width: parent.width
                    height: 90

                    Rectangle {
                        id: sysExhaust
                        width: 80; height: 30
                        anchors.horizontalCenter: sysCoreChassis.horizontalCenter
                        anchors.top: sysCoreChassis.bottom
                        anchors.topMargin: -2
                        z: -1
                        opacity: 0.25 + Math.sin(root.independentCometAngle * 4 + 3) * 0.05
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(root.teal.r, root.teal.g, root.teal.b, 0.35) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }

                    Rectangle {
                        width: 55; height: 50; anchors.right: sysCoreChassis.left; anchors.rightMargin: 6; anchors.verticalCenter: sysCoreChassis.verticalCenter
                        color: root.crust; border.color: Qt.rgba(root.surface2.r, root.surface2.g, root.surface2.b, 0.15); border.width: 1; radius: 4
                        transform: Translate { x: -sysInfoSatellite.xNorm * 10; y: sysInfoSatellite.yNorm * 10 }
                    }
                    Rectangle {
                        width: 55; height: 50; anchors.right: sysCoreChassis.left; anchors.rightMargin: 6; anchors.verticalCenter: sysCoreChassis.verticalCenter
                        color: root.mantle; border.color: Qt.rgba(root.surface2.r, root.surface2.g, root.surface2.b, 0.25); border.width: 1; radius: 4
                        transform: Translate { x: -sysInfoSatellite.xNorm * 5; y: sysInfoSatellite.yNorm * 5 }
                    }
                    Rectangle {
                        id: sysLPanel
                        width: 55; height: 50
                        anchors.right:          sysCoreChassis.left
                        anchors.rightMargin:   6
                        anchors.verticalCenter: sysCoreChassis.verticalCenter
                        color: root.mantle
                        border.color: Qt.rgba(root.surface2.r, root.surface2.g, root.surface2.b, 0.35)
                        border.width: 1; radius: 4
                        Grid {
                            anchors.fill: parent; anchors.margins: 4; columns: 3; rows: 3; spacing: 2
                            Repeater { model: 9
                                Rectangle {
                                    width:  (sysLPanel.width  - 8 - 4) / 3
                                    height: (sysLPanel.height - 8 - 4) / 3
                                    color: Qt.rgba(root.teal.r, root.teal.g, root.teal.b, index % 2 === 0 ? 0.16 : 0.06)
                                    radius: 1
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 200; height: 90; anchors.centerIn: parent; radius: 14
                        color: root.crust; border.color: Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.2); border.width: 1.2
                        transform: Translate { x: -sysInfoSatellite.xNorm * 10; y: sysInfoSatellite.yNorm * 10 }
                    }
                    Rectangle {
                        width: 200; height: 90; anchors.centerIn: parent; radius: 14
                        color: root.mantle; border.color: Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.35); border.width: 1.2
                        transform: Translate { x: -sysInfoSatellite.xNorm * 5; y: sysInfoSatellite.yNorm * 5 }
                    }
                    Rectangle {
                        id: sysCoreChassis
                        width: 200; height: 90
                        anchors.centerIn: parent
                        color: Qt.rgba(root.base.r, root.base.g, root.base.b, 0.94)
                        border.color: sysInfoSatellite.centerFocusFactor > 0
                            ? Qt.rgba(root.teal.r, root.teal.g, root.teal.b, 0.5)
                            : Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.5)
                        border.width: 1.2; radius: 14
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        width: 4; height: 4; radius: 2; color: root.teal
                        anchors.top: parent.top; anchors.topMargin: 5
                        anchors.right: parent.right; anchors.rightMargin: 7
                        SequentialAnimation on opacity { loops: Animation.Infinite; running: true
                            NumberAnimation { from: 1; to: 0.1; duration: 800; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 0.1; to: 1; duration: 800; easing.type: Easing.InOutSine }
                        }
                    }

                    Grid {
                        id: sysPillGrid
                        anchors.centerIn: parent
                        columns: 2; rows: 3; spacing: 4

                        Rectangle {
                            id: kbPill
                            width: 80; height: 20; radius: 6
                            color: kbPillMouse.containsMouse
                                ? Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.8)
                                : Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.5)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            scale: kbPillMouse.pressed ? 0.92 : (kbPillMouse.containsMouse ? 1.06 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }
                            Row {
                                anchors.centerIn: parent; spacing: 4
                                Text { text: "󰌌"; font.family: "Iosevka Nerd Font"; font.pixelSize: 11; color: root.overlay0; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: root.kbLayout; font.family: "JetBrains Mono"; font.pixelSize: 10; font.weight: Font.Black; color: root.text; anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea { id: kbPillMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["hyprctl", "switchxkblayout", "main", "next"]) }
                        }

                        Rectangle {
                            id: volPill
                            width: 80; height: 20; radius: 6
                            color: volPillMouse.containsMouse
                                ? Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.8)
                                : Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.5)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Rectangle {
                                anchors.fill: parent; radius: parent.radius
                                opacity: root.isSoundActive ? 0.85 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 250 } }
                                gradient: Gradient { orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: root.peach }
                                    GradientStop { position: 1.0; color: Qt.lighter(root.peach, 1.3) }
                                }
                            }
                            scale: volPillMouse.pressed ? 0.92 : (volPillMouse.containsMouse ? 1.06 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }
                            Row {
                                anchors.centerIn: parent; spacing: 4
                                Text { text: root.volIcon; font.family: "Iosevka Nerd Font"; font.pixelSize: 11; color: root.isSoundActive ? root.base : root.subtext0; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: root.volPercent; font.family: "JetBrains Mono"; font.pixelSize: 10; font.weight: Font.Black; color: root.isSoundActive ? root.base : root.text; anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea { id: volPillMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["bash", "-c", paths.serpantinumDir + "/scripts/qs_manager.sh toggle volume"]) }
                        }

                        Rectangle {
                            id: wifiSatPill
                            width: 80; height: 20; radius: 6
                            color: wifiSatPillMouse.containsMouse
                                ? Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.8)
                                : Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.5)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Rectangle {
                                anchors.fill: parent; radius: parent.radius
                                opacity: root.showEthernet ? (root.ethStatus === "Connected" ? 1.0 : 0.0) : (root.isWifiOn ? 1.0 : 0.0)
                                Behavior on opacity { NumberAnimation { duration: 250 } }
                                gradient: Gradient { orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: root.blue }
                                    GradientStop { position: 1.0; color: Qt.lighter(root.blue, 1.3) }
                                }
                            }
                            scale: wifiSatPillMouse.pressed ? 0.92 : (wifiSatPillMouse.containsMouse ? 1.06 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }
                            Row {
                                anchors.centerIn: parent; spacing: 4
                                Text {
                                    text: root.showEthernet ? "󰈀" : root.wifiIcon; font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                                    color: root.showEthernet ? (root.ethStatus === "Connected" ? root.base : root.subtext0) : (root.isWifiOn ? root.base : root.subtext0)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: root.showEthernet ? root.ethStatus : (root.isWifiOn ? (root.wifiSsid !== "" ? root.wifiSsid : "On") : "Off")
                                    font.family: "JetBrains Mono"; font.pixelSize: 10; font.weight: Font.Black
                                    color: root.showEthernet ? (root.ethStatus === "Connected" ? root.base : root.text) : (root.isWifiOn ? root.base : root.text)
                                    elide: Text.ElideRight; width: 52; anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            MouseArea { id: wifiSatPillMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["bash", "-c", paths.serpantinumDir + "/scripts/qs_manager.sh toggle network wifi"]) }
                        }

                        Rectangle {
                            id: btSatPill
                            width: 80; height: 20; radius: 6
                            visible: !root.isDesktop
                            color: btSatPillMouse.containsMouse
                                ? Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.8)
                                : Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.5)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Rectangle {
                                anchors.fill: parent; radius: parent.radius
                                opacity: root.isBtOn ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 250 } }
                                gradient: Gradient { orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: root.mauve }
                                    GradientStop { position: 1.0; color: Qt.lighter(root.mauve, 1.3) }
                                }
                            }
                            scale: btSatPillMouse.pressed ? 0.92 : (btSatPillMouse.containsMouse ? 1.06 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }
                            Row {
                                anchors.centerIn: parent; spacing: 4
                                Text { text: root.btIcon; font.family: "Iosevka Nerd Font"; font.pixelSize: 11; color: root.isBtOn ? root.base : root.subtext0; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: root.isBtOn ? (root.btDevice !== "" ? root.btDevice : "On") : "Off"; font.family: "JetBrains Mono"; font.pixelSize: 10; font.weight: Font.Black; color: root.isBtOn ? root.base : root.text; elide: Text.ElideRight; width: 52; anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea { id: btSatPillMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["bash", "-c", paths.serpantinumDir + "/scripts/qs_manager.sh toggle network bt"]) }
                        }

                        Rectangle {
                            id: batSatPill
                            width: 80; height: 20; radius: 6
                            color: batSatPillMouse.containsMouse
                                ? Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.8)
                                : Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.5)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Rectangle {
                                anchors.fill: parent; radius: parent.radius; opacity: 1.0
                                gradient: Gradient { orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: root.isDesktop ? root.red : root.batColor; Behavior on color { ColorAnimation { duration: 300 } } }
                                    GradientStop { position: 1.0; color: root.isDesktop ? Qt.lighter(root.red, 1.3) : Qt.lighter(root.batColor, 1.3); Behavior on color { ColorAnimation { duration: 300 } } }
                                }
                            }
                            scale: batSatPillMouse.pressed ? 0.92 : (batSatPillMouse.containsMouse ? 1.06 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }
                            Row {
                                anchors.centerIn: parent; spacing: 4
                                Text { text: root.isDesktop ? "" : root.batIcon; font.family: "Iosevka Nerd Font"; font.pixelSize: root.isDesktop ? 13 : 11; color: root.base; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: root.batPercent; font.family: "JetBrains Mono"; font.pixelSize: 10; font.weight: Font.Black; color: root.base; anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea { id: batSatPillMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["bash", "-c", paths.serpantinumDir + "/scripts/qs_manager.sh toggle battery"]) }
                        }

                        Rectangle {
                            id: notifSatPill
                            width: 80; height: 20; radius: 6
                            color: notifSatPillMouse.containsMouse
                                ? Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.8)
                                : Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.5)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            scale: notifSatPillMouse.pressed ? 0.92 : (notifSatPillMouse.containsMouse ? 1.06 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }
                            Row {
                                anchors.centerIn: parent; spacing: 4
                                Text { text: "󰂚"; font.family: "Iosevka Nerd Font"; font.pixelSize: 11; color: root.overlay0; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "Notifs"; font.family: "JetBrains Mono"; font.pixelSize: 10; font.weight: Font.Black; color: root.text; anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea { id: notifSatPillMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["bash", "-c", paths.serpantinumDir + "/scripts/qs_manager.sh toggle notifications"]) }
                        }
                    }
                }

                Rectangle { width: 55; height: 50; anchors.left: sysCoreChassis.right; anchors.leftMargin: 6; anchors.verticalCenter: sysCoreChassis.verticalCenter
                    color: root.crust; border.color: Qt.rgba(root.surface2.r, root.surface2.g, root.surface2.b, 0.15); border.width: 1; radius: 4
                    transform: Translate { x: -sysInfoSatellite.xNorm * 10; y: sysInfoSatellite.yNorm * 10 }
                }
                Rectangle {
                    width: 55; height: 50; anchors.left: sysCoreChassis.right; anchors.leftMargin: 6; anchors.verticalCenter: sysCoreChassis.verticalCenter
                    color: root.mantle; border.color: Qt.rgba(root.surface2.r, root.surface2.g, root.surface2.b, 0.25); border.width: 1; radius: 4
                    transform: Translate { x: -sysInfoSatellite.xNorm * 5; y: sysInfoSatellite.yNorm * 5 }
                }
                Rectangle {
                    id: sysRPanel
                    width: 55; height: 50
                    anchors.left:              sysCoreChassis.right
                    anchors.leftMargin:        6
                    anchors.verticalCenter: sysCoreChassis.verticalCenter
                    color: root.mantle
                    border.color: Qt.rgba(root.surface2.r, root.surface2.g, root.surface2.b, 0.35)
                    border.width: 1; radius: 4
                    Grid {
                        anchors.fill: parent; anchors.margins: 4; columns: 3; rows: 3; spacing: 2
                        Repeater { model: 9
                            Rectangle {
                                width:  (sysRPanel.width  - 8 - 4) / 3
                                height: (sysRPanel.height - 8 - 4) / 3
                                color: Qt.rgba(root.teal.r, root.teal.g, root.teal.b, index % 2 === 0 ? 0.16 : 0.06)
                                radius: 1
                            }
                        }
                    }
                }
            }
        }

            Item {
                id: musicSatellite

                property real orbitDistance: 1.18
                property real angle: root.musicAngle
                property real b_x: Math.cos(angle) * orbitDistance
                property real b_z: Math.sin(angle) * orbitDistance
                property real b_y: -0.05 + Math.sin(angle * 2.5 + 4.0) * 0.045

                property var proj: root.project3D(b_x, b_y, b_z, true)

                x: (worldCenter.width / 2) + (proj.x * root.sphereRadius) - width / 2
                y: (worldCenter.height / 2) + (proj.y * root.sphereRadius) - height / 2
                z: Math.round(proj.z * 1000)

                opacity: root.isMusicActive ? 1.0 : 0.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutCubic } }

                property real baselineDepthScale: 0.65 + (Math.max(0.0, proj.z) * 0.25)
                property real centerFocusFactor:  (proj.z > 0) ? Math.max(0.0, 1.0 - (Math.abs(proj.x) * 1.6)) : 0.0
                scale: (baselineDepthScale + (centerFocusFactor * 0.12)) * 1.45 * root.satelliteZoom
                Behavior on scale { 
                    enabled: !sceneMouse.pressed
                    NumberAnimation { duration: 500; easing.type: Easing.OutBack } 
                }

                width:  240
                height: 70

                property real xNorm: proj.x / orbitDistance
                property real yNorm: proj.y / orbitDistance

                transform: [
                    Rotation {
                        axis { x: 1; y: 0; z: 0 }
                        angle: -musicSatellite.yNorm * 50
                        origin.x: musicSatellite.width / 2
                        origin.y: musicSatellite.height / 2
                    },
                    Rotation {
                        axis { x: 0; y: 1; z: 0 }
                        angle: musicSatellite.xNorm * 60
                        origin.x: musicSatellite.width / 2
                        origin.y: musicSatellite.height / 2
                    }
                ]

                Rectangle {
                    id: musicExhaust
                    width: 60; height: 25
                    anchors.horizontalCenter: musicChassis.horizontalCenter
                    anchors.top: musicChassis.bottom
                    anchors.topMargin: -2
                    z: -1
                    opacity: 0.25 + Math.sin(root.independentCometAngle * 4 + 4) * 0.05
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(root.green.r, root.green.g, root.green.b, 0.35) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                Rectangle {
                    width: 180; height: 56; anchors.centerIn: parent; radius: 14
                    color: root.crust; border.color: Qt.rgba(root.green.r, root.green.g, root.green.b, 0.2); border.width: 1.2
                    transform: Translate { x: -musicSatellite.xNorm * 8; y: musicSatellite.yNorm * 8 }
                }
                Rectangle {
                    width: 180; height: 56; anchors.centerIn: parent; radius: 14
                    color: root.mantle; border.color: Qt.rgba(root.green.r, root.green.g, root.green.b, 0.35); border.width: 1.2
                    transform: Translate { x: -musicSatellite.xNorm * 4; y: musicSatellite.yNorm * 4 }
                }
                Rectangle {
                    id: musicChassis
                    anchors.centerIn: parent
                    width: 180; height: 56
                    color: Qt.rgba(root.base.r, root.base.g, root.base.b, 0.94)
                    border.color: musicSatellite.centerFocusFactor > 0
                        ? Qt.rgba(root.green.r, root.green.g, root.green.b, 0.5)
                        : Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.5)
                    border.width: 1.2; radius: 14
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 10

                        Rectangle {
                            width: 36; height: 36; radius: 8; color: root.surface1
                            border.width: 1; border.color: root.mauve
                            clip: true
                            Image {
                                anchors.fill: parent
                                source: root.musicData.artUrl || ""
                                fillMode: Image.PreserveAspectCrop
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                text: root.musicData.title || "No Title"
                                font.family: "JetBrains Mono"; font.weight: Font.Black
                                font.pixelSize: 12; color: root.text
                                width: 110; elide: Text.ElideRight
                            }
                            Text {
                                text: root.musicData.timeStr || ""
                                font.family: "JetBrains Mono"; font.weight: Font.Bold
                                font.pixelSize: 10; color: root.subtext0
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["bash", "-c", paths.serpantinumDir + "/scripts/qs_manager.sh toggle music"])
                    }
                }

                Rectangle {
                    id: mLeftWing
                    anchors.right: musicChassis.left; anchors.rightMargin: 4
                    anchors.verticalCenter: musicChassis.verticalCenter
                    width: 24; height: 38; color: root.mantle
                    border.color: Qt.rgba(root.green.r, root.green.g, root.green.b, 0.35)
                    border.width: 1; radius: 2
                    Grid { anchors.fill: parent; anchors.margins: 2; columns: 2; rows: 3; spacing: 1
                        Repeater { model: 6
                            Rectangle {
                                width: (mLeftWing.width - 5) / 2; height: (mLeftWing.height - 6) / 3
                                color: Qt.rgba(root.green.r, root.green.g, root.green.b, index % 2 === 0 ? 0.25 : 0.1)
                            }
                        }
                    }
                }

                Rectangle {
                    id: mRightWing
                    anchors.left: musicChassis.right; anchors.leftMargin: 4
                    anchors.verticalCenter: musicChassis.verticalCenter
                    width: 24; height: 38; color: root.mantle
                    border.color: Qt.rgba(root.green.r, root.green.g, root.green.b, 0.35)
                    border.width: 1; radius: 2
                    Grid { anchors.fill: parent; anchors.margins: 2; columns: 2; rows: 3; spacing: 1
                        Repeater { model: 6
                            Rectangle {
                                width: (mRightWing.width - 5) / 2; height: (mRightWing.height - 6) / 3
                                color: Qt.rgba(root.green.r, root.green.g, root.green.b, index % 2 === 0 ? 0.25 : 0.1)
                            }
                        }
                    }
                }
           }

            Item {
                id: easterEggSatellite
            
                property real orbitDistance: 1.15            
                property real angle: root.easterEggAngle
                property real b_x: Math.cos(angle) * orbitDistance
                property real b_z: Math.sin(angle) * orbitDistance
                property real b_y: 0.18 + Math.sin(angle * 2.2) * 0.04   
            
                property var proj: root.project3D(b_x, b_y, b_z, true)
            
                x: (worldCenter.width / 2) + (proj.x * root.sphereRadius) - width / 2
                y: (worldCenter.height / 2) + (proj.y * root.sphereRadius) - height / 2
                z: Math.round(proj.z * 1000)
            
                opacity: 1.0
                visible: true
            
                property real baselineDepthScale: 0.70 + (Math.max(0.0, proj.z) * 0.25)
                property real centerFocusFactor:  (proj.z > 0) ? Math.max(0.0, 1.0 - (Math.abs(proj.x) * 1.6)) : 0.0
                scale: (baselineDepthScale + (centerFocusFactor * 0.12)) * 1.3 * root.satelliteZoom   
                Behavior on scale { 
                    enabled: !sceneMouse.pressed
                    NumberAnimation { duration: 500; easing.type: Easing.OutBack } 
                }
            
                width:  80
                height: 70
            
                property real xNorm: proj.x / orbitDistance
                property real yNorm: proj.y / orbitDistance
            
                transform: [
                    Rotation {
                        axis { x: 1; y: 0; z: 0 }
                        angle: -easterEggSatellite.yNorm * 55
                        origin.x: easterEggSatellite.width / 2
                        origin.y: easterEggSatellite.height / 2
                    },
                    Rotation {
                        axis { x: 0; y: 1; z: 0 }
                        angle: easterEggSatellite.xNorm * 60
                        origin.x: easterEggSatellite.width / 2
                        origin.y: easterEggSatellite.height / 2
                    }
                ]

                Rectangle {
                    id: eggExhaust
                    width: 30; height: 20
                    anchors.horizontalCenter: eggChassis.horizontalCenter
                    anchors.top: eggChassis.bottom
                    anchors.topMargin: -2
                    z: -1
                    opacity: 0.25 + Math.sin(root.independentCometAngle * 4 + 5) * 0.05
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(root.mauve.r, root.mauve.g, root.mauve.b, 0.35) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
            
                Rectangle {
                    id: eggLeftWing
                    anchors.right: eggChassis.left; anchors.rightMargin: 4
                    anchors.verticalCenter: eggChassis.verticalCenter
                    width: 14; height: 24; color: root.mantle
                    border.color: Qt.rgba(root.mauve.r, root.mauve.g, root.mauve.b, 0.4)
                    border.width: 1; radius: 2
                    Grid {
                        anchors.fill: parent; anchors.margins: 2; columns: 2; rows: 3; spacing: 1
                        Repeater {
                            model: 6
                            Rectangle {
                                width:  (eggLeftWing.width  - 5) / 2
                                height: (eggLeftWing.height - 6) / 3
                                color: Qt.rgba(root.mauve.r, root.mauve.g, root.mauve.b, index % 2 === 0 ? 0.25 : 0.1)
                            }
                        }
                    }
                }
            
                Rectangle {
                    width: 50; height: 40; anchors.centerIn: parent; radius: 8
                    color: root.crust; border.color: Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.2); border.width: 1.2
                    transform: Translate { x: -easterEggSatellite.xNorm * 8; y: easterEggSatellite.yNorm * 8 }
                }
                Rectangle {
                    width: 50; height: 40; anchors.centerIn: parent; radius: 8
                    color: root.mantle; border.color: Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.35); border.width: 1.2
                    transform: Translate { x: -easterEggSatellite.xNorm * 4; y: easterEggSatellite.yNorm * 4 }
                }
                Rectangle {
                    id: eggChassis
                    anchors.centerIn: parent
                    width: 50; height: 40
                    color: Qt.rgba(root.base.r, root.base.g, root.base.b, 0.94)
                    border.color: easterEggSatellite.centerFocusFactor > 0
                        ? Qt.rgba(root.mauve.r, root.mauve.g, root.mauve.b, 0.6)
                        : Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.5)
                    border.width: 1.2; radius: 8
                    Behavior on border.color { ColorAnimation { duration: 150 } }
            
                    Rectangle {
                        width: 3; height: 3; radius: 1.5; color: root.mauve
                        anchors.top: parent.top; anchors.topMargin: 4
                        anchors.right: parent.right; anchors.rightMargin: 5
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite; running: true
                            NumberAnimation { from: 1; to: 0.2; duration: 500; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 0.2; to: 1; duration: 500; easing.type: Easing.InOutSine }
                        }
                    }
            
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
            
                        Image {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 18; height: 18
                            source: "file:///home/ilyamiro/Downloads/hyprland.png"
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                        }
            
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "sup, vaxry"
                            font.family: "JetBrains Mono"
                            font.pixelSize: 7
                            font.weight: Font.Black
                            color: root.text
                        }
                    }
                }
            
                Rectangle {
                    id: eggRightWing
                    anchors.left: eggChassis.right; anchors.leftMargin: 4
                    anchors.verticalCenter: eggChassis.verticalCenter
                    width: 14; height: 24; color: root.mantle
                    border.color: Qt.rgba(root.mauve.r, root.mauve.g, root.mauve.b, 0.4)
                    border.width: 1; radius: 2
                    Grid {
                        anchors.fill: parent; anchors.margins: 2; columns: 2; rows: 3; spacing: 1
                        Repeater {
                            model: 6
                            Rectangle {
                                width:  (eggRightWing.width  - 5) / 2
                                height: (eggRightWing.height - 6) / 3
                                color: Qt.rgba(root.mauve.r, root.mauve.g, root.mauve.b, index % 2 === 0 ? 0.25 : 0.1)
                            }
                        }
                    }
                }
            }
                        
            Item {
                id: traySatellite

                property real orbitDistance: 1.55
                property real angle: root.trayAngle
                property real b_x: Math.cos(angle) * orbitDistance
                property real b_z: Math.sin(angle) * orbitDistance
                property real b_y: -0.30 + Math.sin(angle * 2.2 + 5.0) * 0.06

                property var proj: root.project3D(b_x, b_y, b_z, true)

                x: (worldCenter.width / 2) + (proj.x * root.sphereRadius) - width / 2
                y: (worldCenter.height / 2) + (proj.y * root.sphereRadius) - height / 2
                z: Math.round(proj.z * 1000)

                opacity: 1.0
                visible: true

                property real baselineDepthScale: 0.65 + (Math.max(0.0, proj.z) * 0.25)
                property real centerFocusFactor:  (proj.z > 0) ? Math.max(0.0, 1.0 - (Math.abs(proj.x) * 1.6)) : 0.0
                scale: (baselineDepthScale + (centerFocusFactor * 0.12)) * 1.45 * root.satelliteZoom
                Behavior on scale { 
                    enabled: !sceneMouse.pressed
                    NumberAnimation { duration: 500; easing.type: Easing.OutBack } 
                }

                width:  Math.max(120, trayInnerRow.implicitWidth + 48)
                height: 56

                property real xNorm: proj.x / orbitDistance
                property real yNorm: proj.y / orbitDistance

                transform: [
                    Rotation {
                        axis { x: 1; y: 0; z: 0 }
                        angle: -traySatellite.yNorm * 25
                        origin.x: traySatellite.width / 2
                        origin.y: traySatellite.height / 2
                    },
                    Rotation {
                        axis { x: 0; y: 1; z: 0 }
                        angle: traySatellite.xNorm * 35
                        origin.x: traySatellite.width / 2
                        origin.y: traySatellite.height / 2
                    }
                ]

                Rectangle {
                    id: trayExhaust
                    width: 70; height: 25
                    anchors.horizontalCenter: trayChassis.horizontalCenter
                    anchors.top: trayChassis.bottom
                    anchors.topMargin: -2
                    z: -1
                    opacity: 0.25 + Math.sin(root.independentCometAngle * 4 + 6) * 0.05
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(root.blue.r, root.blue.g, root.blue.b, 0.35) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                Rectangle {
                    id: trayLeftWing
                    anchors.right: trayChassis.left; anchors.rightMargin: 4
                    anchors.verticalCenter: trayChassis.verticalCenter
                    width: 20; height: 34; color: root.mantle
                    border.color: Qt.rgba(root.blue.r, root.blue.g, root.blue.b, 0.35)
                    border.width: 1; radius: 2
                    Grid { anchors.fill: parent; anchors.margins: 2; columns: 2; rows: 3; spacing: 1
                        Repeater { model: 6
                            Rectangle {
                                width: (trayLeftWing.width - 5) / 2; height: (trayLeftWing.height - 6) / 3
                                color: Qt.rgba(root.blue.r, root.blue.g, root.blue.b, index % 2 === 0 ? 0.22 : 0.07)
                            }
                        }
                    }
                }

                Rectangle {
                    width: trayChassis.width; height: 48; anchors.centerIn: parent; radius: 14
                    color: root.crust; border.color: Qt.rgba(root.blue.r, root.blue.g, root.blue.b, 0.2); border.width: 1.2
                    transform: Translate { x: -traySatellite.xNorm * 8; y: traySatellite.yNorm * 8 }
                }
                Rectangle {
                    width: trayChassis.width; height: 48; anchors.centerIn: parent; radius: 14
                    color: root.mantle; border.color: Qt.rgba(root.blue.r, root.blue.g, root.blue.b, 0.35); border.width: 1.2
                    transform: Translate { x: -traySatellite.xNorm * 4; y: traySatellite.yNorm * 4 }
                }
                Rectangle {
                    id: trayChassis
                    anchors.centerIn: parent
                    width: parent.width - 48
                    height: 48
                    color: Qt.rgba(root.base.r, root.base.g, root.base.b, 0.94)
                    border.color: traySatellite.centerFocusFactor > 0
                        ? Qt.rgba(root.blue.r, root.blue.g, root.blue.b, 0.55)
                        : Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.5)
                    border.width: 1.2; radius: 14
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        width: 4; height: 4; radius: 2; color: root.blue
                        anchors.top: parent.top; anchors.topMargin: 5
                        anchors.right: parent.right; anchors.rightMargin: 7
                        SequentialAnimation on opacity { loops: Animation.Infinite; running: true
                            NumberAnimation { from: 1; to: 0.1; duration: 700; easing.type: Easing.OutSine }
                            NumberAnimation { from: 0.1; to: 1; duration: 700; easing.type: Easing.OutSine }
                        }
                    }

                    Text {
                        anchors.top: parent.top; anchors.topMargin: 4
                        anchors.left: parent.left; anchors.leftMargin: 8
                        text: "TRAY"
                        font.family: "JetBrains Mono"; font.pixelSize: 7; font.weight: Font.Black
                        color: root.overlay0
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "TRAY CLEAR"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 10
                        font.weight: Font.Black
                        color: root.subtext0
                        visible: SystemTray.items.length === 0
                    }

                    Row {
                        id: trayInnerRow
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 2
                        spacing: 10

                        Repeater {
                            model: SystemTray.items
                            delegate: Item {
                                id: trayIconItem
                                width: 22; height: 22
                                anchors.verticalCenter: parent.verticalCenter

                                property bool isHovered: trayIconMouse.containsMouse

                                Image {
                                    anchors.fill: parent
                                    source: modelData.icon || ""
                                    fillMode: Image.PreserveAspectFit
                                    sourceSize: Qt.size(22, 22)
                                    smooth: true
                                    opacity: trayIconItem.isHovered ? 1.0 : 0.80
                                    scale: trayIconMouse.pressed ? 0.85 : (trayIconItem.isHovered ? 1.18 : 1.0)
                                    Behavior on scale   { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                }

                                QsMenuAnchor {
                                    id: trayMenuAnchor
                                    anchor.window: root
                                    anchor.item: trayIconItem
                                    menu: modelData.menu
                                }

                                MouseArea {
                                    id: trayIconMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.LeftButton) {
                                            if (modelData.isMenuOnly || modelData.onlyMenu) {
                                                trayMenuAnchor.open();
                                            } else if (typeof modelData.activate === "function") {
                                                modelData.activate();
                                            }
                                        } else if (mouse.button === Qt.MiddleButton) {
                                            if (typeof modelData.secondaryActivate === "function") {
                                                modelData.secondaryActivate();
                                            }
                                        } else if (mouse.button === Qt.RightButton) {
                                            if (modelData.menu) {
                                                trayMenuAnchor.open();
                                            } else if (typeof modelData.activate === "function") {
                                                modelData.activate();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: trayRightWing
                        anchors.left: trayChassis.right; anchors.leftMargin: 4
                        anchors.verticalCenter: trayChassis.verticalCenter
                        width: 20; height: 34; color: root.mantle
                        border.color: Qt.rgba(root.blue.r, root.blue.g, root.blue.b, 0.35)
                        border.width: 1; radius: 2
                        Grid { anchors.fill: parent; anchors.margins: 2; columns: 2; rows: 3; spacing: 1
                            Repeater { model: 6
                                Rectangle {
                                    width: (trayRightWing.width - 5) / 2; height: (trayRightWing.height - 6) / 3
                                    color: Qt.rgba(root.blue.r, root.blue.g, root.blue.b, index % 2 === 0 ? 0.22 : 0.07)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

