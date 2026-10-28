from __future__ import annotations

import json
import math
import queue
import time
from pathlib import Path
from typing import Any

from .core import log


class SilentVoice:
    def say(self, text: str) -> None:
        log(f"Джарвис: {text}")


class SystemVoice(SilentVoice):
    def __init__(self, config: dict[str, Any]) -> None:
        import pyttsx3

        self.engine = pyttsx3.init()
        settings = config["voiceOutput"]
        preferred = settings["preferredVoice"].casefold()
        voice = next(
            (item for item in self.engine.getProperty("voices") if preferred in f"{item.name} {item.id}".casefold()),
            None,
        )
        if voice:
            self.engine.setProperty("voice", voice.id)
        else:
            log(f"Голос {settings['preferredVoice']} недоступен через SAPI", "WARN")
        self.engine.setProperty("rate", settings["rate"])
        self.engine.setProperty("volume", settings["volume"])

    def say(self, text: str) -> None:
        super().say(text)
        self.engine.say(text)
        self.engine.runAndWait()


def create_voice(config: dict[str, Any], silent: bool = False):
    if silent:
        return SilentVoice()
    try:
        return SystemVoice(config)
    except Exception as error:
        log(f"Голосовой движок недоступен: {error}. Ответы будут выводиться текстом.", "WARN")
        return SilentVoice()


def list_voices() -> list[tuple[int, str, str]]:
    import pyttsx3

    engine = pyttsx3.init()
    try:
        return [
            (index, getattr(voice, "name", ""), getattr(voice, "id", ""))
            for index, voice in enumerate(engine.getProperty("voices"))
        ]
    finally:
        engine.stop()


def list_microphones() -> list[tuple[int, str, int, float]]:
    import sounddevice as sd

    microphones = []
    for index, device in enumerate(sd.query_devices()):
        channels = int(device["max_input_channels"])
        if channels > 0:
            microphones.append((index, str(device["name"]), channels, float(device["default_samplerate"])))
    return microphones


class KeyboardInput:
    def listen(self) -> str:
        return input("Введите команду: ").strip()


class VoskInput:
    def __init__(self, config: dict[str, Any], root: Path) -> None:
        settings = config["voiceInput"]
        self.model_path = root / settings["modelPath"]
        self.device = settings.get("device")
        self.rate = int(settings["sampleRate"])
        self.timeout = float(settings["timeoutSeconds"])
        self._model = None

    @property
    def available(self) -> bool:
        try:
            import sounddevice  # noqa: F401
            import vosk  # noqa: F401
        except ImportError:
            return False
        return self.model_path.is_dir()

    def prepare(self) -> None:
        if self._model is not None:
            return
        from vosk import Model, SetLogLevel

        SetLogLevel(-1)
        log("Загрузка русской модели распознавания...")
        self._model = Model(str(self.model_path))
        log("Модель распознавания готова.")

    def listen(self, level_callback=None) -> str:
        import sounddevice as sd
        from vosk import KaldiRecognizer

        chunks: queue.Queue[bytes] = queue.Queue()

        def callback(data, _frames, _time, status) -> None:
            if status:
                log(str(status), "WARN")
            raw = bytes(data)
            chunks.put(raw)
            if level_callback is not None:
                try:
                    samples = memoryview(raw).cast("h")
                    step = max(1, len(samples) // 256)
                    selected = samples[::step]
                    rms = math.sqrt(sum(sample * sample for sample in selected) / max(1, len(selected)))
                    level_callback(min(1.0, rms / 9000.0))
                except Exception:
                    level_callback(0.0)

        self.prepare()
        recognizer = KaldiRecognizer(self._model, self.rate)
        deadline = time.monotonic() + self.timeout
        partial = ""
        try:
            with sd.RawInputStream(
                device=self.device,
                samplerate=self.rate,
                # Smaller blocks keep the on-screen microphone wave responsive.
                blocksize=1600,
                dtype="int16",
                channels=1,
                callback=callback,
            ):
                while time.monotonic() < deadline:
                    try:
                        data = chunks.get(timeout=0.5)
                    except queue.Empty:
                        continue
                    if recognizer.AcceptWaveform(data):
                        text = json.loads(recognizer.Result()).get("text", "").strip()
                        if text:
                            return text
                    partial = json.loads(recognizer.PartialResult()).get("partial", "").strip()
            final = json.loads(recognizer.FinalResult()).get("text", "").strip()
            return final or partial
        finally:
            if level_callback is not None:
                level_callback(0.0)


def create_input(config: dict[str, Any], root: Path):
    microphone = VoskInput(config, root)
    if microphone.available:
        microphone.prepare()
        return microphone
    if config["voiceInput"].get("fallbackToKeyboard"):
        log(f"Vosk или модель не найдены: {microphone.model_path}. Используется клавиатура.", "WARN")
        return KeyboardInput()
    raise RuntimeError(f"Модель Vosk не найдена: {microphone.model_path}")
