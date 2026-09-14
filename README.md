# webbridge-tools

Code generation tools for the [webbridge](https://github.com/fsbondtec/webbridge) framework, packaged as an installable Python distribution instead of a script folder fetched/vendored from the main repo.

Generates C++ registration headers (`_registration.h`/`.cpp`) and TypeScript bindings (`.ts`) from C++ header files that declare classes inheriting from `webbridge::object`.

## Install

```bash
pip install webbridge-tools
# or, inside a conda environment:
conda activate myenv
pip install webbridge-tools
```

This installs the `webbridge_tools` Python package plus three console scripts: `webbridge-generate`, `webbridge-discoverer`, `webbridge-parser`.

## Usage

```bash
# Generate C++ registration
webbridge-generate src/MyObject.h --class-name MyObject --cpp_out=build/src

# Generate TypeScript bindings
webbridge-generate src/MyObject.h --class-name MyObject --ts_impl_out=frontend/src

# Discover webbridge::object classes in a set of headers
webbridge-discoverer src/*.h

# Inspect a single class in detail
webbridge-parser src/MyObject.h --class-name MyObject
```

Equivalently, everything is also invokable as `python -m webbridge_tools.<generate|discoverer|parser>` without relying on the console scripts being on `PATH` (this is what the CMake integration below uses).

## CMake integration

[`cmake/webbridge.cmake`](cmake/webbridge.cmake) ships as part of this package and provides the `webbridge_generate()` CMake function for any C++ project that wants to call the generator from CMake. It only ever shells out to the installed `webbridge-tools` package (via `python -m webbridge_tools.*`) - it has no dependency on a vendored `tools/` directory or any other repo. Point it at whichever Python interpreter has `webbridge-tools` installed:

```cmake
include(webbridge)  # cmake/webbridge.cmake on CMAKE_MODULE_PATH

# Optional: only needed if it isn't the interpreter found by find_package(Python)
set(WEBBRIDGE_TOOLS_PYTHON_EXECUTABLE /path/to/python)

webbridge_generate(
    TARGET your_target
    AUTO
)
```

Any project that wants to use it (including the `webbridge` C++ library itself) just needs to add this file to its `CMAKE_MODULE_PATH` and `include(webbridge)` - there's nothing to sync or copy back and forth.

## Repository layout

- `src/webbridge_tools/` - the installable package (`generate.py`, `discoverer.py`, `parser.py`, `tstypes.py`, `templates/`)
- `tests/` - pytest suite (`pytest`)
- `cmake/webbridge.cmake` - standalone CMake integration, usable by any consumer
- `webbridge-hackathon/` - a one-time source snapshot the code above was extracted from; not imported, referenced, or required by anything in this repo, and can be deleted now

## Development

```bash
pip install -e ".[test]"
pytest
```

## Provenance

`src/webbridge_tools/{generate,discoverer,parser,tstypes}.py` and `src/webbridge_tools/templates/` were extracted from the `tools/` directory of the [webbridge](https://github.com/fsbondtec/webbridge) repository (MIT licensed, F&S Bondtec Semiconductor GmbH), repackaged as a standalone, pip/conda-installable distribution. See [`LICENSE`](LICENSE).
