"""Apply or roll back a local bundle deployment using retained ZIP files."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
from tempfile import TemporaryDirectory
from datetime import datetime

from build import ROOT, MANIFEST, file_sha, save_json


def game_running():
    proc = subprocess.run(["tasklist.exe", "/FO", "CSV", "/NH"], check=True,
                          capture_output=True, text=True, errors="replace")
    return any(line.casefold().startswith(('"bb-launcher-gog.exe",', '"battlebrothers.exe",'))
               for line in proc.stdout.splitlines())


def desired_files(manifest, snapshot, profile, enable_groups):
    if profile == "original":
        return {s["name"]: (snapshot / "packages" / s["name"], s["sha256"])
                for s in manifest["sources"] if not s.get("modular_only")}
    build = ROOT / "dist" / profile
    report = json.loads((build / "deployment.json").read_text(encoding="utf-8"))
    if set(report["generated"]) != set(manifest["outputs"]):
        raise ValueError("Deployment requires a complete build")
    enabled = set(enable_groups or manifest["outputs"])
    if enabled - set(manifest["outputs"]):
        raise ValueError(f"Invalid output name: {enabled - set(manifest['outputs'])}")
    desired = {s["name"]: (snapshot / "packages" / s["name"], s["sha256"])
               for s in manifest["sources"]
               if s["output"] not in enabled and (profile == "modular" or not s.get("modular_only"))}
    desired.update({name: (build / name, report["generated"][name]) for name in enabled})
    return desired


def deploy(data, snapshot, desired, profile):
    ledger = snapshot / "active.json"
    reference = ledger if ledger.exists() else snapshot / "original.json"
    previous = json.loads(reference.read_text(encoding="utf-8"))
    current = {p.name: file_sha(p) for p in data.glob("*.zip")}
    if current != previous:
        raise ValueError(f"Active files differ from ledger: "
                         f"{sorted(n for n in current.keys() | previous.keys() if current.get(n) != previous.get(n))}")
    target = {name: checksum for name, (_, checksum) in desired.items()}
    changed = {name for name in current.keys() | target.keys() if current.get(name) != target.get(name)}
    if not changed:
        print(f"Already active: {profile} ({len(target)} ZIPs)")
        return
    if game_running():
        raise ValueError("Exit Battle Brothers and its launcher first")
    retained = snapshot / "deployments" / datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    retained.mkdir(parents=True)
    save_json(retained / "previous.json", previous)
    save_json(retained / "next.json", target)
    removed, added = [], []
    with TemporaryDirectory(prefix="deploy-", dir=snapshot) as temp:
        staging = Path(temp)
        for name in sorted(changed & desired.keys()):
            source, checksum = desired[name]
            staged = staging / name
            shutil.copy2(source, staged)
            if file_sha(staged) != checksum:
                raise ValueError(f"Deploy source changed: {source}")
        if game_running():
            raise ValueError("The game started during staging")
        try:
            for name in sorted(changed & current.keys()):
                (data / name).rename(retained / name)
                removed.append(name)
            for name in sorted(changed & target.keys()):
                (staging / name).rename(data / name)
                added.append(name)
            if {p.name: file_sha(p) for p in data.glob("*.zip")} != target:
                raise ValueError("Final deployment did not match target")
            save_json(staging / "active.json", target)
            (staging / "active.json").replace(ledger)
        except Exception:
            for name in reversed(added):
                (data / name).rename(staging / name)
            for name in reversed(removed):
                (retained / name).rename(data / name)
            raise
    print(f"Deployed {profile}: {len(current)} → {len(target)} ZIPs")
    print(f"Retained replaced files in {retained}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("profile", choices=("original", "repack", "modular"))
    parser.add_argument("--group", action="append", help="Deploy only these bundle groups")
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    snapshot = ROOT.parent / manifest["snapshot"]
    deploy(ROOT.parent / "data", snapshot,
           desired_files(manifest, snapshot, args.profile, args.group), args.profile)


if __name__ == "__main__":
    main()
