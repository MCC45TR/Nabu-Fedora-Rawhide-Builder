SHELL := /usr/bin/bash

.PHONY: srpm
srpm:
	@if [[ -x ./build-srpms.sh ]]; then \
		./build-srpms.sh "$(outdir)/rpmbuild"; \
		package=$$(sed -n 's/^Name:[[:space:]]*//p' "$(spec)" | head -n1); \
		cp "$(outdir)"/rpmbuild/SRPMS/"$$package"-*.src.rpm "$(outdir)/"; \
	else \
		./build-srpm.sh "$(outdir)/rpmbuild"; \
		cp "$(outdir)"/rpmbuild/SRPMS/*.src.rpm "$(outdir)/"; \
	fi
