"""webbridge-tools: the webbridge C++ library source plus its code generator.

Bundles the webbridge C++ library (``webbridge/``) and the code generator
(``generate``/``discoverer``/``parser``/``tstypes``) that turns C++ header
files declaring ``webbridge::object`` subclasses into C++ registration code
and TypeScript bindings, as a single pip/conda-installable distribution.
No checkout of the webbridge source repo is required at install or build time.
"""

from pathlib import Path

__version__ = "1.0.0"


def get_include_dir() -> str:
    """Directory to add to a C++ include path so ``#include "webbridge/object.h"`` resolves.

    This is the webbridge_tools package directory itself - the bundled
    ``webbridge/`` C++ source tree lives directly inside it.

    Returned with forward slashes (even on Windows): CMake re-embeds
    CMAKE_MODULE_PATH/list entries into generated scratch CMakeLists.txt
    files (e.g. during try_compile for compiler-ABI detection), where a
    backslash is parsed as an escape character - "...\\cmake" turns into an
    invalid escape sequence. Forward slashes are always safe there.
    """
    return Path(__file__).parent.as_posix()


def get_cmake_dir() -> str:
    """Directory containing webbridge.cmake, for CMAKE_MODULE_PATH / CMAKE_PREFIX_PATH.

    webbridge_tools.cmake is its own subpackage (mapped in from a top-level
    cmake/ directory outside src/webbridge_tools/, for repo layout parity
    with upstream), not a plain sibling directory of this file - resolving it
    via "cmake" as a sibling of __file__ silently breaks under editable
    installs, where each subpackage's package-dir mapping can point
    somewhere else entirely. Importing it and reading its own __path__ asks
    the import system for wherever it actually is, editable or not.

    See get_include_dir() for why this uses forward slashes.
    """
    from . import cmake as _cmake

    return Path(next(iter(_cmake.__path__))).as_posix()
