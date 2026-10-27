from __future__ import annotations

import json
import os
import re
import subprocess
import urllib.parse
import webbrowser
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Protocol


@dataclass
class Result:
    action: str
    success: bool
    value: str | None = None
    failed: list[str] = field(default_factory=list)


class Voice(Protocol):
    def say(self, text: str) -> None: ...


def load_config(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as stream:
        return json.load(stream)


def expand_path(value: str) -> str:
    variables = {key.casefold(): val for key, val in os.environ.items()}
    return re.sub(
        r"%([^%]+)%",
        lambda match: variables.get(match.group(1).casefold(), match.group(0)),
        value,
    )


def log(message: str, level: str = "INFO") -> None:
    print(f"[{level}] {message}")


class Launcher:
    def __init__(self, config: dict[str, Any], dry_run: bool = False) -> None:
        self.config = config
        self.dry_run = dry_run

    @staticmethod
    def _exists(path: Path) -> bool:
        try:
            return path.is_file()
        except PermissionError:
            return False

    @staticmethod
    def _running(processes: list[str]) -> bool:
        if os.name != "nt" or not processes:
            return False
        try:
            output = subprocess.run(
                ["tasklist", "/FO", "CSV", "/NH"],
                capture_output=True,
                check=False,
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
            ).stdout.decode(errors="ignore").casefold()
            return any(process.casefold() in output for process in processes)
        except OSError:
            return False

    def open_url(self, url: str) -> bool:
        if self.dry_run:
            log(f"Открыть URL: {url}", "DRYRUN")
            return True
        browser = Path(expand_path(self.config["browser"]))
        try:
            if self._exists(browser):
                subprocess.Popen([str(browser), url])
                return True
            return bool(webbrowser.open(url))
        except OSError as error:
            log(f"Ошибка открытия сайта: {error}", "ERROR")
            return False

    def start_app(self, app_id: str) -> Result:
        app = self.config["applications"][app_id]
        if "url" in app:
            return Result("application", self.open_url(app["url"]), app_id)

        path = Path(expand_path(app["path"]))
        command = [str(path), *app.get("args", [])]
        if self.dry_run:
            log(f"Запустить {app['name']}: {' '.join(command)}", "DRYRUN")
            return Result("application", True, app_id)
        if self._running(app.get("processes", [])):
            log(f"{app['name']} уже запущен")
            return Result("application", True, app_id)
        if not self._exists(path):
            log(f"{app['name']} не найден: {path}", "WARN" if app.get("optional") else "ERROR")
            return Result("application", False, app_id)
        try:
            subprocess.Popen(command, creationflags=getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0))
            log(f"{app['name']} запущен")
            return Result("application", True, app_id)
        except OSError as error:
            log(f"Ошибка запуска {app['name']}: {error}", "ERROR")
            return Result("application", False, app_id)

    def start_mode(self, mode: str) -> Result:
        failed: list[str] = []
        required_failed: list[str] = []
        for app_id in self.config["modes"][mode]["applications"]:
            if not self.start_app(app_id).success:
                failed.append(app_id)
                if not self.config["applications"][app_id].get("optional"):
                    required_failed.append(app_id)
        return Result("mode", not required_failed, mode, failed)

    def movie(self, title: str) -> Result:
        title = title.strip()
        if not title:
            return Result("movie", False)
        url = self.config["kinopoiskSearch"].replace("{query}", urllib.parse.quote(title))
        return Result("movie", self.open_url(url), title)

    def environment(self) -> list[tuple[str, str, str]]:
        rows = []
        for app_id, app in self.config["applications"].items():
            if "url" in app:
                rows.append(("URL", app["name"], app["url"]))
            else:
                target = Path(expand_path(app["path"]))
                rows.append(("FOUND" if self._exists(target) else "MISSING", app["name"], str(target)))
        return rows


class Assistant:
    def __init__(self, config: dict[str, Any], launcher: Launcher, voice: Voice) -> None:
        self.config = config
        self.launcher = launcher
        self.voice = voice

    def execute(self, raw_command: str) -> Result:
        command = re.sub(
            r"^\s*джарвис[\s,.:;!—-]*",
            "",
            raw_command,
            flags=re.IGNORECASE,
        ).strip()
        normalized = command.casefold()
        log(f"Команда: {command}")

        if re.search(r"игров\w*\s*(режим)?|режим\s+игр", normalized):
            result = self.launcher.start_mode("gaming")
            self.voice.say(self.config["modes"]["gaming"]["confirmation"])
            return result
        if re.search(r"рабоч\w*\s*(режим)?|режим\s+работ", normalized):
            result = self.launcher.start_mode("work")
            self.voice.say(self.config["modes"]["work"]["confirmation"])
            return result
        if re.search(r"режим\s+отдыха|отдых", normalized):
            result = self.launcher.start_mode("leisure")
            self.voice.say(self.config["modes"]["leisure"]["confirmation"])
            return result

        film = re.search(
            r"(?:включи|открой|найди|покажи)?\s*(?:фильм|кино)\s*(.*)$",
            command,
            flags=re.IGNORECASE,
        )
        if film:
            result = self.launcher.movie(film.group(1))
            if result.success:
                self.voice.say(f"Ищу фильм {result.value} на Кинопоиске.")
            else:
                self.voice.say("Какой фильм найти?")
            return result

        for app_id, app in self.config["applications"].items():
            if any(alias.casefold() in normalized for alias in app["aliases"]):
                result = self.launcher.start_app(app_id)
                self.voice.say(f"Открываю {app['name']}." if result.success else f"Не удалось открыть {app['name']}.")
                return result

        self.voice.say("Команда не распознана.")
        return Result("unknown", False)
