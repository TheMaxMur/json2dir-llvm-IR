CLANG ?= clang
IRFLAGS ?= -O2 -Wno-override-module
LDFLAGS ?=
PYTHON ?= python3
LLVM_AS ?= llvm-as
OPT ?= opt
PREFIX ?= /usr/local
DESTDIR ?=

SYSTEM := $(shell uname -s)
ARCH := $(shell uname -m)
ifeq ($(SYSTEM),Darwin)
  ifeq ($(ARCH),arm64)
    PLATFORM ?= src/platform-darwin.ll
  else ifeq ($(ARCH),x86_64)
    PLATFORM ?= src/platform-darwin-x86_64.ll
  endif
else ifeq ($(SYSTEM),Linux)
  ifeq ($(ARCH),x86_64)
    PLATFORM ?= src/platform-linux-x86_64.ll
  else ifeq ($(ARCH),aarch64)
    PLATFORM ?= src/platform-linux-aarch64.ll
  endif
endif
ifeq ($(PLATFORM),)
  $(error Unsupported host $(SYSTEM)/$(ARCH); set PLATFORM to an appropriate IR ABI adapter)
endif

.PHONY: all test verify sanitize differential install clean
all: json2dir

json2dir: src/json2dir.ll $(PLATFORM) Makefile
	$(CLANG) $(IRFLAGS) src/json2dir.ll $(PLATFORM) $(LDFLAGS) -o $@

test: json2dir
	$(PYTHON) tests/test_json2dir.py --binary ./json2dir

verify:
	mkdir -p .build/ir
	$(LLVM_AS) src/json2dir.ll -o .build/ir/json2dir.bc
	$(OPT) -passes=verify -disable-output .build/ir/json2dir.bc
	$(LLVM_AS) $(PLATFORM) -o .build/ir/platform.bc
	$(OPT) -passes=verify -disable-output .build/ir/platform.bc

sanitize:
	mkdir -p .build
	sed '/^define /s/) {/) sanitize_address {/' src/json2dir.ll > .build/json2dir-sanitize.ll
	sed '/^define /s/) {/) sanitize_address {/' $(PLATFORM) > .build/platform-sanitize.ll
	$(CLANG) -O1 -fsanitize=address -Wno-override-module .build/json2dir-sanitize.ll .build/platform-sanitize.ll -o .build/json2dir-sanitize
	$(PYTHON) tests/test_json2dir.py --binary .build/json2dir-sanitize

differential: json2dir
	@test -n "$(REFERENCE)" || (echo 'Set REFERENCE=/absolute/path/to/original/json2dir'; exit 1)
	$(PYTHON) tests/test_json2dir.py --binary ./json2dir --reference "$(REFERENCE)"

install: json2dir
	install -d "$(DESTDIR)$(PREFIX)/bin"
	install -m 755 json2dir "$(DESTDIR)$(PREFIX)/bin/json2dir"

clean:
	rm -f json2dir
	rm -rf .build
