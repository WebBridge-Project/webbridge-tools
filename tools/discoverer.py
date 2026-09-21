#!/usr/bin/env python3
"""
webbridge Auto-Discovery Scanner

Scans C++ header files and finds all classes that inherit from webbridge::object.
Called by CMake to automatically discover classes for registration.

Usage:
    webbridge-discoverer header1.h header2.h ...
    python -m webbridge_tools.tools.discoverer header1.h header2.h ...

Output:
    Per found class: filename|classname (one per line)
    CMake can use this via COMMAND_OUTPUT_VARIABLE

Inspired by Qt's MOC auto-discovery mechanism.
"""

import sys
from pathlib import Path
from typing import List
import tree_sitter_cpp as tscpp
from tree_sitter import Parser, Language


def find_webbridge_classes(header_file: str) -> List[str]:
    """
    Finds all classes in a header file that inherit from webbridge::object.

    Args:
        header_file: Path to the header file

    Returns:
        List of webbridge class names
    """
    try:
        path = Path(header_file)
        if not path.exists() or not path.suffix.lower() in ['.h', '.hpp']:
            return []

        with open(path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()

        if 'webbridge::Object' not in content and 'webbridge::object' not in content:
            return []

        try:
            parser = Parser(Language(tscpp.language()))
            tree = parser.parse(content.encode('utf-8'))

            class_names = []
            _find_class_names(tree.root_node, content, class_names)
            return class_names
        except Exception as e:
            print(f"# Parse error for {header_file}: {e}", file=sys.stderr)
            return []

    except Exception as e:
        print(f"# Error for {header_file}: {e}", file=sys.stderr)
        return []


def _find_class_names(node, content: str, class_names: List[str]):
    """
    Recursive search for class names that inherit from webbridge::object

    Args:
        node: AST node
        content: source code
        class_names: list to collect the class names into
    """
    if node.type == 'class_specifier':
        class_name = None
        inherits_webbridge = False

        for child in node.children:
            if child.type == 'type_identifier':
                class_name = content[child.start_byte:child.end_byte].strip()
            elif child.type == 'base_class_clause':
                base_text = content[child.start_byte:child.end_byte]

                if 'webbridge::Object' in base_text or 'webbridge::object' in base_text or 'Object' in base_text or 'object' in base_text:
                    inherits_webbridge = True

        if class_name and inherits_webbridge:
            class_names.append(class_name)

    for child in node.children:
        _find_class_names(child, content, class_names)


def main():
    """
    Main entry point for CMake integration.

    Prints found classes one per line in the format: filename|classname
    Exit code: 0 on success, 1 on failure
    """
    if len(sys.argv) < 2:
        print("# Usage: webbridge-discoverer <header1.h> [header2.h] ...",
              file=sys.stderr)
        sys.exit(1)

    results: List[str] = []

    for header_file in sys.argv[1:]:
        class_names = find_webbridge_classes(header_file)
        for class_name in class_names:
            results.append(f"{header_file}|{class_name}")

    if results:
        for result in results:
            print(result)
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
