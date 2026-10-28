pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: root
    property var appBackend: backend
    width: 1180
    height: 760
    minimumWidth: compactMode ? 390 : 980
    minimumHeight: compactMode ? 580 : 660
    visible: true
    color: "transparent"
    title: "Jarvis PC"
    flags: Qt.Window | Qt.FramelessWindowHint

    property string robotState: "loading"
    property string systemStatus: "Инициализация"
    property real audioLevel: 0
    property real wavePhase: 0
    property bool settingsOpen: false
    property bool compactMode: false
    property int savedWidth: 1180
    property int savedHeight: 760
    property int savedX: 100
    property int savedY: 100

    readonly property color stateColor: {
        switch (robotState) {
        case "listening": return "#50c8ff"
        case "thinking": return "#9b87ff"
        case "executing": return "#ffc35c"
        case "success": return "#56d6a1"
        case "error": return "#ff6978"
        case "loading": return "#5d8cff"
        default: return "#65bdf2"
        }
    }

    readonly property string stateTitle: {
        switch (robotState) {
        case "listening": return "СЛУШАЮ"
        case "thinking": return "ДУМАЮ"
        case "executing": return "ВЫПОЛНЯЮ"
        case "success": return "ГОТОВО"
        case "error": return "ОШИБКА"
        case "loading": return "ЗАГРУЗКА"
        default: return "ОЖИДАНИЕ"
        }
    }

    function sendCommand() {
        const command = commandInput.text.trim()
        if (command.length === 0)
            return
        root.appBackend.executeCommand(command)
        commandInput.text = ""
    }

    function addToast(title, message, kind) {
        toastModel.insert(0, {"title": title, "message": message, "kind": kind})
        if (toastModel.count > 4)
            toastModel.remove(4)
    }

    function toggleCompact() {
        if (!compactMode) {
            savedWidth = width
            savedHeight = height
            savedX = x
            savedY = y
            root.appBackend.restoreWindow()
            compactMode = true
            Qt.callLater(function() {
                root.width = 430
                root.height = 650
            })
        } else {
            compactMode = false
            Qt.callLater(function() {
                root.width = savedWidth
                root.height = savedHeight
                root.x = savedX
                root.y = savedY
            })
        }
    }

    function openSettings() {
        settingsOpen = !settingsOpen
        if (settingsOpen)
            settingsPage.loadValues()
    }

    function stopStateAnimations() {
        successAnimation.stop()
        errorAnimation.stop()
        eventMotion.eventX = 0
        eventMotion.eventY = 0
        eventMotion.eventScale = 1
        if (robotState !== "thinking")
            eventMotion.thinkAngle = 0
        if (robotState !== "executing")
            eventMotion.executeOffset = 0
    }

    onRobotStateChanged: {
        stopStateAnimations()
        if (robotState === "success")
            successAnimation.start()
        else if (robotState === "error")
            errorAnimation.start()
    }

    Behavior on audioLevel { NumberAnimation { duration: 75 } }

    component WindowControl: Rectangle {
        property string symbol: ""
        property bool danger: false
        signal clicked()
        width: 34
        height: 28
        radius: 8
        color: controlMouse.containsMouse ? (danger ? "#7b3038" : "#252a32") : "transparent"

        Text {
            anchors.centerIn: parent
            text: parent.symbol
            color: parent.danger && controlMouse.containsMouse ? "#ffffff" : "#929aa8"
            font.pixelSize: 14
        }
        MouseArea {
            id: controlMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: parent.clicked()
        }
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    component ModeButton: Rectangle {
        id: modeButton
        property string title: ""
        property string subtitle: ""
        property color accent: "#5db8ff"
        signal clicked()
        width: parent ? parent.width : 220
        height: 62
        radius: 14
        color: modeMouse.containsMouse ? "#20242b" : "#171a20"
        border.width: 1
        border.color: modeMouse.containsMouse ? accent : "#252932"

        Rectangle {
            x: 13
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 34
            radius: 11
            color: Qt.rgba(modeButton.accent.r, modeButton.accent.g, modeButton.accent.b, 0.12)
            Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: modeButton.accent }
        }
        Column {
            x: 58
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Text { text: modeButton.title; color: "#f3f5f7"; font.pixelSize: 14; font.weight: Font.DemiBold }
            Text { text: modeButton.subtitle; color: "#747c8b"; font.pixelSize: 10 }
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 15
            anchors.verticalCenter: parent.verticalCenter
            text: "›"
            color: modeMouse.containsMouse ? modeButton.accent : "#5f6672"
            font.pixelSize: 23
        }
        MouseArea {
            id: modeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: modeButton.clicked()
        }
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    component SettingLabel: Text {
        color: "#a8afba"
        font.pixelSize: 12
        font.weight: Font.DemiBold
    }

    Rectangle {
        id: shell
        anchors.fill: parent
        radius: root.visibility === Window.Maximized || root.visibility === Window.FullScreen ? 0 : 14
        color: "#0d0f13"
        border.width: 1
        border.color: "#282c35"
        clip: true

        Rectangle {
            id: titleBar
            x: 1
            y: 1
            width: parent.width - 2
            height: 46
            color: "#101217"

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                property point previousPosition
                onPressed: function(mouse) { previousPosition = Qt.point(mouse.x, mouse.y) }
                onPositionChanged: function(mouse) {
                    if (!pressed || root.visibility === Window.Maximized || root.visibility === Window.FullScreen)
                        return
                    root.x += mouse.x - previousPosition.x
                    root.y += mouse.y - previousPosition.y
                }
                onDoubleClicked: root.appBackend.toggleMaximize()
            }

            Row {
                x: 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9
                Rectangle { width: 9; height: 9; radius: 5; color: "#3b414c" }
                Rectangle { width: 9; height: 9; radius: 5; color: "#3b414c" }
                Rectangle { width: 9; height: 9; radius: 5; color: root.stateColor }
            }

            Text {
                anchors.centerIn: parent
                text: settingsOpen ? "НАСТРОЙКИ JARVIS" : "JARVIS PC"
                color: "#737b88"
                font.pixelSize: 11
                font.letterSpacing: 2.2
                font.weight: Font.DemiBold
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                z: 3
                WindowControl { symbol: "⚙"; onClicked: root.openSettings() }
                WindowControl { symbol: root.compactMode ? "▣" : "◱"; onClicked: root.toggleCompact() }
                WindowControl { symbol: "⛶"; onClicked: root.appBackend.toggleFullscreen() }
                WindowControl { symbol: "⌄"; onClicked: root.appBackend.hideToTray() }
                WindowControl { symbol: "—"; onClicked: root.appBackend.minimizeWindow() }
                WindowControl { symbol: "×"; danger: true; onClicked: root.appBackend.closeApplication() }
            }
        }

        Rectangle {
            id: sidebar
            x: 1
            y: titleBar.height
            width: root.compactMode ? 0 : 262
            height: shell.height - titleBar.height - 1
            visible: !root.compactMode
            color: "#111318"
            clip: true

            Column {
                x: 18
                y: 22
                width: parent.width - 36
                spacing: 12

                Row {
                    width: parent.width
                    height: 44
                    spacing: 12
                    Rectangle {
                        width: 40; height: 40; radius: 13
                        color: "#172532"; border.width: 1; border.color: "#285172"
                        Text { anchors.centerIn: parent; text: "J"; color: "#78c8ff"; font.pixelSize: 18; font.weight: Font.Bold }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text { text: "Джарвис"; color: "#f2f4f7"; font.pixelSize: 16; font.weight: Font.DemiBold }
                        Text { text: "Персональный ассистент"; color: "#6f7785"; font.pixelSize: 10 }
                    }
                }
                Rectangle { width: parent.width; height: 1; color: "#22262e" }
                Text { text: "РЕЖИМЫ"; color: "#59616f"; font.pixelSize: 10; font.letterSpacing: 1.5 }
                ModeButton {
                    title: "Игровой"; subtitle: "Discord · Steam · Музыка"; accent: "#61c4ff"
                    onClicked: root.appBackend.activateMode("gaming")
                }
                ModeButton {
                    title: "Рабочий"; subtitle: "VS Code · ChatGPT · Telegram"; accent: "#9b87ff"
                    onClicked: root.appBackend.activateMode("work")
                }
                ModeButton {
                    title: "Отдых"; subtitle: "Фильм на Кинопоиске"; accent: "#56d6a1"
                    onClicked: root.appBackend.activateMode("leisure")
                }
                Text { text: "ПОСЛЕДНИЕ КОМАНДЫ"; color: "#59616f"; font.pixelSize: 10; font.letterSpacing: 1.5 }
                ListView {
                    id: historyList
                    width: parent.width
                    height: Math.min(contentHeight, 150)
                    model: historyModel
                    spacing: 3
                    interactive: false
                    delegate: Rectangle {
                        required property string command
                        required property bool success
                        width: historyList.width; height: 34; radius: 9; color: "transparent"
                        Rectangle {
                            x: 3; anchors.verticalCenter: parent.verticalCenter
                            width: 5; height: 5; radius: 3
                            color: success ? "#56d6a1" : "#ff6978"
                        }
                        Text {
                            x: 17; anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 24; text: command
                            color: "#89919f"; font.pixelSize: 11; elide: Text.ElideRight
                        }
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 58; color: "#0f1115"
                Row {
                    x: 19; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                    Rectangle {
                        width: 9; height: 9; radius: 5; color: root.stateColor
                        SequentialAnimation on opacity {
                            running: ["loading", "listening", "thinking", "executing"].indexOf(root.robotState) >= 0
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 520 }
                            NumberAnimation { to: 1.0; duration: 520 }
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 1
                        Text { text: root.stateTitle; color: root.stateColor; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.2 }
                        Text { text: root.systemStatus; color: "#858d9a"; font.pixelSize: 10 }
                    }
                }
            }
        }

        Rectangle {
            id: content
            x: sidebar.width
            y: titleBar.height
            width: shell.width - sidebar.width - 1
            height: shell.height - titleBar.height - 1
            color: "#0d0f13"

            Item {
                id: assistantPage
                anchors.fill: parent
                visible: !root.settingsOpen

                Item {
                    id: heroStage
                    anchors.fill: parent
                    anchors.bottomMargin: 112

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.compactMode ? 18 : 28
                        spacing: 5
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.stateTitle
                            color: root.stateColor
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 2.3
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.robotState === "idle" ? "Чем могу помочь?" : root.systemStatus
                            color: "#f1f3f6"
                            font.pixelSize: root.compactMode ? 18 : 23
                            font.weight: Font.DemiBold
                        }
                    }

                    Rectangle {
                        anchors.centerIn: robotEntrance
                        width: robotEntrance.width * 0.96
                        height: width
                        radius: width / 2
                        color: Qt.rgba(root.stateColor.r, root.stateColor.g, root.stateColor.b, root.robotState === "idle" ? 0.045 : 0.085)
                        border.width: 1
                        border.color: Qt.rgba(root.stateColor.r, root.stateColor.g, root.stateColor.b, 0.35)
                        scale: root.robotState === "listening" ? 1.08 : 1.0
                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    }

                    Rectangle {
                        anchors.centerIn: robotEntrance
                        width: robotEntrance.width * 1.15
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(root.stateColor.r, root.stateColor.g, root.stateColor.b, 0.28)
                        opacity: root.robotState === "idle" ? 0.25 : 0.8
                        SequentialAnimation on scale {
                            running: root.robotState === "listening" || root.robotState === "executing"
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.95; to: 1.06; duration: 720; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 1.06; to: 0.95; duration: 720; easing.type: Easing.InOutSine }
                        }
                    }

                    Item {
                        id: robotEntrance
                        width: root.compactMode ? Math.min(292, heroStage.width * 0.72) : 390
                        height: root.compactMode ? Math.min(390, heroStage.height - 90) : Math.min(heroStage.height - 98, 510)
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: root.compactMode ? 18 : 34
                        opacity: 0
                        property real introOffset: 440
                        property real introScale: 0.72
                        property real tiltX: 0
                        property real tiltY: 0

                        transform: [
                            Translate { y: robotEntrance.introOffset },
                            Scale {
                                origin.x: robotEntrance.width / 2; origin.y: robotEntrance.height / 2
                                xScale: robotEntrance.introScale; yScale: robotEntrance.introScale
                            },
                            Rotation {
                                origin.x: robotEntrance.width / 2; origin.y: robotEntrance.height / 2
                                axis { x: 0; y: 1; z: 0 }
                                angle: robotEntrance.tiltY
                            },
                            Rotation {
                                origin.x: robotEntrance.width / 2; origin.y: robotEntrance.height / 2
                                axis { x: 1; y: 0; z: 0 }
                                angle: robotEntrance.tiltX
                            }
                        ]

                        Item {
                            id: eventMotion
                            anchors.fill: parent
                            property real eventX: 0
                            property real eventY: 0
                            property real eventScale: 1
                            property real thinkAngle: 0
                            property real executeOffset: 0
                            transform: [
                                Translate { x: eventMotion.eventX; y: eventMotion.eventY + eventMotion.executeOffset },
                                Scale {
                                    origin.x: eventMotion.width / 2; origin.y: eventMotion.height / 2
                                    xScale: eventMotion.eventScale; yScale: eventMotion.eventScale
                                },
                                Rotation {
                                    origin.x: eventMotion.width / 2; origin.y: eventMotion.height / 2
                                    axis { x: 0; y: 1; z: 0 }
                                    angle: eventMotion.thinkAngle
                                }
                            ]

                            Item {
                                id: floatingRobot
                                anchors.fill: parent
                                property real floatOffset: 0
                                transform: Translate { y: floatingRobot.floatOffset }
                                Image {
                                    anchors.fill: parent
                                    source: "assets/jarvis-robot.png"
                                    fillMode: Image.PreserveAspectFit
                                    mipmap: true
                                    smooth: true
                                }
                                SequentialAnimation on floatOffset {
                                    running: true; loops: Animation.Infinite
                                    NumberAnimation { from: -5; to: 7; duration: root.robotState === "listening" ? 1300 : 2300; easing.type: Easing.InOutSine }
                                    NumberAnimation { from: 7; to: -5; duration: root.robotState === "listening" ? 1300 : 2300; easing.type: Easing.InOutSine }
                                }
                            }

                            SequentialAnimation on thinkAngle {
                                running: root.robotState === "thinking"; loops: Animation.Infinite
                                NumberAnimation { from: -5; to: 5; duration: 520; easing.type: Easing.InOutSine }
                                NumberAnimation { from: 5; to: -5; duration: 520; easing.type: Easing.InOutSine }
                            }
                            SequentialAnimation on executeOffset {
                                running: root.robotState === "executing"; loops: Animation.Infinite
                                NumberAnimation { from: 0; to: -9; duration: 340; easing.type: Easing.OutCubic }
                                NumberAnimation { from: -9; to: 0; duration: 340; easing.type: Easing.InCubic }
                            }
                        }

                        ParallelAnimation {
                            id: entranceAnimation
                            NumberAnimation { target: robotEntrance; property: "introOffset"; from: 440; to: 0; duration: 1050; easing.type: Easing.OutBack }
                            NumberAnimation { target: robotEntrance; property: "introScale"; from: 0.72; to: 1; duration: 980; easing.type: Easing.OutCubic }
                            NumberAnimation { target: robotEntrance; property: "opacity"; from: 0; to: 1; duration: 620; easing.type: Easing.OutCubic }
                        }
                        SequentialAnimation {
                            id: successAnimation
                            ParallelAnimation {
                                NumberAnimation { target: eventMotion; property: "eventScale"; to: 1.09; duration: 190; easing.type: Easing.OutBack }
                                NumberAnimation { target: eventMotion; property: "eventY"; to: -14; duration: 190; easing.type: Easing.OutCubic }
                            }
                            ParallelAnimation {
                                NumberAnimation { target: eventMotion; property: "eventScale"; to: 1; duration: 320; easing.type: Easing.OutBounce }
                                NumberAnimation { target: eventMotion; property: "eventY"; to: 0; duration: 320; easing.type: Easing.OutBounce }
                            }
                        }
                        SequentialAnimation {
                            id: errorAnimation
                            NumberAnimation { target: eventMotion; property: "eventX"; to: -12; duration: 70 }
                            NumberAnimation { target: eventMotion; property: "eventX"; to: 12; duration: 90 }
                            NumberAnimation { target: eventMotion; property: "eventX"; to: -8; duration: 80 }
                            NumberAnimation { target: eventMotion; property: "eventX"; to: 8; duration: 80 }
                            NumberAnimation { target: eventMotion; property: "eventX"; to: 0; duration: 90 }
                        }

                        Behavior on tiltX { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on tiltY { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Component.onCompleted: entranceAnimation.start()
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        onPositionChanged: function(mouse) {
                            const nx = (mouse.x - width / 2) / (width / 2)
                            const ny = (mouse.y - height / 2) / (height / 2)
                            robotEntrance.tiltY = Math.max(-6, Math.min(6, nx * 6))
                            robotEntrance.tiltX = Math.max(-4, Math.min(4, -ny * 4))
                        }
                        onExited: {
                            robotEntrance.tiltX = 0
                            robotEntrance.tiltY = 0
                        }
                    }

                    Row {
                        id: waveform
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 3
                        spacing: 3
                        height: 58
                        opacity: root.robotState === "listening" ? 1 : 0
                        visible: opacity > 0
                        Repeater {
                            model: root.compactMode ? 25 : 38
                            Rectangle {
                                required property int index
                                width: 3
                                radius: 2
                                anchors.verticalCenter: parent.verticalCenter
                                color: root.stateColor
                                height: Math.max(3, 4 + root.audioLevel * 50 * (0.35 + 0.65 * Math.abs(Math.sin(index * 0.62 + root.wavePhase))))
                                Behavior on height { NumberAnimation { duration: 65 } }
                            }
                        }
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                    }
                }

                Rectangle {
                    id: composer
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.leftMargin: root.compactMode ? 20 : 58
                    anchors.rightMargin: root.compactMode ? 20 : 58
                    anchors.bottomMargin: 27
                    height: 72; radius: 22
                    color: "#171a20"; border.width: 1
                    border.color: commandInput.activeFocus ? root.stateColor : "#2a2e37"

                    Rectangle {
                        x: 15; anchors.verticalCenter: parent.verticalCenter
                        width: 42; height: 42; radius: 14
                        color: micMouse.pressed || root.robotState === "listening" ? Qt.darker(root.stateColor, 1.45) : "#1b2730"
                        Text { anchors.centerIn: parent; text: root.robotState === "listening" ? "■" : "●"; color: root.stateColor; font.pixelSize: 14 }
                        MouseArea {
                            id: micMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.appBackend.listenCommand()
                        }
                    }
                    TextField {
                        id: commandInput
                        x: 69; anchors.right: sendButton.left; anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter; height: 48
                        color: "#e7eaf0"; placeholderText: root.compactMode ? "Команда..." : "Введите команду для Джарвиса..."
                        placeholderTextColor: "#656d79"; font.pixelSize: 14
                        selectionColor: "#285b7b"; background: Rectangle { color: "transparent" }
                        onAccepted: root.sendCommand()
                    }
                    Rectangle {
                        id: sendButton
                        anchors.right: parent.right; anchors.rightMargin: 15; anchors.verticalCenter: parent.verticalCenter
                        width: 42; height: 42; radius: 14
                        color: sendMouse.containsMouse ? Qt.lighter(root.stateColor, 1.12) : root.stateColor
                        Text { anchors.centerIn: parent; text: "↑"; color: "#071018"; font.pixelSize: 21; font.weight: Font.Bold }
                        MouseArea {
                            id: sendMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.sendCommand()
                        }
                    }
                }
            }

            Rectangle {
                id: settingsPage
                anchors.fill: parent
                visible: root.settingsOpen
                color: "#0d0f13"

                function findValue(model, value) {
                    for (let i = 0; i < model.count; ++i) {
                        if (String(model.get(i).value) === String(value))
                            return i
                    }
                    return model.count > 0 ? 0 : -1
                }

                function loadValues() {
                    const data = root.appBackend.getSettings()
                    microphoneModel.clear()
                    voiceModel.clear()
                    for (let i = 0; i < data.microphones.length; ++i)
                        microphoneModel.append(data.microphones[i])
                    for (let j = 0; j < data.voices.length; ++j)
                        voiceModel.append(data.voices[j])
                    microphoneCombo.currentIndex = findValue(microphoneModel, data.device)
                    voiceCombo.currentIndex = findValue(voiceModel, data.voice)
                    volumeSlider.value = data.volume
                    rateSlider.value = data.rate
                    hotkeyField.text = data.hotkey
                    exitHotkeyField.text = data.exitHotkey
                }

                ScrollView {
                    id: settingsScroll
                    anchors.fill: parent
                    anchors.margins: root.compactMode ? 20 : 42
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    Column {
                        width: settingsScroll.availableWidth
                        spacing: 18

                        Row {
                            width: parent.width; height: 54
                            Column {
                                spacing: 4
                                Text { text: "Настройки"; color: "#f3f5f7"; font.pixelSize: 24; font.weight: Font.DemiBold }
                                Text { text: "Голос, микрофон и горячие клавиши"; color: "#747c8b"; font.pixelSize: 11 }
                            }
                            Item { width: Math.max(0, parent.width - 300); height: 1 }
                            Button {
                                text: "Назад"
                                onClicked: root.settingsOpen = false
                            }
                        }

                        Rectangle {
                            width: parent.width; height: 190; radius: 18
                            color: "#15181e"; border.width: 1; border.color: "#272c35"
                            Column {
                                anchors.fill: parent; anchors.margins: 20; spacing: 12
                                Text { text: "Аудиовход"; color: "#eef1f5"; font.pixelSize: 16; font.weight: Font.DemiBold }
                                SettingLabel { text: "Микрофон" }
                                ComboBox {
                                    id: microphoneCombo
                                    width: parent.width; height: 42
                                    model: ListModel { id: microphoneModel }
                                    textRole: "label"; valueRole: "value"
                                }
                                Text { text: "Изменение применяется после сохранения."; color: "#67707e"; font.pixelSize: 10 }
                            }
                        }

                        Rectangle {
                            width: parent.width; height: 260; radius: 18
                            color: "#15181e"; border.width: 1; border.color: "#272c35"
                            Column {
                                anchors.fill: parent; anchors.margins: 20; spacing: 11
                                Text { text: "Голос Джарвиса"; color: "#eef1f5"; font.pixelSize: 16; font.weight: Font.DemiBold }
                                SettingLabel { text: "Системный голос" }
                                ComboBox {
                                    id: voiceCombo
                                    width: parent.width; height: 42
                                    model: ListModel { id: voiceModel }
                                    textRole: "label"; valueRole: "value"
                                }
                                Row {
                                    width: parent.width; spacing: 14
                                    SettingLabel { width: 105; text: "Громкость " + Math.round(volumeSlider.value) + "%" }
                                    Slider { id: volumeSlider; width: parent.width - 119; from: 0; to: 100; value: 100 }
                                }
                                Row {
                                    width: parent.width; spacing: 14
                                    SettingLabel { width: 105; text: "Скорость " + Math.round(rateSlider.value) }
                                    Slider { id: rateSlider; width: parent.width - 119; from: 80; to: 260; stepSize: 5; value: 165 }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width; height: 225; radius: 18
                            color: "#15181e"; border.width: 1; border.color: "#272c35"
                            Column {
                                anchors.fill: parent; anchors.margins: 20; spacing: 11
                                Text { text: "Горячие клавиши"; color: "#eef1f5"; font.pixelSize: 16; font.weight: Font.DemiBold }
                                SettingLabel { text: "Активация голоса" }
                                TextField {
                                    id: hotkeyField; width: parent.width; height: 40
                                    color: "#e8ebf0"; background: Rectangle { radius: 10; color: "#0f1217"; border.width: 1; border.color: "#2d323c" }
                                }
                                SettingLabel { text: "Полный выход" }
                                TextField {
                                    id: exitHotkeyField; width: parent.width; height: 40
                                    color: "#e8ebf0"; background: Rectangle { radius: 10; color: "#0f1217"; border.width: 1; border.color: "#2d323c" }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width; height: 54; radius: 15
                            color: saveMouse.containsMouse ? "#68c8ff" : "#50b7f0"
                            Text { anchors.centerIn: parent; text: "Сохранить настройки"; color: "#061017"; font.pixelSize: 14; font.weight: Font.Bold }
                            MouseArea {
                                id: saveMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.appBackend.saveSettings({
                                        "device": microphoneCombo.currentValue,
                                        "voice": voiceCombo.currentValue,
                                        "volume": volumeSlider.value,
                                        "rate": rateSlider.value,
                                        "hotkey": hotkeyField.text,
                                        "exitHotkey": exitHotkeyField.text
                                    })
                                }
                            }
                        }
                        Item { width: 1; height: 18 }
                    }
                }
            }
        }
    }

    ListModel { id: historyModel }
    ListModel { id: toastModel }

    ListView {
        id: toastList
        z: 20
        width: root.compactMode ? root.width - 30 : 330
        height: Math.min(contentHeight, root.height - 80)
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.top: parent.top
        anchors.topMargin: 58
        spacing: 9
        model: toastModel
        interactive: false

        delegate: Rectangle {
            id: toastCard
            required property int index
            required property string title
            required property string message
            required property string kind
            width: toastList.width
            height: 76
            radius: 15
            color: "#1b1f26"
            border.width: 1
            border.color: kind === "success" ? "#315f50" : kind === "error" ? "#66363d" : "#665735"
            opacity: 0
            transform: Translate { id: toastTranslate; x: 36 }

            Rectangle {
                x: 12; anchors.verticalCenter: parent.verticalCenter
                width: 34; height: 34; radius: 11
                color: toastCard.kind === "success" ? "#18382e" : toastCard.kind === "error" ? "#3b2025" : "#3b321d"
                Text {
                    anchors.centerIn: parent
                    text: toastCard.kind === "success" ? "✓" : toastCard.kind === "error" ? "!" : "i"
                    color: toastCard.kind === "success" ? "#56d6a1" : toastCard.kind === "error" ? "#ff7b87" : "#ffc35c"
                    font.pixelSize: 16; font.weight: Font.Bold
                }
            }
            Column {
                x: 58; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 72; spacing: 3
                Text { text: toastCard.title; color: "#f1f3f6"; font.pixelSize: 12; font.weight: Font.DemiBold }
                Text { text: toastCard.message; width: parent.width; color: "#8c94a1"; font.pixelSize: 10; elide: Text.ElideRight }
            }
            ParallelAnimation {
                id: toastIn
                NumberAnimation { target: toastCard; property: "opacity"; from: 0; to: 1; duration: 220 }
                NumberAnimation { target: toastTranslate; property: "x"; from: 36; to: 0; duration: 280; easing.type: Easing.OutCubic }
            }
            Timer {
                interval: 4200; running: true
                onTriggered: if (toastCard.index >= 0 && toastCard.index < toastModel.count) toastModel.remove(toastCard.index)
            }
            Component.onCompleted: toastIn.start()
        }
    }

    Timer {
        interval: 50
        running: root.robotState === "listening"
        repeat: true
        onTriggered: root.wavePhase += 0.34
    }

    Connections {
        target: root.appBackend
        function onStatusChanged(status, kind) {
            root.systemStatus = status
            if (["idle", "loading", "listening", "thinking", "executing", "success", "error"].indexOf(kind) >= 0)
                root.robotState = kind
        }
        function onRobotStateChanged(state) { root.robotState = state }
        function onAudioLevelChanged(level) { root.audioLevel = level }
        function onRecognized(text) { if (text.length > 0) commandInput.text = text }
        function onCommandFinished(command, success, payload) {
            historyModel.insert(0, {"command": command, "success": success})
            if (historyModel.count > 4) historyModel.remove(4)
        }
        function onToastRequested(title, message, kind) { root.addToast(title, message, kind) }
        function onSettingsSaved(success, message) {
            if (success) root.settingsOpen = false
        }
        function onInitializationFinished(success, message) {
            root.robotState = success ? "idle" : "error"
        }
    }
}
