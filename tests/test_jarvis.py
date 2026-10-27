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


if __name__ == "__main__":
    unittest.main()
