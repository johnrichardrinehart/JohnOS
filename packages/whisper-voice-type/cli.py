import argparse
import os
import signal
import subprocess
import sys
import textwrap

PIDFILE = "/tmp/whisper-voice-type.pid"
DAEMON_SCRIPT = os.environ["DAEMON_SCRIPT"]
TRAIN_SCRIPT = os.environ["TRAIN_SCRIPT"]
REVIEW_SCRIPT = os.environ["REVIEW_SCRIPT"]
SETSID = os.environ["SETSID"]
START_PHRASE = os.environ.get("MOONSHINE_START_PHRASE", "start dictation")
STOP_PHRASE = os.environ.get("MOONSHINE_STOP_PHRASE", "stop dictation")
LEADER_KEY = os.environ.get("MOONSHINE_LEADER_KEY") or "none"


def _read_pid():
    try:
        pid = int(open(PIDFILE).read().strip())
        os.kill(pid, 0)
        return pid
    except (FileNotFoundError, ValueError, ProcessLookupError, PermissionError):
        try:
            os.unlink(PIDFILE)
        except FileNotFoundError:
            pass
        return None


def _signal_daemon(sig):
    pid = _read_pid()
    if pid:
        os.kill(pid, sig)


def cmd_toggle(_args):
    pid = _read_pid()
    if pid:
        os.kill(-pid, signal.SIGTERM)
        os.unlink(PIDFILE)
    else:
        p = subprocess.Popen([SETSID, sys.executable, DAEMON_SCRIPT])
        with open(PIDFILE, "w") as f:
            f.write(str(p.pid))


def cmd_daemon(_args):
    old_pid = _read_pid()
    if old_pid and old_pid != os.getpid():
        try:
            os.kill(-old_pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        except PermissionError:
            pass
        except OSError:
            try:
                os.kill(old_pid, signal.SIGTERM)
            except OSError:
                pass
    with open(PIDFILE, "w") as f:
        f.write(str(os.getpid()))
    os.execv(sys.executable, [sys.executable, DAEMON_SCRIPT])


def cmd_abort(_args):
    _signal_daemon(signal.SIGUSR1)


def cmd_reload(_args):
    _signal_daemon(signal.SIGHUP)


def cmd_review(args):
    if args.all:
        os.execv(sys.executable, [sys.executable, REVIEW_SCRIPT, "--all"])
    else:
        os.execv(sys.executable, [sys.executable, REVIEW_SCRIPT])


def cmd_train(_args):
    os.execv(sys.executable, [sys.executable, TRAIN_SCRIPT])


EPILOG = textwrap.dedent("""\
    data directory:
      %(dir)s
        corrections.json      word/phrase replacement rules
        vocabulary.txt        custom vocabulary for fuzzy matching
        transcript-log.jsonl  transcription log (with optional 'flagged' field)

    voice commands:
      "%(start_phrase)s"     begin typing when leader key is active
      "%(stop_phrase)s"      stop typing
      leader key             %(leader_key)s
      "mark that"           flag recent lines for later review
      "correct X to Y"      add a correction rule on the fly

    systemd:
      whisper-voice-type daemon
                            run under the user service
""") % {
    "dir": os.path.join(
        os.environ.get("XDG_DATA_HOME", "~/.local/share"), "moonshine-dictation"
    ),
    "start_phrase": START_PHRASE,
    "stop_phrase": STOP_PHRASE,
    "leader_key": LEADER_KEY,
}

parser = argparse.ArgumentParser(
    prog="whisper-voice-type",
    description="Voice dictation daemon with Moonshine. Without a subcommand, toggles the daemon on/off.",
    epilog=EPILOG,
    formatter_class=argparse.RawDescriptionHelpFormatter,
)
sub = parser.add_subparsers(title="commands")

p_daemon = sub.add_parser("daemon", help="run the daemon in the foreground")
p_daemon.set_defaults(func=cmd_daemon)

p_abort = sub.add_parser(
    "abort", help="discard pending dictation text (sends SIGUSR1 to daemon)"
)
p_abort.set_defaults(func=cmd_abort)

p_reload = sub.add_parser(
    "reload", help="hot-reload corrections.json and vocabulary.txt (sends SIGHUP)"
)
p_reload.set_defaults(func=cmd_reload)

p_review = sub.add_parser("review", help="interactively review transcript entries")
p_review.add_argument(
    "--all", action="store_true", help="review all entries, not just flagged"
)
p_review.set_defaults(func=cmd_review)

p_train = sub.add_parser(
    "train", help="record audio samples to generate correction rules"
)
p_train.set_defaults(func=cmd_train)

args = parser.parse_args()
if hasattr(args, "func"):
    args.func(args)
else:
    cmd_toggle(args)
