# json2dir in LLVM IR

A handwritten implementation of `json2dir` in textual LLVM IR. The JSON
parser, UTF-8 handling, key sorting, memory management, and directory tree
creation live in [`src/json2dir.ll`](src/json2dir.ll). The build compiles
`.ll` files directly; the executable uses only the system libc/POSIX library.
No C, Rust, Python, or external JSON library is required to build or run it.

This implementation preserves the behavior of the neighboring Rust project
`../json2dir` at revision `b2072fb5515a603024c123297b27dcaabfdf098a`.
The original license is retained in [LICENSE](LICENSE).

## Building and running

You need Clang with opaque pointer support (LLVM 15+) and GNU Make.
The installed Apple Clang works on macOS.

```sh
make
```

JSON is read from stdin, and the tree is created in the **current working
directory**. Command-line arguments are not accepted. Success returns `0`,
and failure returns `1`; error messages go to stderr.

```sh
mkdir -p /tmp/json2dir-example
cd /tmp/json2dir-example
/Users/maxmur/Code/json2dir-llvm-IR/json2dir < /Users/maxmur/Code/json2dir-llvm-IR/example-tree.json
```

To install, run `make install PREFIX="$HOME/.local"`.
You can override the compiler and flags, for example:

```sh
make CLANG=/opt/homebrew/opt/llvm/bin/clang IRFLAGS='-O3 -Wno-override-module'
```

## Format

The JSON root must be an object. Its keys name directory entries:

| Value | Resulting entry |
| --- | --- |
| `"text"` | A regular file containing this text |
| `{ "file": "text" }` | A directory containing nested entries |
| `["link", "target"]` | A symbolic link pointing to `target` |
| `["script", "#!/bin/sh\necho hi"]` | A file with execute bits `0111` added |

All JSON escapes, UTF-16 surrogate pairs, and UTF-8 are supported. NUL bytes
in file contents are preserved; NUL bytes in entry names or link targets
are rejected. `null`, numbers, and booleans are parsed syntactically but
cannot represent tree entries. Arrays must contain exactly two strings,
with `link` or `script` as the first element.

## Compatibility

- The entire document is parsed and validated as UTF-8 before any filesystem
  changes. Invalid JSON, infinite numeric values, or inputs exceeding the
  nesting limit do not create any entries.
- The maximum is 127 nested objects/arrays, matching the original's default
  `serde_json` recursion limit.
- Objects are traversed in ascending key order. For duplicate keys, the last
  value wins, including keys written using Unicode escapes.
- A name must contain exactly one normal Unix path component. Empty names,
  `.`, `..`, absolute paths, and paths with multiple components are rejected.
- As in the original, component validation allows trailing `/` and `/.`,
  but system calls receive the original name. Writing a file named `foo/`
  therefore fails, and `foo/.` requires the `foo` directory to already exist.
- Existing files and symbolic links are removed before applying a value.
  Existing directories are reused, and unrelated entries inside them are
  preserved. A directory is not removed to replace it with a file or link.
- Normal permissions respect umask. For scripts, the actual permissions of
  the created file are read, and all three execute bits are added.
- A schema or filesystem error may leave previously applied entries in
  place. As in the original, there is no rollback or protection against
  races involving changes to symbolic links.
- Diagnostics retain their meaning; Rust `Debug` formatting for system
  errors is not reproduced byte for byte.

## Platforms

The main IR has no target triple. The Makefile selects a small IR module
that provides the `stat` ABI and access to errno:

| Platform | Module | Validation |
| --- | --- | --- |
| macOS arm64 | `src/platform-darwin.ll` | Build and functional tests |
| macOS x86_64 | `src/platform-darwin-x86_64.ll` | Build and tests through Rosetta |
| Linux AArch64, glibc | `src/platform-linux-aarch64.ll` | Tests in an isolated Linux container |
| Linux x86_64, glibc | `src/platform-linux-x86_64.ll` | IR verification and object file compilation |

Other ABIs and Windows are not supported. When cross-compiling, explicitly
select the appropriate `PLATFORM` and configure Clang and the linker for
the target system.

## Validation

Tests require Python 3.9+. Each test runs in a fresh temporary directory.

```sh
make test
make sanitize
make verify LLVM_AS=/opt/homebrew/opt/llvm/bin/llvm-as OPT=/opt/homebrew/opt/llvm/bin/opt
```

`sanitize` adds `sanitize_address` to temporary copies of the IR and runs
the tests with AddressSanitizer instrumentation. The source `.ll` files are
unchanged. `verify` requires `llvm-as` and `opt` and checks the main module
and the selected ABI module. For IR syntax, see the
[LLVM Language Reference](https://llvm.org/docs/LangRef.html).

To compare against an original binary you have built:

```sh
make differential REFERENCE=/absolute/path/to/original/json2dir
```

Validation covered 29 functional tests and 2460 combinations of input data
and directory state against the Rust original: exit codes and resulting
trees matched. The comparison includes Unicode, duplicate keys, invalid
values, random byte mutations of JSON, nesting limits, and existing files,
directories, and symbolic links.
