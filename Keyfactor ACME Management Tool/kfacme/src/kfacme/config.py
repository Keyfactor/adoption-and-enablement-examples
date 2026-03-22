from pathlib import Path
import importlib.util
from typing import Any, Dict


def load_user_variables(variables_file: str | Path | None = None, base_path: str | Path = ".") -> Dict[str, Any]:
    base = Path(base_path).resolve()
    var_file = Path(variables_file).resolve() if variables_file else base / "kfacme" / "variables.py"

    if not var_file.exists():
        raise FileNotFoundError(
            f"Missing config file: {var_file}\n"
            f"Run `kfacme init` first to generate it."
        )

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