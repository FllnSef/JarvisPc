from __future__ import annotations

import argparse
import threading
from pathlib import Path

from .core import Assistant, Launcher, load_config, log
from .speech import create_input, create_voice, list_microphones, list_voices


ROOT = Path(__file__).resolve().parents[1]


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description="Джарвис для Windows")
    result.add_argument("--command")
    result.add_argument("--dry-run", action="store_true")
    result.add_argument("--silent", action="store_true")
    result.add_argument("--check", action="store_true")
    result.add_argument("--list-mics", action="store_true", help="Показать доступные микрофоны")
    result.add_argument("--list-voices", action="store_true", help="Показать системные голоса")
    result.add_argument("--listen-once", action="store_true", help="Распознать одну фразу без выполнения")
    result.add_argument("--mic", help="Индекс или имя микрофона для текущего запуска")
    return result


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    config = load_config(ROOT / "config" / "jarvis.json")
    if args.mic is not None:
        config["voiceInput"]["device"] = int(args.mic) if args.mic.isdigit() else args.mic
    launcher = Launcher(config, dry_run=args.dry_run)
    voice = create_voice(config, silent=args.silent or args.dry_run)
    assistant = Assistant(config, launcher, voice)

    if args.list_mics:
        try:
            microphones = list_microphones()
            if not microphones:
                print("Микрофоны не найдены.")
                return 1
            print("Доступные микрофоны:")
            for index, name, channels, rate in microphones:
                print(f"[{index}] {name} | каналов: {channels} | частота: {rate:.0f} Гц")
            return 0
        except Exception as error:
            log(f"Не удалось получить список микрофонов: {error}", "ERROR")
            return 1

    if args.list_voices:
        try:
            print("Доступные голоса:")
            for index, name, voice_id in list_voices():
                print(f"[{index}] {name} | {voice_id}")
            return 0
        except Exception as error:
            log(f"Не удалось получить список голосов: {error}", "ERROR")
            return 1

    if args.check:
        for status, name, target in launcher.environment():
            print(f"{status:7} {name:20} {target}")
        return 0
    if args.command:
        result = assistant.execute(args.command)
        return 0 if result.success else 1

    command_input = create_input(config, ROOT)

    if args.listen_once:
        voice.say("Слушаю.")
        try:
            recognized = command_input.listen()
        except Exception as error:
            log(f"Ошибка микрофона: {error}", "ERROR")
            return 1
        print(f"Распознано: {recognized or '<пусто>'}")
        return 0 if recognized else 1

    try:
        import keyboard
    except ImportError:
        log("Зависимости не установлены. Запустите setup.ps1", "ERROR")
        return 2

    lock = threading.Lock()

    def listen() -> None:
        if not lock.acquire(blocking=False):
            return
        try:
            voice.say("Слушаю.")
            command = command_input.listen()
            if command:
                log(f"Распознано: {command}")
                assistant.execute(command)
            else:
                voice.say("Я не расслышал команду.")
        except Exception as error:
            log(f"Ошибка микрофона: {error}", "ERROR")
            voice.say("Не удалось распознать команду.")
        finally:
            lock.release()

    hotkey = config["assistant"]["hotkey"]
    exit_hotkey = config["assistant"]["exitHotkey"]
    keyboard.add_hotkey(hotkey, listen)
    log(f"Запущено. {hotkey} — команда; {exit_hotkey} — выход")
    voice.say("Джарвис запущен и готов к работе.")
    keyboard.wait(exit_hotkey)
    voice.say("До встречи.")
    return 0
