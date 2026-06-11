import os
import json
import re
import difflib
import datetime

DATA_DIR = os.path.join(
    os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share")),
    "moonshine-dictation",
)
CORRECTIONS_FILE = os.path.join(DATA_DIR, "corrections.json")
VOCABULARY_FILE = os.path.join(DATA_DIR, "vocabulary.txt")
TRANSCRIPT_LOG = os.path.join(DATA_DIR, "transcript-log.jsonl")

VOCAB_SIMILARITY_THRESHOLD = 0.85
FLAG_WINDOW_SECS = 60

_COMPOUND_RE = re.compile(r"[-_]")
MARK_THAT_RE = re.compile(r"\bmark\s+that\b", re.IGNORECASE)
CORRECT_RE = re.compile(r'\bcorrect\s+"([^"]+)"\s+to\s+"([^"]+)"\s*$', re.IGNORECASE)
CORRECT_SPOKEN_RE = re.compile(r"\bcorrect\s+(.+?)\s+to\s+(.+)$", re.IGNORECASE)

os.makedirs(DATA_DIR, exist_ok=True)


def load_corrections():
    try:
        with open(CORRECTIONS_FILE) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def save_corrections(corrections):
    with open(CORRECTIONS_FILE, "w") as f:
        json.dump(corrections, f, indent=2)


def load_vocabulary():
    try:
        with open(VOCABULARY_FILE) as f:
            return [w.strip() for w in f if w.strip() and not w.startswith("#")]
    except FileNotFoundError:
        return []


def save_vocabulary(vocab):
    with open(VOCABULARY_FILE, "w") as f:
        for w in vocab:
            f.write(w + "\n")


def load_log():
    try:
        with open(TRANSCRIPT_LOG) as f:
            return [json.loads(line) for line in f if line.strip()]
    except FileNotFoundError:
        return []


def save_log(entries):
    with open(TRANSCRIPT_LOG, "w") as f:
        for e in entries:
            f.write(json.dumps(e) + "\n")


def log_transcript(raw, corrected):
    entry = {
        "ts": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "raw": raw,
    }
    if corrected != raw:
        entry["corrected"] = corrected
    with open(TRANSCRIPT_LOG, "a") as f:
        f.write(json.dumps(entry) + "\n")


def flag_recent_lines():
    try:
        with open(TRANSCRIPT_LOG) as f:
            lines = f.readlines()
    except FileNotFoundError:
        return
    now = datetime.datetime.now(datetime.timezone.utc)
    cutoff = now - datetime.timedelta(seconds=FLAG_WINDOW_SECS)
    changed = False
    for i in range(len(lines) - 1, -1, -1):
        entry = json.loads(lines[i])
        ts = datetime.datetime.fromisoformat(entry["ts"])
        if ts < cutoff:
            break
        if "flagged" not in entry:
            entry["flagged"] = True
            lines[i] = json.dumps(entry) + "\n"
            changed = True
    if changed:
        with open(TRANSCRIPT_LOG, "w") as f:
            f.writelines(lines)


def _normalize_compound(s):
    return _COMPOUND_RE.sub("", s).lower()


def apply_vocabulary(text, vocabulary):
    if not vocabulary:
        return text
    words = text.split()
    i = 0
    while i < len(words):
        best_match = None
        best_ratio = VOCAB_SIMILARITY_THRESHOLD
        best_span = 0
        for entry in vocabulary:
            entry_word_count = len(entry.split())
            span_words = words[i : i + entry_word_count]
            if len(span_words) == entry_word_count:
                span = " ".join(span_words)
                shorter = min(len(span), len(entry))
                longer = max(len(span), len(entry))
                if shorter / longer >= 0.75:
                    ratio = difflib.SequenceMatcher(
                        None, span.lower(), entry.lower()
                    ).ratio()
                    if ratio > best_ratio:
                        best_ratio = ratio
                        best_match = entry
                        best_span = entry_word_count
            if entry_word_count == 1 and len(entry) >= 6:
                entry_norm = _normalize_compound(entry)
                for n in range(2, min(7, len(words) - i + 1)):
                    merged = "".join(w.lower() for w in words[i : i + n])
                    shorter = min(len(merged), len(entry_norm))
                    longer = max(len(merged), len(entry_norm))
                    if shorter / longer < 0.75:
                        continue
                    ratio = difflib.SequenceMatcher(None, merged, entry_norm).ratio()
                    if ratio > best_ratio:
                        best_ratio = ratio
                        best_match = entry
                        best_span = n
        if best_match:
            words[i : i + best_span] = [best_match]
            i += 1
        else:
            i += 1
    return " ".join(words)


def apply_corrections(text, corrections):
    if not corrections:
        return text
    for wrong, right in corrections.items():
        text = re.sub(re.escape(wrong), right, text, flags=re.IGNORECASE)
    return text


def apply_pipeline(text, vocabulary, corrections):
    return apply_corrections(apply_vocabulary(text, vocabulary), corrections)
