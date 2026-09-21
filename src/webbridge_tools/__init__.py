
from pathlib import Path

__version__ = "1.0.0"


def get_cmake_dir() -> str:

    from . import cmake as _cmake

    return Path(next(iter(_cmake.__path__))).as_posix()
