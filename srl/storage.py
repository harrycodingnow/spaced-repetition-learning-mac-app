from pathlib import Path
from contextlib import contextmanager
import json
import os
import tempfile

try:
    import fcntl
except ImportError:  # pragma: no cover - advisory locks are Unix-only
    fcntl = None

DATA_DIR = Path.home() / ".srl"
PROGRESS_FILE = DATA_DIR / "problems_in_progress.json"
MASTERED_FILE = DATA_DIR / "problems_mastered.json"
NEXT_UP_FILE = DATA_DIR / "next_up.json"
AUDIT_FILE = DATA_DIR / "audit.json"
CONFIG_FILE = DATA_DIR / "config.json"
BACKUP_DIR = DATA_DIR / "backups"


def ensure_data_dir():
    DATA_DIR.mkdir(parents=True, exist_ok=True)


def load_json(file_path: Path) -> dict:
    if not file_path.exists():
        return {}
    with open(file_path, "r") as f:
        return json.load(f)


def save_json(file_path: Path, data: dict):
    file_path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_path = tempfile.mkstemp(
        dir=file_path.parent,
        prefix=f".{file_path.name}.",
        suffix=".tmp",
        text=True,
    )
    try:
        with os.fdopen(descriptor, "w") as f:
            json.dump(data, f, indent=2)
        os.replace(temporary_path, file_path)
    finally:
        if os.path.exists(temporary_path):
            os.unlink(temporary_path)


@contextmanager
def data_lock(exclusive: bool = True):
    """Coordinate full CLI transactions with native app reads and writes."""
    ensure_data_dir()
    if fcntl is None:
        yield
        return

    lock_path = DATA_DIR / ".lock"
    with open(lock_path, "a+") as lock_file:
        operation = fcntl.LOCK_EX if exclusive else fcntl.LOCK_SH
        fcntl.flock(lock_file.fileno(), operation)
        try:
            yield
        finally:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)
