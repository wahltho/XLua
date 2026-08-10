#!/usr/bin/env python3
"""Create a deterministic XLua aircraft-component release for the Toolkit."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import zipfile
from pathlib import Path


PACKAGE_ID = "wahltho.optimized-xlua"
REPOSITORY = "https://github.com/wahltho/XLua"
SUPPORTED_PRODUCTS = ["zibo-737ng", "levelup-737ng"]
PAYLOADS = (
    ("deploy/init.lua", "init.lua", 0o644),
    ("deploy/lin_x64/xlua.xpl", "lin_x64/xlua.xpl", 0o755),
    ("deploy/mac_x64/xlua.xpl", "mac_x64/xlua.xpl", 0o755),
    ("deploy/win_x64/xlua.xpl", "win_x64/xlua.xpl", 0o755),
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def source_version(repository: Path) -> str:
    source = (repository / "src/xlua.cpp").read_text(encoding="utf-8")
    match = re.search(r'^#define VERSION "([^"]+)"$', source, re.MULTILINE)
    if match is None:
        raise ValueError("Could not read VERSION from src/xlua.cpp")
    return match.group(1)


def write_archive(repository: Path, archive_path: Path, version: str) -> list[dict[str, object]]:
    version_bytes = version.encode("ascii")
    files: list[dict[str, object]] = []
    with zipfile.ZipFile(
        archive_path,
        mode="w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=9,
    ) as archive:
        for source_relative, target_relative, mode in PAYLOADS:
            source_path = repository / source_relative
            if not source_path.is_file():
                raise FileNotFoundError(f"Required release payload is missing: {source_path}")
            payload = source_path.read_bytes()
            if target_relative.endswith("xlua.xpl") and version_bytes not in payload:
                raise ValueError(f"{source_path} does not contain expected XLua version {version}")

            archive_name = f"xlua/{target_relative}"
            info = zipfile.ZipInfo(archive_name, date_time=(1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = mode << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, payload, compresslevel=9)
            files.append(
                {
                    "path": target_relative,
                    "size": len(payload),
                    "sha256": hashlib.sha256(payload).hexdigest(),
                }
            )
    return files


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=Path("dist"))
    parser.add_argument("--release-tag")
    parser.add_argument("--channel", choices=("stable", "beta"), default="stable")
    args = parser.parse_args()

    repository = Path(__file__).resolve().parents[1]
    version = source_version(repository)
    release_tag = args.release_tag or f"r{version}"
    normalized_tag = release_tag[1:] if release_tag[:1].lower() in {"r", "v"} else release_tag
    if normalized_tag != version:
        raise ValueError(
            f"Release tag {release_tag} does not match the compiled XLua version {version}"
        )
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)

    archive_path = output / f"Xlua.{version}.zip"
    manifest_path = output / f"Xlua.{version}-manifest.json"
    files = write_archive(repository, archive_path, version)
    manifest = {
        "schemaVersion": 1,
        "packageId": PACKAGE_ID,
        "packageVersion": version,
        "releaseTag": release_tag,
        "channel": args.channel,
        "repository": REPOSITORY,
        "installScope": "aircraftInstallation",
        "targetPath": "plugins/xlua",
        "supportedProducts": SUPPORTED_PRODUCTS,
        "restartRequired": True,
        "archive": {
            "fileName": archive_path.name,
            "rootPath": "xlua",
            "size": archive_path.stat().st_size,
            "sha256": sha256(archive_path),
        },
        "protectedPaths": ["scripts/**"],
        "files": files,
    }
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(archive_path)
    print(manifest_path)


if __name__ == "__main__":
    main()
