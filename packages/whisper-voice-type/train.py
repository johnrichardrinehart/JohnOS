import sys
import re
import time
import queue
import difflib
import sounddevice as sd
from moonshine_voice import Transcriber, TranscriptEventListener, ModelArch
from dictation_lib import (
    load_corrections,
    save_corrections,
    load_vocabulary,
    save_vocabulary,
    apply_pipeline,
)

MODEL_PATH = sys.argv[1]
MODEL_ARCH = ModelArch(int(sys.argv[2]))
SAMPLE_RATE = 16000

print("Loading model…")
transcriber = Transcriber(
    model_path=MODEL_PATH,
    model_arch=MODEL_ARCH,
    update_interval=999999,
    options={"vad_window_duration": "0.3"},
)

lines_lock = queue.Queue()


class TrainListener(TranscriptEventListener):
    def on_line_completed(self, event):
        text = event.line.text.strip()
        if text:
            lines_lock.put(text)


transcriber.add_listener(TrainListener())
transcriber.start()
stream = transcriber.get_default_stream()

audio_q = queue.Queue()


def audio_callback(indata, frames, time_info, status):
    audio_q.put(indata[:, 0].copy())


def record_and_transcribe(duration):
    while not audio_q.empty():
        audio_q.get_nowait()
    while not lines_lock.empty():
        lines_lock.get_nowait()

    with sd.InputStream(
        samplerate=SAMPLE_RATE,
        channels=1,
        dtype="float32",
        blocksize=int(SAMPLE_RATE * 0.1),
        callback=audio_callback,
    ):
        end_time = time.time() + duration
        while time.time() < end_time:
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
        time.sleep(0.3)
        while True:
            try:
                chunk = audio_q.get_nowait()
                stream.add_audio(chunk.tolist(), SAMPLE_RATE)
            except queue.Empty:
                break
        stream.update_transcription()
        time.sleep(0.3)

    results = []
    while not lines_lock.empty():
        results.append(lines_lock.get_nowait())
    return results


def normalize(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())


def generate_corrections(target, variants):
    corrections = {}
    target_norm = normalize(target)
    for variant in variants:
        variant_stripped = variant.strip().rstrip(".,!?;:")
        if normalize(variant_stripped) == target_norm:
            continue
        if variant_stripped.lower() == target.lower():
            continue
        corrections[variant_stripped.lower()] = target
    return corrections


print("Model loaded.\n")
print("=== Dictation Training ===")
print("Type the target word/phrase, then speak it several times.")
print("Each recording is 4 seconds. Press Ctrl-C to finish.\n")

corrections = load_corrections()
vocabulary = load_vocabulary()
new_corrections = {}
new_vocab = set()

try:
    while True:
        try:
            target = input("Target word/phrase (or 'q' to quit): ").strip()
        except EOFError:
            break
        if not target or target.lower() == "q":
            break

        all_variants = []
        round_num = 0
        while True:
            round_num += 1
            try:
                input(
                    f"  Round {round_num}: press Enter then say \"{target}\" (or 'done'): "
                )
            except EOFError:
                break

            print("  Recording 4s…")
            results = record_and_transcribe(4.0)

            if not results:
                print("  (nothing detected)")
                continue

            for r in results:
                transcribed = apply_pipeline(r, vocabulary, corrections)
                sim = difflib.SequenceMatcher(
                    None, normalize(transcribed), normalize(target)
                ).ratio()
                marker = "ok" if sim > 0.6 else "?"
                print(f'  {marker} decoded:       "{r}"')
                if transcribed != r:
                    print(f'    transcription: "{transcribed}"')
                print(f"    similarity:    {sim:.2f}")

            all_variants.extend(results)

            try:
                cont = input("  Another round? [Y/n/done]: ").strip().lower()
            except EOFError:
                break
            if cont in ("n", "done"):
                break

        if all_variants:
            new_rules = generate_corrections(target, all_variants)
            if new_rules:
                print(f'\n  Generated correction rules for "{target}":')
                for wrong, right in new_rules.items():
                    print(f'    "{wrong}" -> "{right}"')
                new_corrections.update(new_rules)

            if target not in vocabulary and target not in new_vocab:
                try:
                    add_vocab = (
                        input(f'  Add "{target}" to vocabulary? [Y/n]: ')
                        .strip()
                        .lower()
                    )
                except EOFError:
                    add_vocab = ""
                if add_vocab != "n":
                    new_vocab.add(target)
                    print("  Added to vocabulary.")
            print()

except KeyboardInterrupt:
    print()

transcriber.stop()
transcriber.close()

if new_corrections or new_vocab:
    print("\n=== Summary ===")
    if new_corrections:
        corrections.update(new_corrections)
        save_corrections(corrections)
        print(f"Saved {len(new_corrections)} correction rule(s).")
        for wrong, right in new_corrections.items():
            print(f'  "{wrong}" -> "{right}"')
    if new_vocab:
        vocabulary.extend(sorted(new_vocab))
        save_vocabulary(vocabulary)
        print(f"Added {len(new_vocab)} vocabulary entry/ies.")
    print("\nRun --reload-corrections to apply to running daemon.")
else:
    print("\nNo changes.")
