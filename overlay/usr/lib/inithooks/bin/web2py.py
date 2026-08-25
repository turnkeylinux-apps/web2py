#!/usr/bin/python3
"""Set the Web2py administration password."""

import getopt
import os
import subprocess
import sys

from libinithooks.dialog_wrapper import Dialog


def usage(message=None):
    if message:
        print(f"Error: {message}", file=sys.stderr)
    print(f"Syntax: {sys.argv[0]} [--pass=PASSWORD]", file=sys.stderr)
    raise SystemExit(1)


def main():
    try:
        options, _arguments = getopt.gnu_getopt(
            sys.argv[1:], "h", ["help", "pass="]
        )
    except getopt.GetoptError as error:
        usage(error)

    password = ""
    for option, value in options:
        if option in ("-h", "--help"):
            usage()
        if option == "--pass":
            password = value

    if not password:
        dialog = Dialog("TurnKey Linux - First boot configuration")
        password = dialog.get_password(
            "Web2py password",
            "Enter a password for the Web2py administration console.",
        )

    root = "/var/www/web2py"
    password_file = f"{root}/parameters_443.py"
    os.chdir(root)
    subprocess.run(
        [
            "python3",
            "-c",
            "import sys; from gluon.main import save_password; "
            "save_password(sys.stdin.read(), 443)",
        ],
        input=password,
        text=True,
        check=True,
    )
    os.chown(password_file, 33, 33)
    os.chmod(password_file, 0o640)


if __name__ == "__main__":
    main()
