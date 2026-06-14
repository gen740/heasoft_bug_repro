# HEASoft Bug Reproduction Environment

A self-contained Docker setup that builds HEASoft 6.36 from source with STL
bounds-checking enabled (`-D_GLIBCXX_ASSERTIONS`) and debug symbols (`-g`), then
reproduces an XSPEC crash (SIGABRT) under GDB and captures a clean backtrace.

## Layout

```
heasoft_buf_repro/
├── Dockerfile
├── heasoft-6.36src.tar.gz   ← local source tarball (download separately, see below)
├── build_and_run.sh
└── scripts/
    ├── generate_spectra.xcm   # XSPEC fakeit script -> src1.pha / src2.pha
    ├── make_responses.py      # builds dummy{1,2}.rmf / .arf (OGIP responses)
    ├── reproduce_bug.xcm      # the data + model commands that trigger the crash
    └── run_gdb.sh             # container entrypoint: steps 1–3 below
```

> **Note:** `heasoft-6.36src.tar.gz` and its unpacked tree are **not** committed to
> the repository (see `.gitignore`). You must download the tarball before building —
> see step 0.

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
next to the `Dockerfile`. You do **not** need to unpack it yourself — the image
does that during the build.

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

## 2. Build the image (first build takes hours)

```bash
nix shell nixpkgs#docker -c bash build_and_run.sh build
```

> **About caching**
> Docker stores each `RUN` instruction as a layer. The slow `make` step is not
> re-run unless an instruction before it changes. Changing only files under
> `scripts/` rebuilds in seconds, because the `COPY scripts/` step is placed last.

---

## 3. Reproduce the bug

```bash
nix shell nixpkgs#docker -c bash build_and_run.sh run
```

What happens inside the container:

| Step | Action |
|------|--------|
| 1 | `make_responses.py` generates `dummy{1,2}.rmf` / `.arf` |
| 2 | XSPEC `fakeit` generates `src1.pha` / `src2.pha` |
| 3 | GDB launches `xspec`, runs `data 1:1 src1.pha` + `data 2:2 src2.pha` + `model powerlaw`, stops on SIGABRT, and prints the backtrace |

The backtrace is also saved to `/work/bt_clean.txt` inside the container.

---

## 4. Interactive investigation

```bash
nix shell nixpkgs#docker -c bash build_and_run.sh shell
```

Inside the container:

```bash
# Initialize the environment (same as run_gdb.sh)
export HEADAS=/opt/heasoft
. $HEADAS/headas-init.sh

cd /work

# Reproduce the bug by hand
python3 /scripts/make_responses.py
xspec < /scripts/generate_spectra.xcm
gdb --args xspec   # then at the prompt: run < /scripts/reproduce_bug.xcm

# Inspect the build environment
cat /opt/heasoft/build-info.txt

# Confirm _GLIBCXX_ASSERTIONS was actually applied
zgrep 'GLIBCXX_ASSERT' /home/heasoft/build.log.gz | head -5
```

---

## 5. Rebuild after changing only the scripts

```bash
# build (re-runs just the COPY scripts/ layer, seconds)
nix shell nixpkgs#docker -c bash build_and_run.sh build

# then run
nix shell nixpkgs#docker -c bash build_and_run.sh run
```

---

## `build_and_run.sh` subcommands

| Command | Description |
|---------|-------------|
| `build`     | Build the image |
| `run`       | Reproduce the bug (emit GDB backtrace) |
| `shell`     | Start a bash shell inside the container |
| `build-run` | Build, then immediately run |
