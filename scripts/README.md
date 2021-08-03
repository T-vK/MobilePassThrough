```
scripts                  # All bash scripts called directly or indirectly by `mbpt.sh`. (Some scripts may also be installed in the `thirdparty` directory or may straight up be system dependencies installed using your package manager.)
├── main                 # Scripts that can be called directly or by running `mbpt.sh`. They work on any Linux distribution, given that a corresponding `utils/distro-specific/{DISTRIBUTION}/{VERSION}` directory with its scripts exists.
└── utils                # Scripts that are used by other scripts in this project.
    ├── common           # Scripts that work on any Linux distribution, given that a corresponding `utils/distro-specific/{DISTRIBUTION}/{VERSION}` directory with its scripts exists.
    │   ├── libs         # Scripts that are not executable and have to be `source`d.
    │   ├── setup        # Scripts that have dependencies on other scripts (or programs in the `thirdparty` directory) in this project.
    │   └── tools        # Scripts that don't have dependencies on other files in this project and could be moved into their own project at some point.
    └── distro-specific  # Scripts that are distribution-specific. For every distribution/version the exact same set of scripts have to exist (same names, but different content of course).
        ├── Fedora       # All `Fedora`-specific scripts.
        │   ├── 34       # All `Fedora 34`-specific scripts.
        │   └── 35       # All `Fedora 35`-specific scripts.
        └── Ubuntu       # All `Ubuntu`-specific scripts.
            └── 21.04    # All `Ubuntu 21.04`-specific scripts.
```