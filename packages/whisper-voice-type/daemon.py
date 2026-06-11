# ruff: noqa: F722, F821
import signal
import sys
import os
import subprocess
import re
import time
import threading
import queue
import asyncio
import struct
import select
from contextlib import nullcontext

import evdev
import numpy as np
import sounddevice as sd
from moonshine_voice import Transcriber, TranscriptEventListener, ModelArch
from dbus_next.aio import MessageBus
from dbus_next.service import (
    ServiceInterface,
    dbus_property,
    signal as dbus_signal,
    PropertyAccess,
)
from dbus_next import Variant, BusType
import dictation_lib as dlib

MODEL_PATH = os.environ["MOONSHINE_MODEL_PATH"]
MODEL_ARCH = ModelArch(int(os.environ["MOONSHINE_MODEL_ARCH"]))
AUDIO_BACKEND = os.environ.get("MOONSHINE_AUDIO_BACKEND", "pulse")
INPUT_DEVICE = os.environ.get("MOONSHINE_INPUT_DEVICE") or None
START_PHRASE = os.environ.get("MOONSHINE_START_PHRASE", "start dictation")
STOP_PHRASE = os.environ.get("MOONSHINE_STOP_PHRASE", "stop dictation")
LEADER_KEY = os.environ.get("MOONSHINE_LEADER_KEY") or None
LEADER_GRACE_SECONDS = float(os.environ.get("MOONSHINE_LEADER_GRACE_SECONDS", "2.5"))
SAMPLE_RATE = 16000
NOTIFY = os.environ["NOTIFY_SEND"]
PACTL = os.environ["PACTL"]
PACAT = os.environ["PACAT"]
WPCTL = os.environ["WPCTL"]
WTYPE = os.environ["WTYPE"]
NOTIFY_ID_FILE = "/tmp/whisper-voice-type.notifyid"
_notify_id = None

_corrections = dlib.load_corrections()
_vocabulary = dlib.load_vocabulary()


def _reload():
    global _corrections, _vocabulary
    _corrections = dlib.load_corrections()
    _vocabulary = dlib.load_vocabulary()


def _transcribe(text):
    return dlib.apply_pipeline(text, _vocabulary, _corrections)


def _check_correction_command(text):
    m = dlib.CORRECT_RE.search(text) or dlib.CORRECT_SPOKEN_RE.search(text)
    if m:
        wrong, right = m.group(1).strip(), m.group(2).strip()
        _corrections[wrong.lower()] = right
        dlib.save_corrections(_corrections)
        return wrong, right
    return None


def _on_sighup(_sig, _frame):
    _reload()


signal.signal(signal.SIGHUP, _on_sighup)

_abort_pending = threading.Event()
_abort_until = 0.0

_TRAY_COLORS = {
    "loading": (128, 128, 128, 255),
    "listening": (255, 0, 0, 255),
    "dictating": (0, 220, 0, 255),
}


def _make_pixmap(color, size=22):
    pixels = bytearray()
    cx, cy, r = size / 2, size / 2, size / 2 - 2
    for y in range(size):
        for x in range(size):
            dx, dy = x - cx, y - cy
            if dx * dx + dy * dy <= r * r:
                pixels.extend(
                    struct.pack(">BBBB", color[3], color[0], color[1], color[2])
                )
            else:
                pixels.extend(b"\x00\x00\x00\x00")
    return Variant("a(iiay)", [[size, size, bytes(pixels)]])


class StatusNotifierItem(ServiceInterface):
    def __init__(self):
        super().__init__("org.kde.StatusNotifierItem")
        self._icon_pixmap = _make_pixmap(_TRAY_COLORS["loading"])
        self._tooltip = Variant("(sa(iiay)ss)", ["", [], "moonshine", "loading"])
        self._status = "Active"

    def set_state(self, state):
        self._icon_pixmap = _make_pixmap(_TRAY_COLORS[state])
        self._tooltip = Variant("(sa(iiay)ss)", ["", [], "moonshine", state])
        self.NewIcon()
        self.NewToolTip()

    @dbus_property(access=PropertyAccess.READ)
    def Category(self) -> "s":
        return "Communications"

    @dbus_property(access=PropertyAccess.READ)
    def Id(self) -> "s":
        return "moonshine"

    @dbus_property(access=PropertyAccess.READ)
    def Title(self) -> "s":
        return "moonshine"

    @dbus_property(access=PropertyAccess.READ)
    def Status(self) -> "s":
        return self._status

    @dbus_property(access=PropertyAccess.READ)
    def IconName(self) -> "s":
        return ""

    @dbus_property(access=PropertyAccess.READ)
    def IconPixmap(self) -> "a(iiay)":
        return self._icon_pixmap.value

    @dbus_property(access=PropertyAccess.READ)
    def OverlayIconName(self) -> "s":
        return ""

    @dbus_property(access=PropertyAccess.READ)
    def OverlayIconPixmap(self) -> "a(iiay)":
        return []

    @dbus_property(access=PropertyAccess.READ)
    def AttentionIconName(self) -> "s":
        return ""

    @dbus_property(access=PropertyAccess.READ)
    def AttentionIconPixmap(self) -> "a(iiay)":
        return []

    @dbus_property(access=PropertyAccess.READ)
    def ToolTip(self) -> "(sa(iiay)ss)":
        return self._tooltip.value

    @dbus_property(access=PropertyAccess.READ)
    def ItemIsMenu(self) -> "b":
        return False

    @dbus_property(access=PropertyAccess.READ)
    def Menu(self) -> "o":
        return "/NO_DBUSMENU"

    @dbus_signal()
    def NewIcon(self):
        pass

    @dbus_signal()
    def NewToolTip(self):
        pass


_sni = StatusNotifierItem()
_sni_loop = asyncio.new_event_loop()

_SNI_NAME = f"org.kde.StatusNotifierItem-{os.getpid()}-1"


async def _do_register(bus):
    try:
        watcher = bus.get_proxy_object(
            "org.kde.StatusNotifierWatcher",
            "/StatusNotifierWatcher",
            await bus.introspect(
                "org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher"
            ),
        )
        iface = watcher.get_interface("org.kde.StatusNotifierWatcher")
        await iface.call_register_status_notifier_item(_SNI_NAME)
    except Exception:
        pass


async def _register_sni():
    bus = await MessageBus(bus_type=BusType.SESSION).connect()
    bus.export("/StatusNotifierItem", _sni)
    await bus.request_name(_SNI_NAME)
    await _do_register(bus)

    dbus_obj = bus.get_proxy_object(
        "org.freedesktop.DBus",
        "/org/freedesktop/DBus",
        await bus.introspect("org.freedesktop.DBus", "/org/freedesktop/DBus"),
    )
    dbus_iface = dbus_obj.get_interface("org.freedesktop.DBus")

    def _on_name_owner_changed(name, old, new):
        if name == "org.kde.StatusNotifierWatcher" and new:
            _sni_loop.create_task(_do_register(bus))

    dbus_iface.on_name_owner_changed(_on_name_owner_changed)
    return bus


def _run_sni():
    asyncio.set_event_loop(_sni_loop)
    _sni_loop.run_until_complete(_register_sni())
    _sni_loop.run_forever()


threading.Thread(target=_run_sni, daemon=True).start()


def _tray_set(state):
    _sni_loop.call_soon_threadsafe(lambda: _sni.set_state(state))


def _load_notify_id():
    global _notify_id
    try:
        _notify_id = int(open(NOTIFY_ID_FILE).read().strip())
    except Exception:
        _notify_id = None


def _save_notify_id():
    try:
        if _notify_id is not None:
            open(NOTIFY_ID_FILE, "w").write(str(_notify_id))
        else:
            os.unlink(NOTIFY_ID_FILE)
    except Exception:
        pass


_load_notify_id()
if _notify_id is not None:
    subprocess.run(
        [NOTIFY, "-r", str(_notify_id), "-t", "1", "-u", "low", " "],
        capture_output=True,
    )
    _notify_id = None
    _save_notify_id()


def notify_msg(summary, body="", timeout=2000, urgency="normal"):
    global _notify_id
    effective_timeout = 0 if _notify_id is not None else timeout
    cmd = [NOTIFY, "-p", "-t", str(effective_timeout), "-u", urgency, summary, body]
    if _notify_id is not None:
        cmd[1:1] = ["-r", str(_notify_id)]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
        _notify_id = int(result.stdout.strip())
        _save_notify_id()
    except Exception:
        pass


def _pactl_source():
    return INPUT_DEVICE or "@DEFAULT_SOURCE@"


def _run_text(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, timeout=2)


def _default_source_name():
    try:
        result = _run_text([PACTL, "get-default-source"])
    except Exception:
        return None
    if result.returncode != 0:
        return None
    return result.stdout.strip() or None


def _source_mute(source):
    try:
        result = _run_text([PACTL, "get-source-mute", source])
    except Exception:
        return None, ""
    if result.returncode != 0:
        return None, result.stderr.strip()
    return "yes" in result.stdout.lower(), ""


def _source_blocks():
    try:
        result = _run_text([PACTL, "list", "sources"])
    except Exception:
        return []
    if result.returncode != 0:
        return []
    return re.split(r"\n(?=Source #)", result.stdout)


def _source_block(source_name):
    for block in _source_blocks():
        if re.search(rf"^\s*Name:\s+{re.escape(source_name)}\s*$", block, re.M):
            return block
    return ""


def _source_description(source_name):
    block = _source_block(source_name)
    match = re.search(r"^\s*Description:\s+(.+?)\s*$", block, re.M)
    return match.group(1) if match else source_name


def _node_source_name(node_id):
    try:
        result = _run_text([WPCTL, "inspect", str(node_id)])
    except Exception:
        return None
    if result.returncode != 0 or 'media.class = "Audio/Source"' not in result.stdout:
        return None
    match = re.search(r'\*\s*node.name = "([^"]+)"', result.stdout)
    return match.group(1) if match else None


def _upstream_source_name(source_name):
    block = _source_block(source_name)
    match = re.search(r'node.driver-id = "(\d+)"', block)
    if not match:
        return None
    upstream = _node_source_name(match.group(1))
    if upstream == source_name:
        return None
    return upstream


def _check_mic_health():
    source = _pactl_source()
    if source == "@DEFAULT_SOURCE@":
        source = _default_source_name() or source

    muted, error = _source_mute(source)
    if muted is None:
        notify_msg(
            "Moonshine microphone unavailable",
            error or f"Could not inspect {source}",
            timeout=5000,
            urgency="critical",
        )
        return
    if muted:
        notify_msg(
            "Moonshine microphone is muted",
            f"Unmute {source} before starting dictation.",
            timeout=7000,
            urgency="critical",
        )
        return

    upstream = _upstream_source_name(source)
    if upstream is None:
        return
    upstream_muted, _ = _source_mute(upstream)
    if upstream_muted:
        notify_msg(
            "Moonshine microphone is muted",
            f"{source} is active, but upstream source {upstream} is muted.",
            timeout=7000,
            urgency="critical",
        )


_check_mic_health()


def notify_close():
    global _notify_id
    if _notify_id is not None:
        subprocess.run(
            [NOTIFY, "-r", str(_notify_id), "-t", "1", "-u", "low", " "],
            capture_output=True,
        )
        _notify_id = None
        _save_notify_id()


def _on_sigterm(_sig, _frame):
    notify_close()
    notify_msg("Moonshine stopped", timeout=2000, urgency="low")
    sys.exit(0)


signal.signal(signal.SIGTERM, _on_sigterm)

notify_msg("Moonshine", "Loading…", timeout=0)
transcriber = Transcriber(
    model_path=MODEL_PATH,
    model_arch=MODEL_ARCH,
    update_interval=999999,
    options={
        "vad_window_duration": "0.3",
        # Cap a single utterance/segment so the autoregressive decoder never
        # runs a very long token loop in one go: latency grows with token count
        # (~6.5 tokens/s of speech), so a shorter cap keeps the speak->text
        # delay low. Default is 15s; 8s rarely cuts a natural phrase.
        "vad_max_segment_duration": "8.0",
    },
)
notify_close()
_tray_set("listening")

_dev_name = None
if AUDIO_BACKEND == "pulse":
    _dev_source = _pactl_source()
    if _dev_source == "@DEFAULT_SOURCE@":
        _dev_source = _default_source_name()
    if _dev_source is not None:
        _dev_name = _source_description(_dev_source)

_wtype_lock = threading.Lock()
_wtype_proc = None


def wtype(*args):
    global _wtype_proc
    if _abort_pending.is_set() or time.time() < _abort_until:
        return
    _wtype_proc = subprocess.Popen([WTYPE, "-d", "8", *args])
    _wtype_proc.wait()
    _wtype_proc = None


def wtype_text(text):
    wtype("--", text)


def _kill_wtype():
    p = _wtype_proc
    if p is not None:
        try:
            p.terminate()
            try:
                p.wait(timeout=0.2)
            except subprocess.TimeoutExpired:
                p.kill()
        except ProcessLookupError:
            pass


def _on_sigusr1(_sig, _frame):
    global _abort_until, _prev
    _abort_pending.set()
    _abort_until = time.time() + 5.0
    _prev = ""
    _kill_wtype()


signal.signal(signal.SIGUSR1, _on_sigusr1)

_prev = ""
_dictating = False


def _phrase_re(phrase):
    words = [re.escape(word) for word in phrase.strip().split()]
    if not words:
        return re.compile(r"a^")
    return re.compile(r"\b" + r"\s+".join(words) + r"\b", re.IGNORECASE)


_START_RE = _phrase_re(START_PHRASE)
_STOP_RE = _phrase_re(STOP_PHRASE)
_leader_recent_until = 0.0
_leader_available = LEADER_KEY is None

_last_audio = time.time()
# Heartbeat stamped each time the audio loop finishes an iteration. The loop
# runs continuously while the mic is open, so this advances even during silence
# (when no lines complete). It only stops advancing if the loop itself is stuck,
# e.g. wedged inside update_transcription(), which is the real failure to catch.
_loop_heartbeat = time.time()
_STALL_TIMEOUT = 120.0


def _leader_code():
    if LEADER_KEY is None:
        return None
    code = getattr(evdev.ecodes, LEADER_KEY, None)
    if isinstance(code, int):
        return code
    if LEADER_KEY.isdigit():
        return int(LEADER_KEY)
    return None


def _supports_key(device, key_code):
    try:
        return key_code in device.capabilities().get(evdev.ecodes.EV_KEY, [])
    except OSError:
        return False


def _watch_leader_key():
    global _leader_recent_until, _leader_available
    key_code = _leader_code()
    if key_code is None:
        notify_msg(
            "Moonshine leader key unavailable",
            f"Unknown key code: {LEADER_KEY}",
            timeout=5000,
            urgency="critical",
        )
        return

    devices = []
    for path in evdev.list_devices():
        try:
            device = evdev.InputDevice(path)
        except OSError:
            continue
        if _supports_key(device, key_code):
            devices.append(device)
        else:
            device.close()

    if not devices:
        notify_msg(
            "Moonshine leader key unavailable",
            f"No readable input device exposes {LEADER_KEY}",
            timeout=5000,
            urgency="critical",
        )
        return

    _leader_available = True
    while True:
        try:
            readable, _, _ = select.select(devices, [], [], 0.25)
        except OSError:
            break
        now = time.time()
        for device in devices:
            try:
                if key_code in device.active_keys():
                    _leader_recent_until = now + LEADER_GRACE_SECONDS
            except OSError:
                pass
        for device in readable:
            try:
                for event in device.read():
                    if event.type == evdev.ecodes.EV_KEY and event.code == key_code:
                        if event.value:
                            _leader_recent_until = time.time() + LEADER_GRACE_SECONDS
            except OSError:
                pass


if LEADER_KEY is not None:
    threading.Thread(target=_watch_leader_key, daemon=True).start()


def _leader_allows_start():
    if LEADER_KEY is None:
        return True
    if not _leader_available:
        return False
    return time.time() <= _leader_recent_until


def _check_trigger(text):
    global _dictating
    if _START_RE.search(text):
        if not _leader_allows_start():
            return True
        if not _dictating:
            _dictating = True
            _tray_set("dictating")
            notify_msg("Dictating…", _dev_name or "", timeout=0, urgency="low")
        return True
    if _STOP_RE.search(text):
        if _dictating:
            _dictating = False
            _tray_set("listening")
            notify_close()
        return True
    return False


def _type_diff(new_text):
    global _prev
    if _abort_pending.is_set() or time.time() < _abort_until:
        return
    if not _dictating or not new_text or new_text == _prev:
        return
    new_text = _transcribe(new_text)
    common = 0
    while (
        common < len(_prev)
        and common < len(new_text)
        and _prev[common] == new_text[common]
    ):
        common += 1
    if common < len(new_text) and new_text[common] == " ":
        while common > 0 and _prev[common - 1] != " ":
            common -= 1
    n_back = len(_prev) - common
    if n_back:
        wtype(*(["-k", "BackSpace"] * n_back))
    suffix = new_text[common:]
    if suffix:
        wtype_text(suffix)
    _prev = new_text


class Listener(TranscriptEventListener):
    def on_line_text_changed(self, event):
        global _prev
        with _wtype_lock:
            raw_text = event.line.text
            if _check_trigger(raw_text):
                _prev = ""
                return
            _type_diff(raw_text)

    def on_line_completed(self, event):
        global _prev
        with _wtype_lock:
            raw_text = event.line.text
            if _check_trigger(raw_text):
                _prev = ""
                return
            if _check_correction_command(raw_text):
                _prev = ""
                return
            if dlib.MARK_THAT_RE.search(raw_text):
                dlib.flag_recent_lines()
                _prev = ""
                return
            if _dictating and raw_text and time.time() >= _abort_until:
                corrected = _transcribe(raw_text)
                dlib.log_transcript(raw_text, corrected)
                wtype_text(corrected + " ")
            _prev = ""


_listener = Listener()
transcriber.add_listener(_listener)
transcriber.start()


def _watchdog():
    while True:
        time.sleep(30)
        now = time.time()
        # Restart only if the audio loop itself has stopped making progress
        # while audio is still arriving: the mic is live (_last_audio recent)
        # but the loop has not completed an iteration in _STALL_TIMEOUT. This is
        # a genuine wedge (e.g. stuck in update_transcription). Silence is NOT a
        # stall, because the loop keeps iterating and stamping the heartbeat even
        # when no lines complete, so this no longer fires during normal idle.
        loop_stuck = now - _loop_heartbeat >= _STALL_TIMEOUT
        audio_live = now - _last_audio < _STALL_TIMEOUT
        if loop_stuck and audio_live:
            os.execv(sys.executable, [sys.executable] + sys.argv)


threading.Thread(target=_watchdog, daemon=True).start()

# Bounded so a backend that falls behind real time (e.g. CPU fallback) cannot
# accumulate an ever-growing backlog and end up transcribing minutes-old audio.
# Each chunk is 0.1 s, so this caps the queue at _MAX_QUEUE_SECONDS of audio.
_MAX_QUEUE_SECONDS = 15.0
audio_q = queue.Queue(maxsize=int(_MAX_QUEUE_SECONDS / 0.1))
_dropped_audio = 0


def _enqueue_audio(samples):
    global _last_audio, _dropped_audio
    _last_audio = time.time()
    try:
        audio_q.put_nowait(samples.copy())
    except queue.Full:
        # Inference is behind real time: discard the oldest chunk to stay live
        # rather than queueing audio we will never catch up on.
        try:
            audio_q.get_nowait()
        except queue.Empty:
            pass
        try:
            audio_q.put_nowait(samples.copy())
        except queue.Full:
            pass
        _dropped_audio += 1


def callback(indata, frames, time_info, status):
    _enqueue_audio(indata[:, 0])


_pulse_proc = None


def _pulse_reader():
    global _pulse_proc
    chunk_samples = int(SAMPLE_RATE * 0.1)
    chunk_bytes = chunk_samples * 4
    cmd = [
        PACAT,
        "--record",
        "--raw",
        "--format=float32le",
        f"--rate={SAMPLE_RATE}",
        "--channels=1",
    ]
    if INPUT_DEVICE is not None:
        cmd.append(f"--device={INPUT_DEVICE}")
    _pulse_proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    while True:
        data = _pulse_proc.stdout.read(chunk_bytes)
        if len(data) != chunk_bytes:
            break
        _enqueue_audio(np.frombuffer(data, dtype=np.float32))


stream = transcriber.get_default_stream()

if AUDIO_BACKEND == "pulse":
    threading.Thread(target=_pulse_reader, daemon=True).start()
    capture_context = nullcontext()
elif AUDIO_BACKEND == "sounddevice":
    capture_context = sd.InputStream(
        samplerate=SAMPLE_RATE,
        channels=1,
        dtype="float32",
        blocksize=int(SAMPLE_RATE * 0.1),
        device=INPUT_DEVICE,
        callback=callback,
    )
else:
    raise ValueError(f"unsupported MOONSHINE_AUDIO_BACKEND: {AUDIO_BACKEND}")

with capture_context:
    try:
        while True:
            if _abort_pending.is_set():
                _abort_pending.clear()
                _abort_until = time.time() + 5.0
                while not audio_q.empty():
                    try:
                        audio_q.get_nowait()
                    except queue.Empty:
                        break
                _prev = ""
                notify_close()
                notify_msg("Aborted", timeout=2000, urgency="low")
                continue
            got_audio = False
            while True:
                try:
                    chunk = audio_q.get_nowait()
                    stream.add_audio(chunk.tolist(), SAMPLE_RATE)
                    got_audio = True
                except queue.Empty:
                    break
            if got_audio:
                stream.update_transcription()
            else:
                time.sleep(0.02)
            _loop_heartbeat = time.time()
    except KeyboardInterrupt:
        pass

if _pulse_proc is not None:
    _pulse_proc.terminate()
transcriber.stop()
transcriber.close()
notify_close()
