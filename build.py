"""Build deployment archives from the frozen, individually maintained sources."""
import argparse
from collections import defaultdict
from contextlib import ExitStack
import hashlib
import json
from pathlib import Path, PurePosixPath
import struct
from tempfile import TemporaryDirectory
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parent
MANIFEST = ROOT / "manifest.json"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def file_sha(path):
    with path.open("rb") as file:
        return hashlib.file_digest(file, "sha256").hexdigest()


def save_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def member_key(name):
    name = name.replace("\\", "/").casefold()
    return name.removesuffix(".cnut") + ".nut" if name.endswith(".cnut") else name


def raw_name(info):
    utf8 = info.flag_bits & 0x800
    return info.orig_filename.encode("utf-8" if utf8 else "cp437"), utf8


def name_extra(info):
    """Keep the Unicode spelling override for legacy filenames."""
    extra = info.extra
    while len(extra) >= 4:
        tag, length = struct.unpack_from("<HH", extra)
        if tag == 0x7075:
            return extra[:4 + length]
        extra = extra[4 + length:]
    return b""


class ArchiveMember(ZipInfo):
    """Carry the legacy member-name bytes and encoding bit through zipfile."""

    def __init__(self, name, encoding, extra):
        self.encoding = encoding
        super().__init__(name)
        self.extra = extra

    def _encodeFilenameFlags(self):
        raw, utf8 = self.encoding
        return raw, (self.flag_bits & ~0x800) | utf8


def validate_path(name):
    path = PurePosixPath(name.replace("\\", "/"))
    if path.is_absolute() or ".." in path.parts or ":" in name:
        raise ValueError(f"Unsafe archive member: {name!r}")


def inventory(manifest, archive, stack):
    sources = {}
    for source in manifest["sources"]:
        name = source["name"]
        path = ROOT.parent / source["archive"] if "archive" in source else archive / name
        if file_sha(path) != source["sha256"]:
            raise ValueError(f"Changed source archive: {name}")
        z = stack.enter_context(ZipFile(path))
        seen = set()
        for entry in z.infolist():
            validate_path(entry.filename)
            key = member_key(entry.filename)
            if key in seen:
                raise ValueError(f"Duplicate member {name}:{entry.filename}")
            seen.add(key)
        sources[name] = (source, z)
    return sources


def exclusion_plan(manifest, sources):
    paths = defaultdict(list)
    for name, (_, z) in sources.items():
        for entry in z.infolist():
            if not entry.is_dir():
                paths[member_key(entry.filename)].append((name, entry))
    actual = {path for path, entries in paths.items() if len(entries) > 1}
    if actual != manifest["conflicts"].keys():
        raise ValueError(f"Unaccounted overlapping paths: {actual ^ manifest['conflicts'].keys()}")

    exclusions = set()
    conflict_report = {}
    for path, policy in manifest["conflicts"].items():
        entries = paths[path]
        observed = [name for name, _ in entries]
        if sorted(observed) != sorted(policy["providers"]):
            raise ValueError(f"Changed providers for {path}: {observed}")
        details = {}
        for name, entry in entries:
            details[name] = sha(sources[name][1].read(entry))
            if name in policy["omit"]:
                exclusions.add((name, entry.filename))
        if policy.get("same_bytes") and len(set(details.values())) != 1:
            raise ValueError(f"Identical-copy assumption failed for {path}")
        if policy.get("winner"):
            remaining = [name for name, _ in entries if name not in policy["omit"]]
            winner = max(remaining, key=lambda name: (sources[name][0]["output"] or name).casefold())
            original = max(observed, key=str.casefold)
            if winner != policy["winner"] or details[original] != details[winner]:
                raise ValueError(f"Override order changed for {path}: {original} → {winner}")
        conflict_report[path] = {**policy, "source_member_sha256": details}
    return exclusions, conflict_report


def module_collisions(manifest, sources):
    """Reject module files whose virtual path another ZIP or module also provides."""
    replaced = {(m["source"], member_key(name)) for m in manifest["modules"] for name in m["members"]}
    providers = defaultdict(list)
    for name, (_, z) in sources.items():
        for entry in z.infolist():
            key = member_key(entry.filename)
            if not entry.is_dir() and (name, key) not in replaced:
                providers[key].append(name)
    owners = {}
    for module in manifest["modules"]:
        base = ROOT / module["directory"]
        for file in sorted(base.rglob("*")):
            if not file.is_file():
                continue
            name = file.relative_to(base).as_posix()
            validate_path(name)
            key = member_key(name)
            if key in owners:
                raise ValueError(f"Module path {name} in both {owners[key]} and {module['directory']}")
            owners[key] = module["directory"]
            if providers[key]:
                raise ValueError(f"Module path {name} from {module['directory']} "
                                 f"is also provided by {sorted(providers[key])}")
    return len(owners)


def validate_virtual_layout(source, name):
    validate_path(name)
    if source["output"] and name.casefold().startswith(("mod_reforged_core", "mod_reforged_assets")):
        raise ValueError(f"Unexpected reserved Reforged prefix: {name}")


def collect(manifest, sources, exclusions, profile, individual, disabled):
    groups = {name: {} for name in manifest["outputs"] if not individual}
    omissions = {}
    modular = manifest["modules"] if profile == "modular" else []
    patches = [json.loads((ROOT / name).read_text(encoding="utf-8"))
               for name in manifest["patches"]] if profile == "modular" else []
    replaced = {}
    for module in modular:
        for member in module["members"]:
            replaced[(module["source"], member)] = module
    unused = set(replaced)
    for name, (source, z) in sources.items():
        output = source["output"]
        if source.get("modular_only") and profile != "modular":
            continue
        if not output or (individual and individual != name):
            continue
        entries = groups.setdefault(name if individual else output, {})
        for entry in z.infolist():
            if entry.is_dir():
                continue
            origin = (name, entry.filename)
            if origin in exclusions and not individual:
                continue
            data = z.read(entry)
            if origin in replaced:
                module = replaced[origin]
                unused.discard(origin)
                omissions[f"{name}:{entry.filename}"] = module["directory"]
                continue
            for patch in patches:
                if origin != (patch["source"], patch["member"]):
                    continue
                if sha(data) != patch["before"] or data.count(patch["old"].encode()) != 1:
                    raise ValueError(f"Patch no longer applies: {origin}")
                data = data.replace(patch["old"].encode(), patch["new"].encode())
                if sha(data) != patch["after"]:
                    raise ValueError(f"Unexpected patched bytes: {origin}")
            add_member(entries, entry.filename, raw_name(entry), data, name, name_extra(entry))
    for module in modular:
        if individual and module["source"] != individual:
            continue
        if module["directory"] in disabled:
            continue
        source = sources[module["source"]][0]
        output = module.get("output") or source["output"]
        entries = groups.setdefault(module["source"] if individual else output, {})
        for file in sorted((ROOT / module["directory"]).rglob("*")):
            if file.is_file():
                name = file.relative_to(ROOT / module["directory"]).as_posix()
                add_member(entries, name, (name.encode("utf-8"), 0 if name.isascii() else 0x800),
                           file.read_bytes(), module["directory"])
    if unused and not individual:
        raise ValueError(f"Replacement source members missing: {sorted(unused)}")
    return groups, omissions


def add_member(entries, name, encoding, data, origin, extra=b""):
    validate_path(name)
    key = member_key(name)
    if key in entries:
        raise ValueError(f"Duplicate output path: {name} from {origin} and {entries[key][3]}")
    entries[key] = (name, encoding, data, origin, extra)


def verify_archive(path, entries):
    with ZipFile(path) as z:
        bad = z.testzip()
        if bad:
            raise ValueError(f"Bad CRC: {path.name}:{bad}")
        actual = {member_key(e.filename): e for e in z.infolist()}
        if len(z.infolist()) != len(entries) or actual.keys() != entries.keys():
            raise ValueError(f"Unexpected member list in {path.name}")
        for key, (name, encoding, data, origin, extra) in entries.items():
            entry = actual[key]
            if (entry.filename != name or raw_name(entry) != encoding
                    or name_extra(entry) != extra or z.read(entry) != data):
                raise ValueError(f"Output differs: {path.name}:{name} from {origin}")


def publish(target, groups, report):
    target.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(prefix="build-", dir=target.parent) as temp:
        staging = Path(temp)
        for name, entries in groups.items():
            with ZipFile(staging / name, "w", ZIP_DEFLATED) as z:
                for key in sorted(entries):
                    path, encoding, data, _, extra = entries[key]
                    z.writestr(ArchiveMember(path, encoding, extra), data, compress_type=ZIP_DEFLATED)
            verify_archive(staging / name, entries)
        for name in groups:
            (staging / name).replace(target / name)
    report["generated"] = {name: file_sha(target / name) for name in groups}
    save_json(target / "deployment.json", report)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("audit", "build", "verify"))
    parser.add_argument("--profile", choices=("repack", "modular"), default="repack")
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument("--group", help="Output ZIP filename")
    selection.add_argument("--individual", help="Original bundled ZIP filename")
    parser.add_argument("--omit-module", action="append", default=[],
                        help="Omit a local module when building an isolated modular configuration")
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    disabled = set(args.omit_module)
    optional = {m["directory"] for m in manifest["modules"] if m["directory"].startswith("integration/")}
    if disabled and (args.profile != "modular" or disabled - optional):
        parser.error("--omit-module requires a modular profile and an integration module directory")
    archive = ROOT.parent / manifest["snapshot"] / "packages"
    target = ROOT / "dist" / args.profile
    with ExitStack() as stack:
        sources = inventory(manifest, archive, stack)
        for name, (source, _) in sources.items():
            validate_virtual_layout(source, source["output"] or name)
        exclusions, collisions = exclusion_plan(manifest, sources)
        module_files = module_collisions(manifest, sources)
        if args.command == "audit":
            for name, (_, z) in sources.items():
                if bad := z.testzip():
                    raise ValueError(f"Bad CRC: {name}:{bad}")
            print(f"Audit passed: {len(sources)} source ZIPs, {len(collisions)} conflict policies, "
                  f"{module_files} module files without path collisions")
            return
        if args.individual and (args.individual not in sources or not sources[args.individual][0]["output"]):
            parser.error("--individual requires an original bundled ZIP filename")
        groups, omissions = collect(manifest, sources, exclusions, args.profile, args.individual, disabled)
        if args.group:
            if args.group not in groups:
                parser.error(f"Unknown group: {args.group}")
            groups = {args.group: groups[args.group]}
        if args.group or args.individual or disabled:
            label = args.group or ("individual" if args.individual else "all")
            if disabled:
                label += "-without-" + "-".join(Path(name).name for name in sorted(disabled))
            target = target / "isolated" / label
        if args.command == "verify":
            for name, entries in groups.items():
                verify_archive(target / name, entries)
        else:
            report = {
                "profile": args.profile,
                "omitted_modules": sorted(disabled),
                "standalone": {s["name"]: s["sha256"] for s in manifest["sources"] if not s["output"]},
                "conflicts": collisions,
                "replaced": omissions,
                "members": {name: {v[0]: {"sha256": sha(v[2]), "source": v[3],
                                         "name_bytes": v[1][0].hex(), "utf8": bool(v[1][1])}
                                   for v in entries.values()} for name, entries in groups.items()},
            }
            publish(target, groups, report)
        print(f"{args.command} passed: {len(groups)} outputs, {sum(map(len, groups.values()))} members")


if __name__ == "__main__":
    main()
