# C++ to JavaScript Bridge [webbridge-tools]

C++ objects are seamlessly integrated into modern web applications as a modern **Qt alternative** for web-based UIs. While Qt uses QML/Qt Quick or Qt WebEngine for GUI development, WebBridge leverages standard web technologies.

**Motivation:** A key advantage over Qt is the significantly reduced boilerplate code. In Qt, a simple property requires extensive boilerplate with getter, setter, signal, and backing field:

```cpp
// Qt approach - verbose boilerplate
Q_PROPERTY(bool aBool READ aBool WRITE setABool NOTIFY aBoolChanged)
bool aBool() const {
    return _aBool;
}
void setABool(bool v) {
    if (v != _aBool) {
        _aBool = v;
        emit aBoolChanged();
    }
}
signals:
    void aBoolChanged();
private:
    bool _aBool;

// WebBridge approach - minimal and clean
property<bool> aBool;
```

The solution is based on **webview** (C++ wrapper for Microsoft WebView2/Chromium) and a **Python code generator** (`webbridge-generate`, installed as part of this package) that uses **tree-sitter** to analyze C++ classes and automatically generate C++ registration headers and TypeScript type definitions. The build process automatically invokes the code generator via CMake, making the workflow seamless. Code generation is required because C++26 reflection is not yet available.

## Repository layout

- `src/webbridge_tools/webbridge/` — the library itself (bundled C++ source; this is what your project links against and `#include`s)
- `cmake/webbridge.cmake` — the `webbridge_add_library()` and `webbridge_generate()` CMake functions (installs as the `webbridge_tools.cmake` subpackage)
- `tools/{generate.py, discoverer.py, parser.py, tstypes.py, templates/}` — the Python/tree-sitter code generator (installs as the `webbridge_tools.tools` subpackage)
- `tests/` — pytest suite for the code generator


## Getting started

No Conan or vcpkg needed. webbridge's own two C++ dependencies (`nlohmann_json`, `webview`) are fetched and built automatically by CMake via `FetchContent` when you call `webbridge_add_library()` (see below) — just like the upstream repo, pulling webbridge in only fetches *its own* dependencies, not any consuming project's extra ones.

### Prerequisites (in your own project)

- **Visual Studio 2022** with C++ Desktop Development (MSVC compiler)
- **CMake 3.26+**
- **Python 3.9+** with `webbridge-tools` installed (see below)
- **Node.js** (only if you're building a JS/TS frontend that consumes the generated `.ts` bindings)
- **Microsoft Edge WebView2 Runtime** (usually preinstalled on Windows 10/11)

### 1. Install `webbridge-tools` (in your own project's environment)

```bash
pip install webbridge-tools
# or, inside a conda environment:
conda activate myenv
pip install webbridge-tools
```

### 2. Wire it into your own `CMakeLists.txt`

Add this to your project's `CMakeLists.txt` to locate the installed package and pull in its CMake functions:

```cmake
find_package(Python REQUIRED COMPONENTS Interpreter)
execute_process(
    COMMAND ${Python_EXECUTABLE} -m webbridge_tools --cmake-dir
    OUTPUT_VARIABLE WEBBRIDGE_TOOLS_CMAKE_DIR
    OUTPUT_STRIP_TRAILING_WHITESPACE)
list(APPEND CMAKE_MODULE_PATH "${WEBBRIDGE_TOOLS_CMAKE_DIR}")
include(webbridge)

webbridge_add_library()
target_link_libraries(your_target PRIVATE webbridge::webbridge)

webbridge_generate(
    TARGET your_target
    AUTO
    LANGUAGE cpp
)
```

Replace `your_target` with the name of your own CMake target.

### 3. Write and register your class (in your own project)

1. Write a class that inherits from `webbridge::object` — see [Minimal Example](#minimal-example) below for what this looks like.

2. Register it where you create your webview window:
```cpp
webbridge::register_type<YourClass>(&your_webview);
```

### 4. Build and run your own project

```bash
cmake -B build -S .
```
Then choose a build variant:
```bash
cmake --build build --config Debug                      # Debug
cmake --build build --config Release                    # Release
cmake --build build --config Release --clean-first      # Clean rebuild
```
And executing with:
```bash
# Debug build (with DevTools):
build\Debug\your_target.exe
# Release build (without DevTools):
build\Release\your_target.exe
```


## Concepts

Every class to be exposed to the web must inherit from `webbridge::object`. The API is inspired by Qt and provides the following mechanisms for JavaScript integration:

* **Methods** – Public C++ methods are automatically available in JavaScript (similar to Qt's Q_INVOKABLE)
* **Properties** – Exposed as Svelte-compatible stores (read-only, inspired by Qt's Q_PROPERTY)
* **Events** – Trigger custom event listeners in JavaScript (equivalent to Qt signals)
* **Constants** - Readonly JS values

The automatically generated code is functionally inspired by Qt and Qt's MOC (Meta-Object Compiler), but the WebBridge classes require significantly less boilerplate code than their Qt equivalents.

### Methods

All public methods of a `webbridge::object` class are automatically published to JavaScript.

A function marked with the `[[async]]` attribute is executed in a separate worker thread. This prevents blocking the main thread on the C++ side. On the JavaScript side, both synchronous and asynchronous methods always return a `Promise` and never block the main thread.

### Properties

Properties are similar to primitive data types but require access via the parenthesis operator `()` in C++. In JavaScript, properties are exposed as Svelte-compatible, reactive stores. They are read-only in JavaScript; changes to the property value in C++ are automatically and immediately propagated to JavaScript.

### Events

Events are the WebBridge equivalent of the Qt signal/slot mechanism.

### Constants

WebBridge supports exposing constants as both **static** (class-wide) and **non-static** (instance-specific). Both variants are automatically exported to JavaScript and are available there as read-only values.

### Error Handling

WebBridge implements robust error handling, distinguishing between JavaScript client errors (4xxx) and C++ server errors (5xxx). Errors are serialized as JSON objects and, for asynchronous operations, are propagated as rejected Promises.

**Error format:**
```json
{
  "error": {
    "code": 4001,
    "message": "Invalid argument type",
    "details": { "param": "value", "expected": "string" },
    "stack": "at function (file.js:10:5)",
    "origin": "javascript"
  }
}
```

**Error codes:**
- `4000-4999`: JavaScript errors (e.g., 4001 = JSON_PARSE_ERROR during parameter deserialization)
- `5000-5999`: C++ errors (e.g., 5000 = RUNTIME_ERROR during runtime errors)

Inspired by JSON-RPC 2.0, GraphQL, and HTTP status codes. Promises are automatically rejected on error, enabling clean exception handling with async/await syntax.

## Minimal Example

The following example shows how to define a C++ class with methods, properties, and events for web integration with WebBridge.

```cpp
#include "webbridge/object.h"

class MyObject : public webbridge::object
{
public:
    property<bool> aBool{false};
    property<std::string> strProp;
    event<int, bool> aEvent;
    inline static constexpr auto PI = 3.141592654;
    const std::string version = "1.0";

public:
    [[async]] void foo(std::string_view val) {
        // long-running action
        strProp = val;
        aEvent.emit(42, false);
    }

    bool bar() const {
        // Parenthesis operator accesses value
        return !aBool();
    }
};
```

### Tracking JavaScript Properties

```js
const myObj = await MyObject.create();
// ...
myObj.aBool.subscribe(value => {
    console.log('aBool updated:', value);
});
```

### Calling a C++ Method from JavaScript

```js
const myObj = await MyObject.create();

// Example: call a synchronous method
// Blocks the main thread in C++, but JavaScript waits asynchronously
const result = await myObj.bar();
console.log('Result of bar():', result);

// Example: call an asynchronous method ([[async]] = worker thread in C++)
// Does not block the main thread in either C++ or JavaScript
myObj.foo('new value').then(() => {
    console.log('foo() completed');
});
```

### Handling Events in JavaScript

```js
const myObj = await MyObject.create();

// Register event listener (similar to Node.js EventEmitter)
myObj.aEvent.on((intValue, boolValue) => {
    console.log('Event received:', intValue, boolValue);
});

// Alternatively, one-time event
myObj.aEvent.once((intValue, boolValue) => {
    console.log('One-time event:', intValue, boolValue);
});
```

### Accessing Constants in JavaScript

```js
const myObj = await MyObject.create();
console.log(myObj.version); // Instance constant: "1.0"
console.log(MyObject.PI);   // Static constant: 3.141592654
```

## Registration

To make C++ classes available in JavaScript, they must be explicitly registered. The code generator creates the necessary binding files, which are then included in CMake. In your `main.cpp`, you must call the generated registration function:

```cpp
#include "MyObject_registration.h"

int main() {
    // ... create your webview::webview w ...

    // Register the class for JavaScript
    webbridge::register_type<MyObject>(&w);

    // ... run your webview ...
}
```

## Known Limitations

The current implementation has the following limitations:

- Overloaded constructors and methods are not supported.
- Enums are automatically detected and exported to TypeScript, but complex enum use cases may require additional handling.
- Currently Windows-only (relies on Microsoft WebView2).


## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

The contents of `src/webbridge_tools/webbridge/` and the code generator (`tools/`), along with the documentation above, were extracted/adapted from the [webbridge](https://github.com/fsbondtec/webbridge) repository (MIT licensed, F&S Bondtec Semiconductor GmbH). webbridge's own runtime dependencies (`nlohmann_json`, `webview`) are fetched via CMake `FetchContent` when needed, under their own licenses, rather than vendored in this repository.
