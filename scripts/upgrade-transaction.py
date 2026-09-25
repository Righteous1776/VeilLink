#!/usr/bin/env python3
from pathlib import Path
import os, shutil, stat, tempfile

class FileTransaction:
    """Byte-for-byte rollback for local upgrade scripts.

    Call snapshot(path) before mutating an existing file and mark_created(path)
    for new files. rollback() restores original bytes/modes and removes files
    created by the transaction. No remote/network operation is performed.
    """
    def __init__(self, root: Path):
        self.root = root.resolve()
        self._backups = {}
        self._created = []
        self._committed = False

    def _resolve(self, path):
        p = Path(path)
        if not p.is_absolute():
            p = self.root / p
        return p

    def snapshot(self, path):
        p = self._resolve(path)
        if p in self._backups or p in self._created:
            return p
        if p.exists():
            if not p.is_file():
                raise RuntimeError(f'transaction only supports file snapshot: {p}')
            self._backups[p] = (p.read_bytes(), stat.S_IMODE(p.stat().st_mode))
        else:
            self._created.append(p)
        return p

    def mark_created(self, path):
        p = self._resolve(path)
        if p.exists():
            raise RuntimeError(f'expected new path but already exists: {p}')
        if p not in self._created:
            self._created.append(p)
        return p

    def write_bytes(self, path, data: bytes, mode=None):
        p = self.snapshot(path)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(data)
        if mode is not None:
            p.chmod(mode)
        return p

    def write_text(self, path, text: str, mode=None):
        return self.write_bytes(path, text.encode('utf-8'), mode=mode)

    def copy_file(self, source, destination, mode=None):
        src = self._resolve(source) if not Path(source).is_absolute() else Path(source)
        return self.write_bytes(destination, src.read_bytes(), mode=mode)

    def commit(self):
        self._committed = True

    def rollback(self):
        for p in reversed(self._created):
            try:
                if p.is_file() or p.is_symlink():
                    p.unlink()
            except FileNotFoundError:
                pass
        for p, (data, mode) in self._backups.items():
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(data)
            p.chmod(mode)

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        if exc_type is not None and not self._committed:
            self.rollback()
        return False
