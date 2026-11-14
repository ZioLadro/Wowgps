#!/usr/bin/env python3
"""Runs the WowGPS tests on Lua 5.1 (the version WoW embeds).

    pip install lupa
    python3 tests/run.py
"""
import pathlib
import sys

from lupa import lua51

root = pathlib.Path(__file__).resolve().parent.parent
lua = lua51.LuaRuntime(unpack_returned_tuples=True)
chunk = lua.eval("function(path, root) return assert(loadfile(path))(root) end")
try:
    passed = chunk(str(root / "tests" / "test.lua"), str(root))
except Exception as exc:  # lupa raises LuaError with the Lua message
    print(exc)
    sys.exit(1)
print(f"OK: {passed} checks passed")
