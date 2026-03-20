from __future__ import annotations
from pathlib import Path
import importlib.util
from typing import Any, Dict


def load_user_variables(base_path: str | Path = ".") -> Dict[str, Any]:
    """
    Loads the user's ./kfacme/variables.py from disk and calls load_variables().
    Expects load_variables() to return a dict.
    """
    base = Path(base_path).resolve()
    var_file = base / "kfacme" / "variables.py"

    if not var_file.exists():
        raise FileNotFoundError(
            f"Missing config file: {var_file}\n"
            f"Run `kfacme init` first to generate it."
        )

    # Load module from an explicit file path (no sys.path hacks)
    spec = importlib.util.spec_from_file_location("kfacme_user_variables", var_file)
    if spec is None or spec.loader is None:
        raise ImportError(f"Could not load module spec from {var_file}")

    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)  # type: ignore[attr-defined]

    if not hasattr(mod, "load_variables"):
        raise AttributeError(
            f"{var_file} must define a function `load_variables()` returning a dict."
        )

    cfg = mod.load_variables()

    if not isinstance(cfg, dict):
        raise TypeError(
            f"`load_variables()` in {var_file} must return dict, got {type(cfg).__name__}"
        )

    return cfg