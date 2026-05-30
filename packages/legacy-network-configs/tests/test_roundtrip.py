import tempfile
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
import sys


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from wifi_profile_convert import (  # noqa: E402
    WifiProfile,
    convert_legacy_profiles,
    iwd_filename_for_profile,
    nm_filename_for_profile,
    profile_from_iwd_network,
    profile_from_nm_keyfile,
    render_iwd_network,
    render_nm_keyfile,
)


PROFILES = [
    WifiProfile(
        ssid="Home WiFi",
        security="psk",
        passphrase="correct horse battery staple",
        autoconnect=True,
        hidden=False,
    ),
    WifiProfile(
        ssid="Cafe:East",
        security="open",
        autoconnect=False,
        hidden=True,
    ),
    WifiProfile(
        ssid=" leading\\tabs\tand\nnewlines",
        security="psk",
        passphrase="  secret\\with\tchars",
        autoconnect=False,
        hidden=True,
    ),
]


def roundtrip_nm_iwd_nm(profile, tmpdir):
    nm_path = tmpdir / nm_filename_for_profile(profile)
    nm_path.write_text(render_nm_keyfile(profile), encoding="utf-8")

    from_nm = profile_from_nm_keyfile(nm_path)
    iwd_path = tmpdir / iwd_filename_for_profile(from_nm)
    iwd_path.write_text(render_iwd_network(from_nm), encoding="utf-8")

    from_iwd = profile_from_iwd_network(iwd_path)
    nm_again = tmpdir / f"again-{nm_filename_for_profile(from_iwd)}"
    nm_again.write_text(render_nm_keyfile(from_iwd), encoding="utf-8")

    return profile_from_nm_keyfile(nm_again)


def roundtrip_iwd_nm_iwd(profile, tmpdir):
    iwd_path = tmpdir / iwd_filename_for_profile(profile)
    iwd_path.write_text(render_iwd_network(profile), encoding="utf-8")

    from_iwd = profile_from_iwd_network(iwd_path)
    nm_path = tmpdir / nm_filename_for_profile(from_iwd)
    nm_path.write_text(render_nm_keyfile(from_iwd), encoding="utf-8")

    from_nm = profile_from_nm_keyfile(nm_path)
    iwd_again_dir = tmpdir / "iwd-again"
    iwd_again_dir.mkdir(exist_ok=True)
    iwd_again = iwd_again_dir / iwd_filename_for_profile(from_nm)
    iwd_again.write_text(render_iwd_network(from_nm), encoding="utf-8")

    return profile_from_iwd_network(iwd_again)


def main():
    with tempfile.TemporaryDirectory() as tmp:
        tmpdir = Path(tmp)
        for profile in PROFILES:
            assert roundtrip_nm_iwd_nm(profile, tmpdir) == profile
            assert roundtrip_iwd_nm_iwd(profile, tmpdir) == profile

        missing_source = tmpdir / "missing-networkmanager"
        destination = tmpdir / "iwd-destination"
        output = StringIO()
        with redirect_stdout(output):
            convert_legacy_profiles(
                "iwd",
                [f"networkmanager={missing_source}"],
                destination,
                dry_run=False,
                force=False,
            )

        assert output.getvalue().strip() == "converted=0 cleaned=0 skipped=0"
        assert not destination.exists()

        nm_source = tmpdir / "nm-source"
        nm_source.mkdir()
        existing_profile = PROFILES[0]
        nm_existing = nm_source / nm_filename_for_profile(existing_profile)
        nm_existing.write_text(render_nm_keyfile(existing_profile), encoding="utf-8")
        nm_enterprise = nm_source / "enterprise.nmconnection"
        nm_enterprise.write_text(
            "\n".join(
                [
                    "[connection]",
                    "id=Enterprise",
                    "type=wifi",
                    "",
                    "[wifi]",
                    "ssid=Enterprise",
                    "",
                    "[wifi-security]",
                    "key-mgmt=ieee8021x",
                    "",
                ]
            ),
            encoding="utf-8",
        )

        destination.mkdir()
        (destination / iwd_filename_for_profile(existing_profile)).write_text(
            render_iwd_network(existing_profile),
            encoding="utf-8",
        )

        output = StringIO()
        with redirect_stdout(output):
            convert_legacy_profiles(
                "iwd",
                [f"networkmanager={nm_source}"],
                destination,
                dry_run=False,
                force=False,
            )

        assert output.getvalue().strip() == "converted=0 cleaned=1 skipped=1"
        assert not nm_existing.exists()
        assert nm_enterprise.exists()

        nm_existing.write_text(render_nm_keyfile(existing_profile), encoding="utf-8")

        output = StringIO()
        with redirect_stdout(output):
            convert_legacy_profiles(
                "iwd",
                [f"networkmanager={nm_source}"],
                destination,
                dry_run=False,
                force=False,
                show_skipped=True,
                cleanup=False,
            )

        assert "skipped networkmanager:enterprise.nmconnection" in output.getvalue()
        assert "already exists" in output.getvalue()
        assert output.getvalue().strip().endswith("converted=0 cleaned=0 skipped=2")
        assert nm_existing.exists()

    print("roundtrip tests passed")


if __name__ == "__main__":
    main()
