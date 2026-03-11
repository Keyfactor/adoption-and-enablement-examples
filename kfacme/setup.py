from setuptools import setup, find_packages
import pathlib

here = pathlib.Path(__file__).parent.resolve()
long_description = (here / "README.md").read_text(encoding="utf-8")

setup(
    name="kfacme",
    version="0.1.8",
    description="A Keyfactor ACME Management Tool",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/pypa/sampleproject",
    author="Howland, Jeremy",
    classifiers=[
        "Development Status :: 3 - Alpha",  #3 - Alpha, 4 - Beta, 5 - Production/Stable
        "Intended Audience :: Keyfactor Administrators\ACME Users",
        "Topic :: Security"
        "Topic :: Software Development :: Build Tools",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.7",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3 :: Only",
    ],
    keywords="keyfactor, setuptools, development, acme",
    package_dir={"": "src"},
    packages=find_packages(where="src"),
    python_requires=">=3.10, <4",
    install_requires=["jwt","jwt.algorithms","prettytable","requests","click"],
    extras_require={},
    package_data={},
    entry_points={  # Optional
        "console_scripts": [
            "kfacme=kfacme:main",
        ],
    },
    project_urls={  # Optional
        "Keyfactor Documentation": "https://software.keyfactor.com",
        "Source": "https://github.com/pypa/sampleproject/",
    },
)