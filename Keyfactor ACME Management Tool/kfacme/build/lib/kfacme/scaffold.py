from __future__ import annotations

from pathlib import Path
import importlib.resources as ir

TEMPLATE_NAME = "variables.py.tpl"

def init_project(base_path: str | Path = ".", force: bool = False) -> Path:
    """
    Creates a local ./kfacme directory and writes variables.py from template.
    Returns the created directory path.
    """
    base = Path(base_path).resolve()
    target_dir = base / "kfacme"
    target_dir.mkdir(parents=True, exist_ok=True)

    target_file = target_dir / "variables.py"

    if target_file.exists() and not force:
        raise FileExistsError(
            f"{target_file} already exists. Use --force to overwrite."
        )

    # Load template shipped inside the package
    template_pkg = "kfacme.templates"
    template_text = ir.files(template_pkg).joinpath(TEMPLATE_NAME).read_text(encoding="utf-8")

    target_file.write_text(template_text, encoding="utf-8")
    return target_dir