import sys
from dictation_lib import load_log, save_log, load_corrections, save_corrections


def show_entry(i, entry, total):
    ts = entry["ts"]
    raw = entry["raw"]
    corrected = entry.get("corrected")
    print(f"\n[{i + 1}/{total}] {ts}")
    print(f"  raw: {raw}")
    if corrected:
        print(f"  corrected: {corrected}")


def review_flagged():
    entries = load_log()
    corrections = load_corrections()
    flagged = [(i, e) for i, e in enumerate(entries) if e.get("flagged")]

    if not flagged:
        print("No flagged entries.")
        return

    print(f"{len(flagged)} flagged entry/ies found.\n")
    print("Commands:")
    print("  a <wrong> -> <right>   add correction rule")
    print("  u                      unflag this entry")
    print("  s                      skip")
    print("  q                      quit\n")

    changed = False
    for idx, (log_idx, entry) in enumerate(flagged):
        show_entry(idx, entry, len(flagged))
        while True:
            try:
                cmd = input("> ").strip()
            except (EOFError, KeyboardInterrupt):
                print()
                if changed:
                    save_log(entries)
                    save_corrections(corrections)
                return

            if not cmd or cmd == "s":
                break
            elif cmd == "q":
                if changed:
                    save_log(entries)
                    save_corrections(corrections)
                return
            elif cmd == "u":
                del entries[log_idx]["flagged"]
                changed = True
                print("  unflagged.")
                break
            elif cmd.startswith("a ") and "->" in cmd:
                parts = cmd[2:].split("->", 1)
                wrong = parts[0].strip().lower()
                right = parts[1].strip()
                if wrong and right:
                    corrections[wrong] = right
                    changed = True
                    print(f'  added: "{wrong}" -> "{right}"')
                else:
                    print("  usage: a <wrong> -> <right>")
            else:
                print("  unknown command. (a/u/s/q)")

    if changed:
        save_log(entries)
        save_corrections(corrections)
    print("\nDone. Run --reload-corrections to apply changes to the running daemon.")


def review_all():
    entries = load_log()
    corrections = load_corrections()

    if not entries:
        print("No transcript entries.")
        return

    print(f"{len(entries)} entry/ies total.\n")
    print("Commands:")
    print("  a <wrong> -> <right>   add correction rule")
    print("  f                      flag this entry")
    print("  u                      unflag this entry")
    print("  s                      skip")
    print("  q                      quit\n")

    changed = False
    for idx, entry in enumerate(entries):
        flag_marker = " [FLAGGED]" if entry.get("flagged") else ""
        ts = entry["ts"]
        raw = entry["raw"]
        corrected = entry.get("corrected")
        print(f"\n[{idx + 1}/{len(entries)}]{flag_marker} {ts}")
        print(f"  raw: {raw}")
        if corrected:
            print(f"  corrected: {corrected}")
        while True:
            try:
                cmd = input("> ").strip()
            except (EOFError, KeyboardInterrupt):
                print()
                if changed:
                    save_log(entries)
                    save_corrections(corrections)
                return

            if not cmd or cmd == "s":
                break
            elif cmd == "q":
                if changed:
                    save_log(entries)
                    save_corrections(corrections)
                return
            elif cmd == "f":
                entries[idx]["flagged"] = True
                changed = True
                print("  flagged.")
                break
            elif cmd == "u":
                entries[idx].pop("flagged", None)
                changed = True
                print("  unflagged.")
                break
            elif cmd.startswith("a ") and "->" in cmd:
                parts = cmd[2:].split("->", 1)
                wrong = parts[0].strip().lower()
                right = parts[1].strip()
                if wrong and right:
                    corrections[wrong] = right
                    changed = True
                    print(f'  added: "{wrong}" -> "{right}"')
                else:
                    print("  usage: a <wrong> -> <right>")
            else:
                print("  unknown command. (a/f/u/s/q)")

    if changed:
        save_log(entries)
        save_corrections(corrections)
    print("\nDone. Run --reload-corrections to apply changes to the running daemon.")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--all":
        review_all()
    else:
        review_flagged()
