#!/usr/bin/env python3
"""Regression test for noninteractive AKT password prompt handling."""

from __future__ import annotations

import pathlib
import subprocess
import sys


repo_root = pathlib.Path(__file__).resolve().parents[1]
helper = repo_root / "scripts/lib/akt_password_helper.py"
child = r"""
import sys

def prompt(text):
    sys.stderr.write(text)
    sys.stderr.flush()
    return sys.stdin.readline().rstrip("\n")

export_password = prompt("Enter passphrase to encrypt the key: ")
keyring_password = prompt("Enter keyring passphrase (attempt 1/3):")
confirmed_password = prompt("Re-enter keyring passphrase:")
if export_password != "export-secret":
    raise SystemExit(10)
if keyring_password != "keyring-secret" or confirmed_password != keyring_password:
    raise SystemExit(11)
print('{"address":"akash1test"}')
"""

result = subprocess.run(
    [sys.executable, str(helper), "--", sys.executable, "-c", child],
    input=b"keyring-secret\nexport-secret\n",
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    check=False,
)
assert result.returncode == 0, result.stderr.decode()
assert result.stdout == b'{"address":"akash1test"}\n'
assert b"passphrase" not in result.stderr
assert b"secret" not in result.stderr
