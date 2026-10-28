from __future__ import annotations

import unittest
from pathlib import Path

from jarvis.core import Assistant, Result, load_config


ROOT = Path(__file__).resolve().parents[1]


class FakeLauncher:
    def start_mode(self, mode: str) -> Result:
        return Result("mode", True, mode)

    def start_app(self, app_id: str) -> Result:
        return Result("application", True, app_id)

    def movie(self, title: str) -> Result:
        return Result("movie", bool(title.strip()), title.strip() or None)


class FakeVoice:
    def __init__(self) -> None:
        self.messages = []

    def say(self, text: str) -> None:
        self.messages.append(text)


class JarvisTests(unittest.TestCase):
    def setUp(self) -> None:
        config = load_config(ROOT / "config" / "jarvis.json")
        self.jarvis = Assistant(config, FakeLauncher(), FakeVoice())

    def test_gaming(self) -> None:
        self.assertEqual("gaming", self.jarvis.execute("Джарвис, игровой режим").value)

    def test_work(self) -> None:
        self.assertEqual("work", self.jarvis.execute("рабочий режим").value)

    def test_telegram(self) -> None:
        self.assertEqual("telegram", self.jarvis.execute("открой телеграм").value)

    def test_movie(self) -> None:
        self.assertEqual("Интерстеллар", self.jarvis.execute("включи фильм Интерстеллар").value)

    def test_unknown(self) -> None:
        self.assertEqual("unknown", self.jarvis.execute("абракадабра").action)

    def test_name_is_optional(self) -> None:
        self.assertEqual("gaming", self.jarvis.execute("включи игровой режим").value)

    def test_movie_without_title_requests_title(self) -> None:
        result = self.jarvis.execute("включи фильм")
        self.assertFalse(result.success)
        self.assertEqual("movie", result.action)

    def test_desktop_interface_assets_exist(self) -> None:
        self.assertTrue((ROOT / "ui" / "Main.qml").is_file())
        self.assertTrue((ROOT / "ui" / "assets" / "jarvis-robot.png").is_file())

    def test_interface_contains_all_robot_states(self) -> None:
        qml = (ROOT / "ui" / "Main.qml").read_text(encoding="utf-8")
        for state in ("idle", "listening", "thinking", "executing", "success", "error"):
            self.assertIn(f'"{state}"', qml)
        self.assertIn("audioLevel", qml)
        self.assertIn("settingsPage", qml)
        self.assertIn("compactMode", qml)


if __name__ == "__main__":
    unittest.main()
