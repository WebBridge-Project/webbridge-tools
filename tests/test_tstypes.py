#!/usr/bin/env python3
"""
Burn test for tstypes (C++ → TypeScript type mapping)

Usage:
    python -m pytest test_tstypes.py -v
"""

import pytest
from webbridge_tools.tools.tstypes import cpp_to_ts_type

@pytest.mark.parametrize("cpp,ts", [
    ("int", "number"),
    ("double", "number"),
    ("bool", "boolean"),
    ("std::string", "string"),
    ("std::vector<int>", "number[]"),
    ("std::vector<std::string>", "string[]"),
    ("std::array<double, 5>", "number[]"),
    ("std::map<std::string, int>", "Record<string, number>"),
    ("std::unordered_map<std::string, bool>", "Record<string, boolean>"),
    ("std::vector<std::vector<int>>", "number[][]"),
    ("std::map<std::string, std::vector<double>>", "Record<string, number[]>"),
    ("std::map<int, int>", "unknown"),
    ("std::pair<int, int>", "unknown"),
    ("const std::vector<int>&", "number[]"),
    ("unsigned long long", "number"),
    ("nullptr_t", "null"),
])

def test_cpp_to_ts_type_burn(cpp, ts):
    assert cpp_to_ts_type(cpp) == ts
