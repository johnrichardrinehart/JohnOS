import configparser
import os
import re
from dataclasses import dataclass
from pathlib import Path


NM_SOURCE = Path("/etc/NetworkManager/system-connections")
IWD_SOURCE = Path("/var/lib/iwd")
IWD_DESTINATION = IWD_SOURCE
NM_DESTINATION = NM_SOURCE


@dataclass(frozen=True)
class WifiProfile:
    ssid: str
    security: str
    passphrase: str | None = None
    autoconnect: bool = True
    hidden: bool = False


def unescape_keyfile_value(value):
    replacements = {
        "n": "\n",
        "r": "\r",
        "s": " ",
        "t": "\t",
        "\\": "\\",
    }

    result = []
    escaping = False
    for char in value:
        if escaping:
            result.append(replacements.get(char, char))
            escaping = False
        elif char == "\\":
            escaping = True
        else:
            result.append(char)

    if escaping:
        result.append("\\")

    return "".join(result)


def escape_keyfile_value(value):
    escaped = value.replace("\\", "\\\\")
    escaped = escaped.replace("\n", "\\n").replace("\r", "\\r")
    escaped = escaped.replace("\t", "\\t")

    leading_spaces = len(escaped) - len(escaped.lstrip(" "))
    if leading_spaces:
        escaped = ("\\s" * leading_spaces) + escaped[leading_spaces:]

    return escaped


def iwd_network_name(ssid, security):
    safe = all(
        char in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 _-"
        for char in ssid
    )
    stem = ssid if safe else f"={ssid.encode('utf-8').hex()}"
    return f"{stem}.{security}"


def ssid_from_iwd_network_name(name):
    stem, security = name.rsplit(".", 1)
    if stem.startswith("="):
        ssid = bytes.fromhex(stem[1:]).decode("utf-8")
    else:
        ssid = stem

    return ssid, security


def nm_connection_name(ssid):
    safe = re.sub(r"[^A-Za-z0-9_. -]+", "_", ssid).strip(" .")
    return safe or "wifi"


def bool_from_value(value, default):
    if value is None:
        return default

    normalized = value.strip().lower()
    if normalized in {"1", "true", "yes"}:
        return True
    if normalized in {"0", "false", "no"}:
        return False

    return default


def parser_for(path):
    parser = configparser.ConfigParser(
        interpolation=None,
        strict=False,
        delimiters=("=",),
    )
    parser.optionxform = str

    with path.open(encoding="utf-8") as keyfile:
        parser.read_file(keyfile)

    return parser


def profile_from_nm_keyfile(path):
    parser = parser_for(path)

    connection_type = parser.get("connection", "type", fallback="")
    if connection_type not in {"802-11-wireless", "wifi"}:
        return None

    ssid = parser.get("wifi", "ssid", fallback=None)
    if ssid is None:
        ssid = parser.get("802-11-wireless", "ssid", fallback=None)
    if not ssid:
        raise ValueError("missing Wi-Fi SSID")

    security = "open"
    passphrase = None
    key_mgmt = parser.get("wifi-security", "key-mgmt", fallback="")

    if key_mgmt in {"wpa-psk", "sae"}:
        psk = parser.get("wifi-security", "psk", fallback=None)
        if not psk:
            raise ValueError("WPA-PSK profile has no stored PSK/passphrase")

        security = "psk"
        passphrase = unescape_keyfile_value(psk)
    elif key_mgmt in {"", "none", "owe"}:
        security = "open"
    else:
        raise ValueError(f"unsupported key-mgmt '{key_mgmt}'")

    return WifiProfile(
        ssid=unescape_keyfile_value(ssid),
        security=security,
        passphrase=passphrase,
        autoconnect=bool_from_value(
            parser.get("connection", "autoconnect", fallback=None),
            True,
        ),
        hidden=bool_from_value(parser.get("wifi", "hidden", fallback=None), False),
    )


def profile_from_iwd_network(path):
    ssid, security = ssid_from_iwd_network_name(path.name)
    if security not in {"open", "psk"}:
        raise ValueError(f"unsupported iwd security type '{security}'")

    parser = parser_for(path)
    passphrase = None
    if security == "psk":
        passphrase = parser.get("Security", "Passphrase", fallback=None)
        if not passphrase:
            raise ValueError("iwd PSK profile has no stored passphrase")
        passphrase = unescape_keyfile_value(passphrase)

    return WifiProfile(
        ssid=ssid,
        security=security,
        passphrase=passphrase,
        autoconnect=bool_from_value(
            parser.get("Settings", "AutoConnect", fallback=None),
            True,
        ),
        hidden=bool_from_value(parser.get("Settings", "Hidden", fallback=None), False),
    )


def render_iwd_network(profile):
    lines = []

    if profile.security == "psk":
        if not profile.passphrase:
            raise ValueError("PSK profile has no passphrase")

        lines.extend(
            [
                "[Security]",
                f"Passphrase={escape_keyfile_value(profile.passphrase)}",
                "",
            ]
        )
    elif profile.security != "open":
        raise ValueError(f"unsupported security type '{profile.security}'")

    settings = [f"AutoConnect={'true' if profile.autoconnect else 'false'}"]
    if profile.hidden:
        settings.append("Hidden=true")

    lines.extend(["[Settings]", *settings, ""])
    return "\n".join(lines)


def render_nm_keyfile(profile):
    lines = [
        "[connection]",
        f"id={escape_keyfile_value(profile.ssid)}",
        "type=wifi",
        f"autoconnect={'true' if profile.autoconnect else 'false'}",
        "",
        "[wifi]",
        f"ssid={escape_keyfile_value(profile.ssid)}",
    ]

    if profile.hidden:
        lines.append("hidden=true")

    if profile.security == "psk":
        if not profile.passphrase:
            raise ValueError("PSK profile has no passphrase")

        lines.extend(
            [
                "",
                "[wifi-security]",
                "key-mgmt=wpa-psk",
                f"psk={escape_keyfile_value(profile.passphrase)}",
            ]
        )
    elif profile.security != "open":
        raise ValueError(f"unsupported security type '{profile.security}'")

    lines.append("")
    return "\n".join(lines)


def iwd_filename_for_profile(profile):
    return iwd_network_name(profile.ssid, profile.security)


def nm_filename_for_profile(profile):
    return f"{nm_connection_name(profile.ssid)}.nmconnection"


def iter_files(source):
    if not source.exists():
        return

    for path in sorted(source.iterdir()):
        if path.is_file():
            yield path


def write_profile_file(destination, name, contents, force):
    destination.mkdir(mode=0o700, parents=True, exist_ok=True)
    target = destination / name

    if target.exists() and not force:
        raise FileExistsError(f"{target} already exists; use --force to replace it")

    temporary = target.with_name(f".{target.name}.tmp")
    temporary.write_text(contents, encoding="utf-8")
    temporary.chmod(0o600)
    os.replace(temporary, target)


def remove_source_file(path):
    path.unlink()


def destination_matches(path, contents):
    try:
        return path.read_text(encoding="utf-8") == contents
    except UnicodeDecodeError:
        return False


SOURCE_HANDLERS = {
    "networkmanager": {
        "default_path": NM_SOURCE,
        "read": profile_from_nm_keyfile,
    },
    "iwd": {
        "default_path": IWD_SOURCE,
        "read": profile_from_iwd_network,
    },
}


DESTINATION_HANDLERS = {
    "networkmanager": {
        "default_path": NM_DESTINATION,
        "filename": nm_filename_for_profile,
        "render": render_nm_keyfile,
        "description": "NetworkManager keyfile",
    },
    "iwd": {
        "default_path": IWD_DESTINATION,
        "filename": iwd_filename_for_profile,
        "render": render_iwd_network,
        "description": "iwd network",
    },
}


def parse_source_specs(source_specs):
    sources = {}
    for spec in source_specs:
        if "=" not in spec:
            raise ValueError(f"source must be MANAGER=PATH, got '{spec}'")

        manager, path = spec.split("=", 1)
        if manager not in SOURCE_HANDLERS:
            supported = ", ".join(sorted(SOURCE_HANDLERS))
            raise ValueError(
                f"unsupported source manager '{manager}'; supported: {supported}"
            )

        sources[manager] = Path(path)

    return sources


def convert_legacy_profiles(
    destination_manager,
    source_specs,
    destination,
    dry_run,
    force,
    show_skipped=False,
    cleanup=True,
):
    destination_handler = DESTINATION_HANDLERS[destination_manager]
    destination = destination or destination_handler["default_path"]
    source_overrides = parse_source_specs(source_specs)

    source_paths = {
        manager: handler["default_path"]
        for manager, handler in SOURCE_HANDLERS.items()
        if manager != destination_manager
    }
    source_paths.update(source_overrides)

    converted = 0
    cleaned = 0
    skipped = 0

    for source_manager, source in sorted(source_paths.items()):
        source_handler = SOURCE_HANDLERS[source_manager]
        for path in iter_files(source):
            try:
                profile = source_handler["read"](path)
                if profile is None:
                    continue

                name = destination_handler["filename"](profile)
                contents = destination_handler["render"](profile)
                target = destination / name

                if dry_run:
                    if target.exists() and destination_matches(target, contents):
                        if cleanup:
                            print(
                                f"would remove {source_manager}:{path.name}; already imported at {target}"
                            )
                            cleaned += 1
                        else:
                            skipped += 1
                            if show_skipped:
                                print(
                                    f"skipped {source_manager}:{path.name}: {target} already exists"
                                )
                    elif target.exists() and not force:
                        skipped += 1
                        if show_skipped:
                            print(
                                f"skipped {source_manager}:{path.name}: {target} already exists with different contents; use --force to replace it"
                            )
                    else:
                        action = "would write"
                        cleanup_suffix = " and remove source" if cleanup else ""
                        print(
                            f"{action} {target} from {source_manager}:{path.name}{cleanup_suffix}"
                        )
                        converted += 1
                        if cleanup:
                            cleaned += 1
                else:
                    if target.exists() and not force:
                        if destination_matches(target, contents):
                            if cleanup:
                                remove_source_file(path)
                                cleaned += 1
                            else:
                                skipped += 1
                                if show_skipped:
                                    print(
                                        f"skipped {source_manager}:{path.name}: {target} already exists"
                                    )
                        else:
                            raise FileExistsError(
                                f"{target} already exists with different contents; use --force to replace it"
                            )
                    else:
                        write_profile_file(destination, name, contents, force)
                        print(f"wrote {target} from {source_manager}:{path.name}")
                        converted += 1
                        if cleanup:
                            remove_source_file(path)
                            cleaned += 1
            except Exception as error:
                skipped += 1
                if show_skipped:
                    print(f"skipped {source_manager}:{path.name}: {error}")

    print(f"converted={converted} cleaned={cleaned} skipped={skipped}")
