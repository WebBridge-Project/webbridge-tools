# End-to-end smoke test for this repository's own CMake integration
# (webbridge_add_library() + webbridge_generate()), run against whichever
# Python interpreter has this checkout's webbridge_tools installed (e.g. an
# editable install from tests/../ - see "Testing your changes locally" in
# the top-level README).
#
# Usage:
#   cmake -S tests/cpp_smoke -B tests/cpp_smoke/build
#   cmake --build tests/cpp_smoke/build --config Debug --target webbridge_smoke_test
#
# Success means: the parser understood src/MyObject.h, generate.py produced
# valid C++ from it, and it compiled and linked against the packaged
# webbridge library - i.e. the full pipeline still works after a change.
cmake_minimum_required(VERSION 3.26)
cmake_policy(SET CMP0091 NEW)
project(webbridge_tools_cpp_smoke LANGUAGES CXX)

set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")

find_package(Python REQUIRED COMPONENTS Interpreter)
execute_process(
    COMMAND ${Python_EXECUTABLE} -m webbridge_tools --cmake-dir
    OUTPUT_VARIABLE WEBBRIDGE_TOOLS_CMAKE_DIR
    OUTPUT_STRIP_TRAILING_WHITESPACE
    RESULT_VARIABLE _wb_cmake_dir_result)
if(NOT _wb_cmake_dir_result EQUAL 0)
    message(FATAL_ERROR
        "webbridge_tools is not importable with ${Python_EXECUTABLE} - "
        "install it first, e.g. 'pip install -e \"${CMAKE_CURRENT_SOURCE_DIR}/../..[test]\"'")
endif()
list(APPEND CMAKE_MODULE_PATH "${WEBBRIDGE_TOOLS_CMAKE_DIR}")
include(webbridge)

webbridge_add_library()

add_library(webbridge_smoke_test STATIC src/MyObject.h)
target_link_libraries(webbridge_smoke_test PUBLIC webbridge::webbridge)
set_target_properties(webbridge_smoke_test PROPERTIES LINKER_LANGUAGE CXX)

webbridge_generate(
    TARGET webbridge_smoke_test
    AUTO
    OUTPUT_DIR ${CMAKE_BINARY_DIR}/generated
)
