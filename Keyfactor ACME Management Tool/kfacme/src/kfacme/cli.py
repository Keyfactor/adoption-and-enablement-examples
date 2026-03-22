import argparse
import sys
from .scaffold import init_project
from .app import main_menu
from . import __version__
from .config import load_user_variables


def main(argv=None) -> int:
    argv = argv if argv is not None else sys.argv[1:]

    # Top-level parser for general arguments
    parser = argparse.ArgumentParser(prog="kfacme", description="KFACME CLI")
    parser.add_argument(
        "--version",
        action="version",
        version=f"%(prog)s {__version__}",
    )
    parser.add_argument(
        "--variables-file",
        default=None,
        help="Path to variables.py",
    )
    
    # Subparsers for commands
    sub = parser.add_subparsers(dest="command")

    # Subcommand: "init"
    p_init = sub.add_parser("init", help="Create ./kfacme and variables.py template")
    p_init.add_argument("--path", default=".", help="Base path to create kfacme directory in")
    p_init.add_argument("--force", action="store_true", help="Overwrite existing variables.py")

    # Handle arguments
    args, remaining_args = parser.parse_known_args(argv)

    # Handle specific subcommands
    if args.command == "init":
        init_project(base_path=args.path, force=args.force)
        return 0

    # Handle the default case when no subcommand is provided
    if args.command is None:
        main_menu.callback(str(args.variables_file))
        return 0

    # If nothing matches, print the help
    parser.print_help()
    return 1
