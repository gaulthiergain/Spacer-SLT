# Spacer-SLT

Spacer-SLT is a load-time memory deduplication framework for unikernels that improves memory efficiency and consolidation density by enabling deterministic sharing of code and data pages across unikernels.

Spacer-SLT builds on the original Spacer approach by shifting deduplication decisions from runtime to load time. This design avoids the overheads and limitations of runtime page-scanning mechanisms (e.g., KSM).

This repository contains the implementation, tooling, benchmarks, and experimental setup used to evaluate Spacer-SLT.

---

## 🧱 Project Structure

- `aligner/`: Toolchain for producing aligned unikernel binaries. These components enforce deterministic placement of code and data sections to maximize page sharing across unikernel instances.  
  - `aslr/` contains support for generating ASLR-enabled unikernels and the associated binary rewriter.  
  - `helpers/` provides scripts to minimize ELF binaries, extract shared libraries into `/dev/shm`, and generate description files used by Spacer-SLT.

- `apps/`: Applications used with Spacer-SLT. Each application is maintained in a separate repository and should be cloned using Git.

- `benchmark/`: Benchmarking scripts and experimental configurations. This directory contains the artifacts required to reproduce the experimental evaluation presented in the paper.

- `DKSM/`: Deamonless Kernel Samepage Merging (DKSM) components and related tooling. This directory presents an alternative kernel-level approach to load-time memory deduplication. It includes source code, benchmarks, and scripts (see the corresponding `README.md` for details).

- `firecracker/`: Forked Firecracker components used to support Spacer-SLT. This includes modifications related to load-time memory mapping, shared library pools, and integration with the Spacer-SLT loader mechanisms.

- `libs/`: Libraries used with Spacer-SLT. Each library is maintained in a separate repository and should be cloned using Git.

- `unikraft/`: The Unikraft codebase used for Spacer-SLT. This directory contains the script to dowload the specific Unikraft version used for the experimental evaluation.

- `unikraft_dynamic/`: Unikraft extended with support for dynamically linked components (user-space Linux only). This directory also contains multiple loaders used to launch dynamically linked unikernels and explores the interaction between dynamic loading and Spacer-SLT, including shared library handling experiments.

---

## 🛠️ Dependencies

Spacer-SLT depends on the following libraries:

- [`Lief`](https://pypi.org/project/lief/): Library to instrument executable formats
- [`pyelftools`](https://pypi.org/project/pyelftools/): Library for analyzing ELF files and DWARF debugging information

You can install them with your system package manager or by using `pip`.

## 🧪 Build and Run

Spacer-SLT is intended as a research prototype. The following steps outline how to set up and run a system using Spacer-SLT:

1. Prepare the `apps/` and `libs/` directories by cloning the corresponding repositories (see `apps.md` and `libs.md`).
2. Compile the unikernels using the `make` command.
3. Use the aligner tool to have aligned unikernels with the following command: `./runner.sh --align`  (use the prefix `--use_aslr` to enable aslr)
4. Run the helper tools to prepare Spacer-SLT: `./runner.sh --minifier --extractor --dump_sec` These tools can be executed independently and in different orders. If the extractor is used, ensure that `/dev/shm` is populated with the extracted libraries. Use `--use_aslr` to enable aslr.
5. Go to the `firecracker` folder to build the custom loader by using the following command: 

```sh
devtool build --debug && cp "build/cargo_target/x86_64-unknown-linux-musl/debug/firecracker" "firecracker" #replace `--debug` by `--release` for production binaries.
```
6. Generate a configuration file (`uk_config.json`) that will be used by firecracker. For instance, the configuration file for `helloworld`:

```json
{
    "boot-source": {
        "kernel_image_path": "/home/gain/unikraft/apps/helloworld/build/unikernel_kvmfc-x86_64",
        "boot_args": "virtio_mmio.device=4K@0xd0000000:5 --  "
    },
    "drives": [],
    "machine-config": {
        "vcpu_count": 1,
        "mem_size_mib": 16
    },
    "network-interfaces": []
}
```

7. Launch the unikernel: `firecracker --no-api --config-file uk_config.json`. The execution can be traced using tools such as `strace`.

---

## 🔬 Research Context

Spacer-SLT is part of a broader investigation into memory efficiency and consolidation in unikernel-based systems and was published into a paper presented at [SoCC'25](https://acmsocc.org/2025/)). If you use this code for academic work, or use Spacer-SLT, please cite the corresponding publication:

```bibtex
@inproceedings{gain2025socc,
    author = {Gain, Gaulthier and Knott, Beno\^{\i}t and Soldani, Cyril and Mathy, Laurent},
    title = {Memory Matters: Load-Time Deduplication for Unikernels},
    year = {2026},
    isbn = {9798400722769},
    publisher = {Association for Computing Machinery},
    address = {New York, NY, USA},
    url = {https://doi.org/10.1145/3772052.3772247},
    doi = {10.1145/3772052.3772247},
    booktitle = {Proceedings of the 2025 ACM Symposium on Cloud Computing},
    pages = {464–478},
    numpages = {15},
    keywords = {Unikernels, Virtualization, Memory Deduplication, Cloud Computing, FaaS, Alignment},
    location = {},
    series = {SoCC '25}
}
```

## 🤝 License and Contributions

This project is licensed under the BSD 3-Clause License. See the LICENSE file for details.

Contributions, feedback, and suggestions are welcome. Feel free to open an issue or submit a pull request.
