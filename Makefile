# UndraByte Linux
#
# `make help` lists everything. The ISO build needs an Arch host and root;
# on anything else use the DOCKER=1 variants.

SHELL := /bin/bash
EDITION ?= full
DESKTOP ?= kde
OUT     ?= out
VERSION := $(shell cat VERSION)

BUILD_FLAGS := --edition $(EDITION) --desktop $(DESKTOP) --out $(OUT)
ifeq ($(VM_ONLY),1)
BUILD_FLAGS += --vm-only
endif
ifeq ($(BLACKARCH),1)
BUILD_FLAGS += --with-blackarch
endif
ifeq ($(NVIDIA),1)
BUILD_FLAGS += --with-nvidia
endif
ifeq ($(DOCKER),1)
BUILD_FLAGS += --docker
endif

.PHONY: help check iso iso-lite iso-vm iso-security iso-docker packages verify lint run run-install clean distclean

help: ## Show this help
	@printf '\033[1mUndraByte Linux %s\033[0m\n\n' '$(VERSION)'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
	@printf '\nVariables: EDITION=%s DESKTOP=%s VM_ONLY=0 BLACKARCH=0 NVIDIA=0 DOCKER=0\n' '$(EDITION)' '$(DESKTOP)'
	@printf 'Example:   make iso EDITION=security DESKTOP=xfce VM_ONLY=1\n'

check: ## Can this machine build and run UndraByte?
	./scripts/check-host.sh

iso: ## Build an ISO (needs Arch + root, or DOCKER=1)
	./scripts/build-iso.sh $(BUILD_FLAGS)

iso-lite: ## Build for a small machine: 2 vCPU / 4 GB guest, XFCE, no gaming
	$(MAKE) iso EDITION=lite DESKTOP=xfce VM_ONLY=1

iso-vm: ## Build a trimmed VM-only ISO
	$(MAKE) iso VM_ONLY=1

iso-security: ## Build the security edition (no gaming stack)
	$(MAKE) iso EDITION=security

iso-docker: ## Build inside an archlinux container (non-Arch hosts)
	$(MAKE) iso DOCKER=1

packages: ## Print the resolved package set for the current edition
	@./scripts/build-iso.sh --edition $(EDITION) --desktop $(DESKTOP) --list-packages

verify: ## Check every package name against the Arch repositories
	./scripts/verify-packages.sh $(if $(filter 1,$(DOCKER)),--docker,)

lint: ## Shell + manifest + profile checks
	./scripts/lint.sh

run: ## Boot the newest ISO in a QEMU VM
	./scripts/run-vm.sh

run-install: ## Boot the ISO with a blank 60G disk attached, ready to install onto
	./scripts/run-vm.sh --disk vm/undrabyte.qcow2 --size 60G

clean: ## Remove build scratch space
	rm -rf work build

distclean: clean ## Also remove built ISOs and VM disks
	rm -rf $(OUT) vm
