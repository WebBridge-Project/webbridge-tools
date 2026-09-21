#!/usr/bin/env python3
"""
webbridge Registration Generator

Generates _registration.h files from explicitly specified C++ classes.
Uses tree-sitter for fast C++ AST parsing and Jinja2 for template rendering.

Usage:
    # Single file:
    webbridge-generate <input.h> --class-name <ClassName> --cpp_out=<dir> --ts_impl_out=<dir>

    # Batch processing of multiple files:
    webbridge-generate --batch file1.h|Class1 file2.h|Class2 --cpp_out=<dir> --ts_impl_out=<dir>

    # Equivalent without the console script (e.g. from CMake):
    python -m webbridge_tools.tools.generate <input.h> --class-name <ClassName> --cpp_out=<dir>

Example:
    webbridge-generate ../src/MyObject.h --class-name MyObject --cpp_out=../build/src
    webbridge-generate ../src/MyObject.h --class-name MyObject --ts_impl_out=../frontend/src
    webbridge-generate ../src/MyObject.h --class-name MyObject --cpp_out=../build/src --ts_impl_out=../frontend/src
    webbridge-generate --batch ../src/Obj1.h|Obj1 ../src/Obj2.h|Obj2 --cpp_out=../build/src

Requirements:
    pip install webbridge-tools

Until C++26 reflection is available, this tool serves as a stopgap.
"""

import sys
from pathlib import Path
from jinja2 import Environment, FileSystemLoader
from .tstypes import cpp_to_ts_type
from .parser import ClassInfo, parse_header


# =============================================================================
# Jinja2 filters (helper functions)
# =============================================================================

def json_names(collection):
    """Formats a collection of objects as a JSON array of their names.

    Args:
        collection: List of objects with a 'name' attribute

    Returns:
        String like: {"method1", "method2", "method3"}
    """
    if not collection:
        return '{}'
    names = [getattr(obj, 'name') for obj in collection]
    json_strings = [f'"{name}"' for name in names]
    return '{' + ', '.join(json_strings) + '}'


# =============================================================================
# Global Jinja2 environment (initialized once)
# =============================================================================

def _setup_jinja_env() -> Environment:
    """Initializes the global Jinja2 environment with all filters."""
    template_dir = Path(__file__).parent / "templates"
    if not template_dir.exists():
        raise FileNotFoundError(f"Template directory not found: {template_dir}")

    env = Environment(
        loader=FileSystemLoader(str(template_dir)),
        autoescape=False,
        trim_blocks=True,
        lstrip_blocks=True,
        keep_trailing_newline=True,
    )

    env.filters['ts_type'] = cpp_to_ts_type
    env.filters['json_names'] = json_names
    env.filters['qualified_type'] = lambda cls, type_name: cls.qualify_type(type_name)

    return env


_JINJA_ENV = _setup_jinja_env()


# =============================================================================
# Code generators (functions)
# =============================================================================

def generate_registration_header(cls: ClassInfo, header_path: str) -> str:
    """Generates the C++ _registration.h header file."""
    try:
        template = _JINJA_ENV.get_template("registration_header.h.j2")
    except Exception as e:
        raise FileNotFoundError(f"Could not load template 'registration_header.h.j2': {e}") from e

    return template.render(
        cls=cls,
        header_path=Path(header_path).name,
    )


def generate_registration_impl(cls: ClassInfo, header_path: str) -> str:
    """Generates the C++ _registration.cpp implementation file."""
    try:
        template = _JINJA_ENV.get_template("registration_impl.cpp.j2")
    except Exception as e:
        raise FileNotFoundError(f"Could not load template 'registration_impl.cpp.j2': {e}") from e

    return template.render(
        cls=cls,
        header_path=Path(header_path).name,
    )


def generate_typescript_impl(cls: ClassInfo, header_path: str) -> str:
    """Generates the TypeScript .ts implementation."""
    try:
        template = _JINJA_ENV.get_template("impl.ts.j2")
    except Exception as e:
        raise FileNotFoundError(f"Could not load template 'impl.ts.j2': {e}") from e

    return template.render(
        cls=cls,
        header_path=Path(header_path).name,
    )


# =============================================================================
# Main
# =============================================================================

def main():
    """
    Main function for registration generation.

    Supports two modes:
    1. Single file: webbridge-generate <file.h> --class-name <Name>
    2. Batch: webbridge-generate --batch file1.h|Class1 file2.h|Class2 ...

    Args:
        input_path: Input header file (.h) [single mode]
        batch: List of "file.h|ClassName" pairs [batch mode]
        class_name: Name of the class to process [single mode]
        cpp_out: Output folder for C++ registration (optional)
        ts_impl_out: Output folder for TypeScript implementation (optional)
        verbose: Detailed output

    Exit Codes:
        0: Success
        1: Error during execution
    """
    import argparse

    parser = argparse.ArgumentParser(
        description="Generates webbridge registration and/or TypeScript types",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument('input_path', nargs='?', help='Input header file (.h) [single mode]')
    parser.add_argument('--class-name', help='Name of the class to process [single mode]')
    parser.add_argument('--batch', nargs='+', metavar='FILE|CLASS',
                        help='Batch mode: list of "file.h|ClassName" pairs')
    parser.add_argument('--cpp_out', type=str, help='Output folder for C++ registration header')
    parser.add_argument('--ts_impl_out', type=str, help='Output folder for TypeScript implementation')
    parser.add_argument('--verbose', '-v', action='store_true', help='Show detailed output')

    args = parser.parse_args()

    if args.batch:
        if args.input_path or args.class_name:
            print("Error: input_path and --class-name must not be used in batch mode", file=sys.stderr)
            sys.exit(1)

        file_class_pairs = []
        for pair in args.batch:
            if '|' not in pair:
                print(f"Error: invalid format '{pair}'. Expected: 'file.h|ClassName'", file=sys.stderr)
                sys.exit(1)
            file_path, class_name = pair.split('|', 1)
            if not Path(file_path).exists():
                print(f"Error: file not found: {file_path}", file=sys.stderr)
                sys.exit(1)
            file_class_pairs.append((file_path, class_name))
    else:
        if not args.input_path or not args.class_name:
            print("Error: input_path and --class-name are required in single mode", file=sys.stderr)
            print("       Or use --batch for multiple files", file=sys.stderr)
            sys.exit(1)
        if not Path(args.input_path).exists():
            print(f"Error: file not found: {args.input_path}", file=sys.stderr)
            sys.exit(1)
        file_class_pairs = [(args.input_path, args.class_name)]

    if not args.cpp_out and not args.ts_impl_out:
        print("Error: at least --cpp_out or --ts_impl_out must be specified", file=sys.stderr)
        sys.exit(1)

    success_count = 0
    error_count = 0

    for input_path, class_name in file_class_pairs:
        if args.verbose:
            print(f"Parsing: {input_path} -> {class_name}")

        try:
            cls = parse_header(input_path, class_name)
        except Exception as e:
            print(f"  [ERROR] Error while parsing: {e}", file=sys.stderr)
            if args.verbose:
                import traceback
                traceback.print_exc()
            error_count += 1
            continue

        if not cls:
            print(f"  [ERROR] Class '{class_name}' not found in {input_path}", file=sys.stderr)
            error_count += 1
            continue

        if args.verbose:
            print(f"  [OK] Class found: {cls.name}")
            print(f"    - Properties: {len(cls.properties)} {[p.name for p in cls.properties]}")
            print(f"    - Events: {len(cls.events)} {[e.name for e in cls.events]}")
            print(f"    - Sync Methods: {len(cls.sync_methods)} {[m.name for m in cls.sync_methods]}")
            print(f"    - Async Methods: {len(cls.async_methods)} {[m.name for m in cls.async_methods]}")

        try:
            if args.cpp_out:
                cpp_out_path = Path(args.cpp_out)
                cpp_out_path.mkdir(parents=True, exist_ok=True)

                reg_header_output = cpp_out_path / f"{cls.name}_registration.h"
                reg_header_code = generate_registration_header(cls, input_path)
                with open(reg_header_output, 'w', encoding='utf-8') as f:
                    f.write(reg_header_code)
                if args.verbose:
                    print(f"    [OK] Generated: {reg_header_output}")

                reg_impl_output = cpp_out_path / f"{cls.name}_registration.cpp"
                reg_impl_code = generate_registration_impl(cls, input_path)
                with open(reg_impl_output, 'w', encoding='utf-8') as f:
                    f.write(reg_impl_code)
                if args.verbose:
                    print(f"    [OK] Generated: {reg_impl_output}")

            if args.ts_impl_out:
                ts_impl_out_path = Path(args.ts_impl_out)
                ts_impl_out_path.mkdir(parents=True, exist_ok=True)
                ts_impl_output = ts_impl_out_path / f"{cls.name}.ts"
                ts_impl_code = generate_typescript_impl(cls, input_path)
                with open(ts_impl_output, 'w', encoding='utf-8') as f:
                    f.write(ts_impl_code)
                if args.verbose:
                    print(f"    [OK] Generated: {ts_impl_output}")

            success_count += 1

        except Exception as e:
            print(f"    [ERROR] Error for {cls.name}: {e}", file=sys.stderr)
            if args.verbose:
                import traceback
                traceback.print_exc()
            error_count += 1

    if not args.verbose and len(file_class_pairs) > 1:
        print(f"Processed: {success_count} succeeded, {error_count} failed")

    if error_count > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
