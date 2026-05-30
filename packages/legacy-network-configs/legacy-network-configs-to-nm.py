#!/usr/bin/env python3
import argparse

from wifi_profile_convert import NM_DESTINATION, convert_legacy_profiles


def main():
    parser = argparse.ArgumentParser(
        description="Import supported legacy Wi-Fi configs into NetworkManager.",
    )
    parser.add_argument(
        "--destination",
        type=type(NM_DESTINATION),
        default=NM_DESTINATION,
        help=f"NetworkManager keyfile directory, default: {NM_DESTINATION}",
    )
    parser.add_argument(
        "--source",
        action="append",
        default=[],
        metavar="MANAGER=PATH",
        help="override or add a source directory for a supported manager",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="show which profiles would be written without writing secrets",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="replace existing NetworkManager profiles",
    )
    parser.add_argument(
        "--show-skipped",
        action="store_true",
        help="print one line for each skipped legacy profile",
    )
    parser.add_argument(
        "--no-cleanup",
        action="store_true",
        help="leave source profiles in place after successful import",
    )
    args = parser.parse_args()

    convert_legacy_profiles(
        "networkmanager",
        args.source,
        args.destination,
        args.dry_run,
        args.force,
        show_skipped=args.show_skipped,
        cleanup=not args.no_cleanup,
    )


if __name__ == "__main__":
    main()
