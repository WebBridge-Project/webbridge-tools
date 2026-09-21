"""CLI for locating the parts of webbridge-tools a build system needs.

Usage:
    python -m webbridge_tools --cmake-dir
"""

import argparse

from . import get_cmake_dir


def main() -> None:
    parser = argparse.ArgumentParser(prog="webbridge_tools")
    parser.add_argument("--cmake-dir", action="store_true", help="Print the directory containing webbridge.cmake")
    args = parser.parse_args()

    if args.cmake_dir:
        print(get_cmake_dir())
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
