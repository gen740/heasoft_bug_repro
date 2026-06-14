# HEASoft Bug Reproduction Environment

A Docker setup that builds HEASoft 6.36 from source with STL bounds-checking
(`-D_GLIBCXX_ASSERTIONS`) and debug symbols (`-g`), then reproduces an XSPEC
crash (SIGABRT) under GDB and captures the backtrace.

The same Dockerfile can build a patched image: the patches in `patches/` are
applied to the source before configuring, so the crash no longer occurs. That
way you can compare the buggy and fixed builds side by side.

## Layout

```
heasoft_bug_repro/
├── Dockerfile
├── heasoft-6.36src.tar.gz   # local source tarball (download separately, see below)
├── build_and_run.sh
├── patches/
│   └── 0001-fix-model-deep-copy.patch   # bugfix applied in the patched image
└── scripts/
    ├── generate_spectra.xcm   # XSPEC fakeit script -> src1.pha / src2.pha
    ├── make_responses.py      # builds dummy{1,2}.rmf / .arf (OGIP responses)
    ├── reproduce_bug.xcm      # the data + model commands that trigger the crash
    └── run_gdb.sh             # container entrypoint: steps 1-3 below
```

> **Note:** `heasoft-6.36src.tar.gz` and its unpacked tree are not committed to the
> repository (see `.gitignore`). Download the tarball before building; see step 0.

---

## 0. Download the HEASoft 6.36 source

The build uses a local tarball instead of downloading inside the image. Fetch the
HEASoft 6.36 source distribution into the project root before building:

```bash
wget -O heasoft-6.36src.tar.gz \
  "https://heasarc.gsfc.nasa.gov/FTP/software/lheasoft/lheasoft6.36/heasoft-6.36src.tar.gz"
```

Or, from the HEASoft download page, select **Source Code (all)** for version 6.36
and save the resulting `heasoft-6.36src.tar.gz` into this directory:
<https://heasarc.gsfc.nasa.gov/lheasoft/download.html>

The file is ~4.5 GB. The `Dockerfile` `COPY`s it into the image, so it must sit
next to the `Dockerfile`. You don't need to unpack it yourself; the image does
that during the build.

---

## 1. Start dockerd (in a separate terminal)

```bash
nix shell nixpkgs#docker -c sudo dockerd \
  --data-root /tmp/docker-data \
  --exec-root /tmp/docker-exec \
  --pidfile   /tmp/docker.pid \
  --host      unix:///tmp/docker.sock
```

---

## 2. Reproduce the bug (first build takes hours)

```bash
nix shell nixpkgs#docker -c bash build_and_run.sh run
```

`run` rebuilds the image first and then runs the scenario. Docker layer caching
makes the rebuild a no-op when nothing changed, so the slow `make` step only
re-runs when an instruction before it changes. Editing only files under
`scripts/` rebuilds in seconds, since the `COPY scripts/` step comes last.
(Use `build` to build without running.)

What happens inside the container:

| Step | Action |
|------|--------|
| 1 | `make_responses.py` generates `dummy{1,2}.rmf` / `.arf` |
| 2 | XSPEC `fakeit` generates `src1.pha` / `src2.pha` |
| 3 | GDB launches `xspec`, runs `data 1:1 src1.pha` + `data 2:2 src2.pha` + `model powerlaw`, stops on SIGABRT, and prints the backtrace |

The backtrace is also saved to `/work/bt_clean.txt` inside the container.

---

## 3. Build and verify the patched (fixed) version

`patches/` holds the bugfix. The patched image is built from the same Dockerfile
with `--build-arg APPLY_PATCH=1`, which applies every `*.patch` to the source
before `configure`. The convenience subcommand wraps this:

```bash
# Build the patched image, then run the same scenario; it should NOT crash
nix shell nixpkgs#docker -c bash build_and_run.sh run-patched
```

The buggy and patched images share every cached layer up to the patch step, so
building the second variant only re-runs `configure` / `make` (still slow, but the
unpack and apt layers are reused). The current fix is
`patches/0001-fix-model-deep-copy.patch`, which corrects the deep copy of
`ComponentGroup` pointers in `Model::Model(const Model&)` so the out-of-bounds
access no longer fires.

To add another bugfix, drop a new `*.patch` (a `-p1` diff against the HEASoft
source root) into `patches/` and rebuild with `run-patched`. All patches in the
directory are applied in sorted order.

---

## `build_and_run.sh` subcommands

`run` and `run-patched` build the image first (a no-op when nothing changed).

| Command | Description |
|---------|-------------|
| `build`         | Build the buggy (unpatched) image without running |
| `build-patched` | Build the patched (fixed) image without running |
| `run`           | Build then reproduce the bug (emit GDB backtrace) |
| `run-patched`   | Build then run the same scenario against the patched build |
