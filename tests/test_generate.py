#!/usr/bin/env python3
"""
Tests for generate.py's template rendering.

Complements test_parser.py: that suite proves parser.py understands C++
correctly, this one proves the parsed metadata actually renders into
plausible-looking C++/TypeScript output. It does not compile anything - the
generated code depends on the real webbridge C++ library (webview,
nlohmann/json.hpp, webbridge/impl/*), which this repository doesn't ship;
verifying an actual compile requires a consumer project with that library
available (e.g. via Conan).
"""

import pytest
import tempfile
from pathlib import Path
from webbridge_tools.tools.generate import (
    generate_registration_header,
    generate_registration_impl,
    generate_typescript_impl,
)
from webbridge_tools.tools.parser import parse_header

HEADER = """
#pragma once
template<typename T> class property {};
template<typename... Args> class event {};
namespace webbridge { class object {}; }

class MyObject : public webbridge::object {
public:
    property<bool> aBool;
    property<std::string> strProp;
    event<int, bool> aEvent;

    [[async]] void foo(std::string_view val);
    bool bar() const;
};
"""


@pytest.fixture
def parsed():
    with tempfile.NamedTemporaryFile(mode="w", suffix=".h", delete=False, encoding="utf-8") as f:
        f.write(HEADER)
        path = Path(f.name)
    cls = parse_header(str(path), "MyObject")
    yield cls, str(path)
    path.unlink()


def test_registration_header_contains_expected_symbols(parsed):
    cls, header_path = parsed
    output = generate_registration_header(cls, header_path)
    assert "register_MyObject" in output
    assert "#include <webview/webview.h>" in output


def test_registration_impl_contains_expected_symbols(parsed):
    cls, header_path = parsed
    output = generate_registration_impl(cls, header_path)
    assert "MyObject" in output
    assert "aBool" in output
    assert "strProp" in output
    assert "aEvent" in output
    assert "bar" in output
    assert "foo" in output


def test_typescript_impl_contains_expected_symbols(parsed):
    cls, header_path = parsed
    output = generate_typescript_impl(cls, header_path)
    assert "MyObject" in output
    assert "aBool" in output
    assert "aEvent" in output
