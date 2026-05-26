"""Allow importlib to load the extensionless theme-sun-toggle script.

Python 3.14 no longer falls back to SourceFileLoader for files without a
recognized suffix, so spec_from_file_location() returns None. Registering an
empty source suffix restores loader detection for the extensionless script
that the test imports by path.
"""
import importlib.machinery

if "" not in importlib.machinery.SOURCE_SUFFIXES:
    importlib.machinery.SOURCE_SUFFIXES.append("")
    importlib.invalidate_caches()
