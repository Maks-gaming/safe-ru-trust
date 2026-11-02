#!/usr/bin/env python3
"""Builds an iOS/macOS profile: the constrained root as a root, the cross certificate as an intermediate."""
import plistlib, ssl, sys, uuid

version, root, cross, out = sys.argv[1:]
NS = uuid.uuid5(uuid.NAMESPACE_DNS, "safe-ru-trust.maks-gaming.github.io")

def payload(kind, ptype, path):
    return {
        "PayloadType": ptype, "PayloadVersion": 1,
        "PayloadIdentifier": f"io.github.maks-gaming.safe-ru-trust.{kind}",
        "PayloadUUID": str(uuid.uuid5(NS, kind + version)).upper(),
        "PayloadDisplayName": f"Safe RU Trust {kind}",
        "PayloadContent": ssl.PEM_cert_to_DER_cert(open(path).read()),
    }

with open(out, "wb") as f:
    plistlib.dump({
        "PayloadType": "Configuration", "PayloadVersion": 1,
        "PayloadIdentifier": "io.github.maks-gaming.safe-ru-trust",  # same id: a new version replaces the old one
        "PayloadUUID": str(uuid.uuid5(NS, "profile" + version)).upper(),
        "PayloadDisplayName": f"Safe RU Trust {version}",
        "PayloadDescription": "Trusts Mintsifry certificates only for the sites listed in the project.",
        "PayloadContent": [payload("root", "com.apple.security.root", root), payload("cross", "com.apple.security.pkcs1", cross)],
    }, f)
