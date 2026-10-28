from __future__ import annotations

import argparse
import json
import sys
import threading
import time
from dataclasses import asdict
from pathlib import Path
from typing import Any

from .core import Assistant, Launcher, load_config, log
from .speech import KeyboardInput, create_input, create_voice, list_microphones, list_voices


ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "config" / "jarvis.json"
UI_PATH = ROOT / "ui" / "Main.qml"
ROBOT_PATH = ROOT / "ui" / "assets" / "jarvis-robot.png"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Jarvis PC desktop application")
    parser.add_argument("--mic", help="Индекс или имя микрофона")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)

    try:
        from PySide6.QtCore import QObject, QTimer, QUrl, Signal, Slot
        from PySide6.QtGui import QAction, QGuiApplication, QIcon, QWindow
        from PySide6.QtQml import QQmlApplicationEngine
        from PySide6.QtWidgets import QApplication, QMenu, QSystemTrayIcon
    except ImportError:
        print("PySide6 не установлен. Повторно запустите .\\setup.ps1")
        return 2

    class Backend(QObject):
        statusChanged = Signal(str, str)
        robotStateChanged = Signal(str)
        audioLevelChanged = Signal(float)
        recognized = Signal(str)
        commandFinished = Signal(str, bool, "QVariant")
        initializationFinished = Signal(bool, str)
        toastRequested = Signal(str, str, str)
        settingsSaved = Signal(bool, str)

        def __init__(self, config: dict[str, Any]) -> None:
            super().__init__()
            self.config = config
            self.launcher = Launcher(config)
            self.voice = create_voice(config)
            self.assistant = Assistant(config, self.launcher, self.voice)
            self.command_input = None
            self.window = None
            self.tray = None
            self.hotkey_updater = None
            self._busy = threading.Lock()
            self._state_version = 0

        def set_window(self, window) -> None:
            self.window = window

        def set_tray(self, tray) -> None:
            self.tray = tray

        def _start_thread(self, target) -> None:
            threading.Thread(target=target, daemon=True).start()

        def _set_state(self, state: str, message: str) -> int:
            self._state_version += 1
            version = self._state_version
            self.robotStateChanged.emit(state)
            self.statusChanged.emit(message, state)
            return version

        def _schedule_idle(self, delay: float = 1.5) -> None:
            version = self._state_version

            def reset() -> None:
                if version == self._state_version:
                    self._set_state("idle", "Система готова")

            timer = threading.Timer(delay, reset)
            timer.daemon = True
            timer.start()

        def _finish_result(self, command: str, result) -> None:
            payload = asdict(result)
            self.commandFinished.emit(command, result.success, payload)
            if result.success:
                self._set_state("success", "Готово")
                self.toastRequested.emit("Команда выполнена", command, "success")
            else:
                self._set_state("error", "Не удалось выполнить")
                self.toastRequested.emit("Ошибка выполнения", command, "error")
            self._schedule_idle()

        @Slot()
        def initialize(self) -> None:
            def work() -> None:
                try:
                    self._set_state("loading", "Загружаю голосовую модель")
                    command_input = create_input(self.config, ROOT)
                    if isinstance(command_input, KeyboardInput):
                        raise RuntimeError("Модель Vosk не найдена")
                    self.command_input = command_input
                    self._set_state("idle", "Система готова")
                    self.initializationFinished.emit(True, "Голосовое управление готово")
                    self.toastRequested.emit("Джарвис готов", "Голосовое управление подключено", "success")
                except Exception as error:
                    log(f"Ошибка инициализации интерфейса: {error}", "ERROR")
                    self._set_state("error", "Голос недоступен")
                    self.initializationFinished.emit(False, str(error))
                    self.toastRequested.emit("Ошибка инициализации", str(error), "error")

            self._start_thread(work)

        def _execute(self, command: str) -> None:
            command = command.strip()
            if not command:
                return
            if not self._busy.acquire(blocking=False):
                self.toastRequested.emit("Джарвис занят", "Дождитесь завершения текущей команды", "warning")
                return
            try:
                self._set_state("thinking", "Анализирую команду")
                time.sleep(0.28)
                self._set_state("executing", "Выполняю команду")
                result = self.assistant.execute(command)
                self._finish_result(command, result)
            except Exception as error:
                log(f"Ошибка команды: {error}", "ERROR")
                self.commandFinished.emit(command, False, {"error": str(error)})
                self._set_state("error", "Ошибка выполнения")
                self.toastRequested.emit("Ошибка", str(error), "error")
                self._schedule_idle(2.0)
            finally:
                self._busy.release()

        @Slot(str)
        def executeCommand(self, command: str) -> None:
            self._start_thread(lambda: self._execute(command))

        @Slot(str)
        def activateMode(self, mode: str) -> None:
            commands = {
                "gaming": "включи игровой режим",
                "work": "включи рабочий режим",
                "leisure": "включи режим отдыха",
            }
            command = commands.get(mode)
            if command:
                self.executeCommand(command)

        @Slot()
        def listenCommand(self) -> None:
            def work() -> None:
                if self.command_input is None:
                    self.toastRequested.emit("Подождите", "Голосовая модель ещё загружается", "warning")
                    return
                if not self._busy.acquire(blocking=False):
                    self.toastRequested.emit("Джарвис занят", "Дождитесь завершения текущей команды", "warning")
                    return
                try:
                    self._set_state("listening", "Слушаю")
                    self.voice.say("Слушаю.")
                    command = self.command_input.listen(self.audioLevelChanged.emit)
                    self.recognized.emit(command)
                    self.audioLevelChanged.emit(0.0)
                    if not command:
                        self.voice.say("Я не расслышал команду.")
                        self.commandFinished.emit("Голосовая команда", False, {"error": "Пустой результат"})
                        self._set_state("error", "Команда не распознана")
                        self.toastRequested.emit("Не расслышал", "Попробуйте произнести команду ещё раз", "error")
                        self._schedule_idle(2.0)
                        return
                    self._set_state("thinking", "Распознаю намерение")
                    time.sleep(0.28)
                    self._set_state("executing", "Выполняю команду")
                    result = self.assistant.execute(command)
                    self._finish_result(command, result)
                except Exception as error:
                    log(f"Ошибка микрофона: {error}", "ERROR")
                    self.commandFinished.emit("Голосовая команда", False, {"error": str(error)})
                    self._set_state("error", "Ошибка микрофона")
                    self.toastRequested.emit("Ошибка микрофона", str(error), "error")
                    self._schedule_idle(2.0)
                finally:
                    self.audioLevelChanged.emit(0.0)
                    self._busy.release()

            self._start_thread(work)

        @Slot(result="QVariant")
        def getSettings(self):
            microphones = [{"label": "Системный микрофон по умолчанию", "value": None}]
            voices = []
            try:
                microphones.extend([
                    {"label": f"{index}: {name}", "value": index}
                    for index, name, _channels, _rate in list_microphones()
                ])
            except Exception as error:
                log(f"Не удалось получить микрофоны: {error}", "WARN")
            try:
                voices = [
                    {"label": name or voice_id, "value": name or voice_id}
                    for _index, name, voice_id in list_voices()
                ]
            except Exception as error:
                log(f"Не удалось получить голоса: {error}", "WARN")
            return {
                "microphones": microphones,
                "voices": voices,
                "device": self.config["voiceInput"].get("device"),
                "voice": self.config["voiceOutput"].get("preferredVoice", ""),
                "volume": round(float(self.config["voiceOutput"].get("volume", 1.0)) * 100),
                "rate": int(self.config["voiceOutput"].get("rate", 165)),
                "hotkey": self.config["assistant"].get("hotkey", "ctrl+alt+j"),
                "exitHotkey": self.config["assistant"].get("exitHotkey", "ctrl+alt+q"),
            }

        @Slot("QVariant")
        def saveSettings(self, payload) -> None:
            def work() -> None:
                try:
                    if hasattr(payload, "toVariant"):
                        payload = payload.toVariant()
                    data = dict(payload)
                    device = data.get("device")
                    if isinstance(device, float) and device.is_integer():
                        device = int(device)
                    self.config["voiceInput"]["device"] = device
                    self.config["voiceOutput"]["preferredVoice"] = str(data.get("voice") or "")
                    self.config["voiceOutput"]["volume"] = max(0.0, min(1.0, float(data.get("volume", 100)) / 100.0))
                    self.config["voiceOutput"]["rate"] = max(80, min(260, int(data.get("rate", 165))))
                    self.config["assistant"]["hotkey"] = str(data.get("hotkey") or "ctrl+alt+j").strip()
                    self.config["assistant"]["exitHotkey"] = str(data.get("exitHotkey") or "ctrl+alt+q").strip()
                    CONFIG_PATH.write_text(
                        json.dumps(self.config, ensure_ascii=False, indent=2) + "\n",
                        encoding="utf-8",
                    )

                    self._set_state("loading", "Применяю настройки")
                    self.voice = create_voice(self.config)
                    self.assistant = Assistant(self.config, self.launcher, self.voice)
                    command_input = create_input(self.config, ROOT)
                    if isinstance(command_input, KeyboardInput):
                        raise RuntimeError("Модель Vosk не найдена")
                    self.command_input = command_input
                    if self.hotkey_updater is not None:
                        self.hotkey_updater()
                    self._set_state("idle", "Система готова")
                    self.settingsSaved.emit(True, "Настройки сохранены")
                    self.toastRequested.emit("Настройки сохранены", "Новые параметры уже применены", "success")
                except Exception as error:
                    log(f"Ошибка сохранения настроек: {error}", "ERROR")
                    self._set_state("error", "Ошибка настроек")
                    self.settingsSaved.emit(False, str(error))
                    self.toastRequested.emit("Не удалось сохранить", str(error), "error")
                    self._schedule_idle(2.0)

            self._start_thread(work)

        @Slot()
        def minimizeWindow(self) -> None:
            if self.window is not None:
                self.window.showMinimized()

        @Slot()
        def restoreWindow(self) -> None:
            if self.window is not None:
                self.window.showNormal()

        @Slot()
        def hideToTray(self) -> None:
            if self.window is not None:
                self.window.hide()
            if self.tray is not None:
                self.tray.showMessage("Jarvis PC", "Приложение продолжает работать в трее")

        @Slot()
        def toggleMaximize(self) -> None:
            if self.window is None:
                return
            if self.window.visibility() == QWindow.Visibility.Maximized:
                self.window.showNormal()
            else:
                self.window.showMaximized()

        @Slot()
        def toggleFullscreen(self) -> None:
            if self.window is None:
                return
            if self.window.visibility() == QWindow.Visibility.FullScreen:
                self.window.showNormal()
            else:
                self.window.showFullScreen()

        @Slot()
        def closeApplication(self) -> None:
            QGuiApplication.quit()

    app = QApplication([sys.argv[0]])
    app.setApplicationName("Jarvis PC")
    app.setOrganizationName("Jarvis PC")
    app.setQuitOnLastWindowClosed(True)
    if ROBOT_PATH.is_file():
        app.setWindowIcon(QIcon(str(ROBOT_PATH)))

    config = load_config(CONFIG_PATH)
    if args.mic is not None:
        config["voiceInput"]["device"] = int(args.mic) if args.mic.isdigit() else args.mic

    backend = Backend(config)
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backend", backend)
    engine.load(QUrl.fromLocalFile(str(UI_PATH)))
    if not engine.rootObjects():
        return 1

    window = engine.rootObjects()[0]
    backend.set_window(window)

    tray = QSystemTrayIcon(QIcon(str(ROBOT_PATH)), app)
    backend.set_tray(tray)
    tray.setToolTip("Jarvis PC")
    tray_menu = QMenu()
    show_action = QAction("Открыть Джарвиса", tray_menu)
    show_action.triggered.connect(lambda _checked=False: (window.show(), window.raise_(), window.requestActivate()))
    gaming_action = QAction("Игровой режим", tray_menu)
    gaming_action.triggered.connect(lambda _checked=False: backend.activateMode("gaming"))
    work_action = QAction("Рабочий режим", tray_menu)
    work_action.triggered.connect(lambda _checked=False: backend.activateMode("work"))
    quit_action = QAction("Полный выход", tray_menu)
    quit_action.triggered.connect(lambda _checked=False: backend.closeApplication())
    tray_menu.addAction(show_action)
    tray_menu.addSeparator()
    tray_menu.addAction(gaming_action)
    tray_menu.addAction(work_action)
    tray_menu.addSeparator()
    tray_menu.addAction(quit_action)
    tray.setContextMenu(tray_menu)

    def restore_from_tray(reason) -> None:
        if reason == QSystemTrayIcon.ActivationReason.Trigger:
            window.show()
            window.raise_()
            window.requestActivate()

    tray.activated.connect(restore_from_tray)
    tray.show()

    hotkey_handles: list[Any] = []
    keyboard_module = None
    try:
        import keyboard

        keyboard_module = keyboard

        def register_hotkeys() -> None:
            while hotkey_handles:
                try:
                    keyboard.remove_hotkey(hotkey_handles.pop())
                except Exception:
                    pass
            hotkey_handles.append(keyboard.add_hotkey(config["assistant"]["hotkey"], backend.listenCommand))
            hotkey_handles.append(keyboard.add_hotkey(config["assistant"]["exitHotkey"], backend.closeApplication))

        backend.hotkey_updater = register_hotkeys
        register_hotkeys()
    except Exception as error:
        log(f"Глобальные горячие клавиши недоступны: {error}", "WARN")

    def cleanup_hotkeys() -> None:
        if keyboard_module is None:
            return
        while hotkey_handles:
            try:
                keyboard_module.remove_hotkey(hotkey_handles.pop())
            except Exception:
                pass

    app.aboutToQuit.connect(cleanup_hotkeys)
    QTimer.singleShot(300, backend.initialize)
    return app.exec()
