// Caelestia Blush splash 1.2.0-alpha (Vymnkoo)
// 1.2.0-alpha: text shows instantly, outro waits for a minimum on-screen time, stages logged
// 1.1.0-alpha: "please wait" line in Orbitron with an opening letter-spacing animation
// Opens on the blurred wallpaper (same image as SDDM + desktop), shows a
// clock + greeting, then un-blurs onto the exact desktop wallpaper so the
// hand-off to Plasma is seamless.
import QtQuick
import QtQuick.Effects

Rectangle {
    id: root
    color: "#f5ecef"            // wallpaper base colour, never black
    property int stage
    readonly property color ink: "#3b2a31"
    readonly property color accent: Qt.rgba(176/255, 104/255, 130/255, 1)

    property bool ready: false        // Plasma says the desktop is up
    property bool minShown: false     // text has been readable long enough
    function tryOutro() { if (ready && minShown && !outro.running && !outroDone) outro.start() }
    onStageChanged: {
        console.log("caelestia-splash: stage", stage, "at", Date.now() - startTime, "ms")
        if (stage >= 5) { ready = true; tryOutro() }
    }
    readonly property double startTime: Date.now()
    Timer { interval: 1300; running: true; onTriggered: { root.minShown = true; root.tryOutro() } }
    property bool outroDone: false

    // --- wallpaper -------------------------------------------------------
    Image {
        id: wall
        anchors.fill: parent
        source: "images/background.jpg"
        fillMode: Image.PreserveAspectCrop
        visible: false
        cache: false
    }
    MultiEffect {
        id: wallFx
        source: wall
        anchors.fill: parent
        blurEnabled: true
        blurMax: 64
        blur: 1.0
        saturation: 0.0
        brightness: 0.0
        scale: 1.08
        opacity: 0
        transformOrigin: Item.Center
    }

    // --- centre content ----------------------------------------------------
    Column {
        id: content
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 24
        spacing: 10
        opacity: 0

        Text {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.ink
            font.pixelSize: 96
            font.weight: Font.Light
            font.letterSpacing: 2
            text: Qt.formatTime(new Date(), "hh:mm")
            Timer { interval: 1000; running: true; repeat: true
                    onTriggered: clock.text = Qt.formatTime(new Date(), "hh:mm") }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.ink
            opacity: 0.8
            font.pixelSize: 22
            text: {
                const h = new Date().getHours()
                const part = h < 5 ? "Good night" : h < 12 ? "Good morning"
                           : h < 18 ? "Good afternoon" : "Good evening"
                return part + ", Vymnkoo"
            }
        }
        Item { width: 1; height: 22 }
        Text {
            id: wait
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.accent
            font.family: "Orbitron"
            font.pixelSize: 15
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0
            text: "please wait"
            NumberAnimation on font.letterSpacing {
                from: 0; to: 9; duration: 900; easing.type: Easing.OutCubic
            }
        }
        Item { width: 1; height: 6 }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            Repeater {
                model: 3
                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: root.accent
                    opacity: 0.25
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        PauseAnimation { duration: index * 180 }
                        NumberAnimation { to: 1; duration: 420; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.25; duration: 420; easing.type: Easing.InOutSine }
                        PauseAnimation { duration: (2 - index) * 180 }
                    }
                }
            }
        }
    }

    // --- intro: starts immediately ----------------------------------------
    ParallelAnimation {
        running: true
        NumberAnimation { target: wallFx; property: "opacity"; to: 1; duration: 350; easing.type: Easing.OutCubic }
        NumberAnimation { target: wallFx; property: "scale"; to: 1.03; duration: 2200; easing.type: Easing.OutCubic }
        SequentialAnimation {
            PauseAnimation { duration: 0 }
            ParallelAnimation {
                NumberAnimation { target: content; property: "opacity"; to: 1; duration: 350; easing.type: Easing.OutCubic }
                NumberAnimation { target: content; property: "anchors.verticalCenterOffset"; to: 0; duration: 500; easing.type: Easing.OutCubic }
            }
        }
    }

    // --- outro: desktop is ready -> land on the real wallpaper --------------
    ParallelAnimation {
        id: outro
        onFinished: root.outroDone = true
        NumberAnimation { target: content; property: "opacity"; to: 0; duration: 450; easing.type: Easing.InCubic }
        NumberAnimation { target: content; property: "anchors.verticalCenterOffset"; to: -30; duration: 450; easing.type: Easing.InCubic }
        NumberAnimation { target: wallFx; property: "blur"; to: 0; duration: 700; easing.type: Easing.InOutCubic }
        NumberAnimation { target: wallFx; property: "scale"; to: 1.0; duration: 700; easing.type: Easing.InOutCubic }
    }
}
