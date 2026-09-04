#!/usr/bin/env python3
"""Run AKT while answering only its known password prompts.

Secrets are read as two newline-delimited values from stdin and are never placed in
the child process arguments or environment. AKT receives each value only
after emitting the corresponding prompt, which avoids its independent stdin
readers consuming passwords intended for a later prompt.
"""

from __future__ import annotations

import os
import pty
import re
import selectors
import subprocess
import sys
import termios
import time


PROMPTS = (
    (re.compile(rb"Enter keyring passphrase(?: \(attempt \d+/\d+\))?:[ \t]*"), 0),
    (re.compile(rb"Re-enter keyring passphrase:[ \t]*"), 0),
    (re.compile(rb"Enter passphrase to encrypt the key:[ \t]*"), 1),
)
MAX_IDLE_SECONDS = 60


def fail(message: str) -> int:
    print(f"AKT password helper: {message}", file=sys.stderr)
    return 2


def main() -> int:
    if len(sys.argv) < 3 or sys.argv[1] != "--":
        return fail("usage: akt_password_helper.py -- <akt command> [args...]")

    keyring_password = sys.stdin.buffer.readline().rstrip(b"\n")
    export_password = sys.stdin.buffer.readline().rstrip(b"\n")
    if not keyring_password or not export_password:
        return fail("expected a keyring password and export password on stdin")
    secrets = (keyring_password, export_password)

    def emit_terminal(data: bytes) -> None:
        for secret in secrets:
            data = data.replace(secret, b"")
        if data:
            sys.stderr.buffer.write(data)
            sys.stderr.buffer.flush()

    master_fd, slave_fd = pty.openpty()
    terminal_attributes = termios.tcgetattr(slave_fd)
    terminal_attributes[1] &= ~termios.ONLCR
    terminal_attributes[3] &= ~(termios.ECHO | termios.ECHONL)
    termios.tcsetattr(slave_fd, termios.TCSANOW, terminal_attributes)
    child_env = os.environ.copy()
    child_env["TERM"] = "dumb"
    child_env["NO_COLOR"] = "1"

    child = subprocess.Popen(
        sys.argv[2:],
        stdin=slave_fd,
        stdout=subprocess.PIPE,
        stderr=slave_fd,
        env=child_env,
        close_fds=True,
    )
    os.close(slave_fd)
    assert child.stdout is not None

    selector = selectors.DefaultSelector()
    selector.register(master_fd, selectors.EVENT_READ, "terminal")
    selector.register(child.stdout, selectors.EVENT_READ, "stdout")
    output_buffer = b""
    discard_prompt_whitespace = False
    last_activity = time.monotonic()

    while selector.get_map():
        events = selector.select(timeout=1)
        if not events:
            if child.poll() is not None:
                break
            if time.monotonic() - last_activity > MAX_IDLE_SECONDS:
                child.terminate()
                return fail("timed out waiting for AKT output")
            continue

        for key, _ in events:
            try:
                chunk = os.read(key.fileobj if isinstance(key.fileobj, int) else key.fileobj.fileno(), 4096)
            except OSError:
                chunk = b""
            if not chunk:
                selector.unregister(key.fileobj)
                continue
            last_activity = time.monotonic()
            if key.data == "stdout":
                sys.stdout.buffer.write(chunk)
                sys.stdout.buffer.flush()
                continue
            output_buffer += chunk
            if discard_prompt_whitespace:
                output_buffer = output_buffer.lstrip(b" \t\r\n")
                if not output_buffer:
                    continue
                discard_prompt_whitespace = False
            while True:
                match_info = None
                for pattern, secret_index in PROMPTS:
                    match = pattern.search(output_buffer)
                    if match and (match_info is None or match.start() < match_info[0].start()):
                        match_info = (match, secret_index)
                if match_info is None:
                    break

                match, secret_index = match_info
                if match.start():
                    emit_terminal(output_buffer[: match.start()])
                output_buffer = output_buffer[match.end() :].lstrip(b" \t\r\n")
                os.write(master_fd, secrets[secret_index] + b"\n")
                discard_prompt_whitespace = not output_buffer

            newline = output_buffer.rfind(b"\n")
            if newline >= 0:
                emit_terminal(output_buffer[: newline + 1])
                output_buffer = output_buffer[newline + 1 :]
            elif len(output_buffer) > 512:
                emit_terminal(output_buffer[:-256])
                output_buffer = output_buffer[-256:]

    return_code = child.wait()
    os.close(master_fd)
    if output_buffer:
        emit_terminal(output_buffer)
    return return_code


if __name__ == "__main__":
    raise SystemExit(main())
