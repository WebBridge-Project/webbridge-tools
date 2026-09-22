# webbridge-tools

[![Tests](https://github.com/WebBridge-Project/webbridge-tools/actions/workflows/tests.yml/badge.svg)](https://github.com/WebBridge-Project/webbridge-tools/actions/workflows/tests.yml)
[![CodeQL](https://github.com/WebBridge-Project/webbridge-tools/actions/workflows/codeql.yml/badge.svg)](https://github.com/WebBridge-Project/webbridge-tools/actions/workflows/codeql.yml)
[![Build](https://github.com/WebBridge-Project/webbridge-tools/actions/workflows/build.yml/badge.svg)](https://github.com/WebBridge-Project/webbridge-tools/actions/workflows/build.yml)
[![PyPI](https://img.shields.io/pypi/v/webbridge-tools.svg)](https://pypi.org/project/webbridge-tools/)

Python code generator for webbridge: turns C++ classes derived from `webbridge::object` into C++ registration code and TypeScript bindings. Use it together with the `webbridge-runtime` C++ library (from Conan) in your project — this package only generates code, it doesn't provide that library itself.

## Install

```bash
pip install webbridge-tools
```

Requires Python 3.9+, and CMake 3.26+ for the integration below.

## Wire it into your project

This assumes your `CMakeLists.txt` already sets up the `webbridge-runtime` C++ library itself (e.g. via Conan) - that part is unrelated to `webbridge-tools` and doesn't change. Add these lines *in addition* to that, after the target you want code generated for already exists:

```cmake
find_package(Python REQUIRED COMPONENTS Interpreter)
execute_process(
    COMMAND ${Python_EXECUTABLE} -m webbridge_tools --cmake-dir
    OUTPUT_VARIABLE WEBBRIDGE_TOOLS_CMAKE_DIR
    OUTPUT_STRIP_TRAILING_WHITESPACE)
list(APPEND CMAKE_MODULE_PATH "${WEBBRIDGE_TOOLS_CMAKE_DIR}")
include(webbridge)

webbridge_generate(
    TARGET your_target
    AUTO
    LANGUAGE cpp
)
```

Replace `your_target` with your own CMake target. `webbridge_generate()` must come after that target is created - `AUTO` scans its sources for classes inheriting `webbridge::object` and generates registration code for each.

## Testing

If you cloned the repository, you can test its functionality locally:

```bash
pip install -e ".[test]"
pytest tests/
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Third-party dependencies and their licenses are listed in [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt).
