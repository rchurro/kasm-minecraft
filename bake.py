#!/usr/bin/env python3
"""Pre-download a Minecraft release into Prism Launcher's data layout.

Fetches Prism's meta for net.minecraft and its LWJGL dependency, then the client
jar, Linux libraries and assets, so a new session can launch without the long
"Downloading game files" step. Game files are Mojang's: keep the image private.

usage: bake.py <prism data dir> <minecraft version|latest> <java path>
"""
import hashlib
import json
import os
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor

META = "https://meta.prismlauncher.org/v1"
MANIFEST = "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"
ASSETS = "https://resources.download.minecraft.net"


def get(url):
    with urllib.request.urlopen(url, timeout=120) as r:
        return r.read()


def get_json(url):
    return json.loads(get(url))


def fetch(url, path, sha1=None, size=None):
    if os.path.isfile(path) and (size is None or os.path.getsize(path) == size):
        return
    data = get(url)
    if sha1 and hashlib.sha1(data).hexdigest() != sha1:
        raise RuntimeError(f"sha1 mismatch for {url}")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path + ".part", "wb") as f:
        f.write(data)
    os.replace(path + ".part", path)


def maven_path(name):
    # Prism stores libraries by their Gradle specifier, not the URL path.
    parts = name.split(":")
    group, artifact, version = parts[:3]
    classifier = f"-{parts[3]}" if len(parts) > 3 else ""
    return f"{group.replace('.', '/')}/{artifact}/{version}/{artifact}-{version}{classifier}.jar"


def allowed_on_linux(lib):
    rules = lib.get("rules")
    if not rules:
        return True
    ok = False
    for rule in rules:
        os_name = rule.get("os", {}).get("name")
        if os_name in (None, "linux"):
            ok = rule["action"] == "allow"
    return ok


def main(data, version, java):
    if version == "latest":
        version = get_json(MANIFEST)["latest"]["release"]
    mc = get_json(f"{META}/net.minecraft/{version}.json")
    lwjgl_req = next(r for r in mc["requires"] if r["uid"] == "org.lwjgl3")
    lwjgl_ver = lwjgl_req.get("equals") or lwjgl_req["suggests"]
    lwjgl = get_json(f"{META}/org.lwjgl3/{lwjgl_ver}.json")

    jobs = []
    for lib in [mc["mainJar"], *mc["libraries"], *lwjgl["libraries"]]:
        art = lib.get("downloads", {}).get("artifact")
        if art and allowed_on_linux(lib):
            jobs.append((art["url"], f"{data}/libraries/{maven_path(lib['name'])}",
                         art["sha1"], art["size"]))

    idx = mc["assetIndex"]
    index_path = f"{data}/assets/indexes/{idx['id']}.json"
    fetch(idx["url"], index_path, idx["sha1"])
    with open(index_path) as f:
        objects = json.load(f)["objects"].values()
    for obj in objects:
        h = obj["hash"]
        jobs.append((f"{ASSETS}/{h[:2]}/{h}", f"{data}/assets/objects/{h[:2]}/{h}", h, obj["size"]))

    print(f"Minecraft {version} (LWJGL {lwjgl_ver}): {len(jobs)} files", flush=True)
    with ThreadPoolExecutor(32) as pool:
        for _ in pool.map(lambda j: fetch(*j), jobs):
            pass

    # Prism re-downloads any library it has no metacache entry for, even when the
    # file is present and correct. "eternal" entries with the md5 make it trust them.
    entries = []
    for _, path, _, _ in jobs:
        if not path.startswith(f"{data}/libraries/"):
            continue
        with open(path, "rb") as f:
            md5 = hashlib.md5(f.read()).hexdigest()
        entries.append({"base": "libraries", "path": path[len(f"{data}/libraries/"):],
                        "md5sum": md5, "etag": "", "eternal": True,
                        "last_changed_timestamp": int(os.path.getmtime(path) * 1000)})
    with open(f"{data}/metacache", "w") as f:
        json.dump({"version": "1", "entries": entries}, f, indent=1)

    inst = f"{data}/instances/{version}"
    os.makedirs(inst, exist_ok=True)
    with open(f"{inst}/mmc-pack.json", "w") as f:
        json.dump({"formatVersion": 1, "components": [
            {"uid": "org.lwjgl3", "version": lwjgl_ver, "dependencyOnly": True},
            {"uid": "net.minecraft", "version": version, "important": True},
        ]}, f, indent=1)
    with open(f"{inst}/instance.cfg", "w") as f:
        f.write("[General]\nConfigVersion=1.2\nInstanceType=OneSix\n"
                f"name=Minecraft {version}\niconKey=default\n"
                f"OverrideJavaLocation=true\nJavaPath={java}\n"
                "OverrideCommands=true\nWrapperCommand=/usr/local/bin/mc-gpu\n")
    print(f"Instance ready: {inst}")


if __name__ == "__main__":
    main(*sys.argv[1:4])
