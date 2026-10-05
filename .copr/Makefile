SHELL := /usr/bin/bash
.SHELLFLAGS := -euo pipefail -c

.PHONY: srpm

package_dir := $(patsubst %/,%,$(dir $(spec)))

srpm:
	@test -n "$(spec)" || { echo "COPR did not provide spec=..." >&2; exit 2; }
	@if [[ -f "$(package_dir)/Makefile" ]]; then \
		$(MAKE) -C "$(package_dir)" srpm outdir="$(outdir)" spec="$(spec)"; \
	elif [[ -x "$(package_dir)/build-srpms.sh" ]]; then \
		"$(package_dir)/build-srpms.sh" "$(outdir)/rpmbuild"; \
		package=$$(sed -n 's/^Name:[[:space:]]*//p' "$(spec)" | head -n1); \
		[[ -n "$$package" ]]; \
		cp "$(outdir)"/rpmbuild/SRPMS/"$$package"-*.src.rpm "$(outdir)/"; \
	elif [[ -x "$(package_dir)/build-srpm.sh" ]]; then \
		"$(package_dir)/build-srpm.sh" "$(outdir)/rpmbuild"; \
		cp "$(outdir)"/rpmbuild/SRPMS/*.src.rpm "$(outdir)/"; \
	else \
		echo "No SRPM builder for $(spec)" >&2; exit 2; \
	fi
