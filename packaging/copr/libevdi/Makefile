.PHONY: srpm
srpm:
	bash ./build-srpm.sh "$(outdir)/rpmbuild"
	cp "$(outdir)"/rpmbuild/SRPMS/*.src.rpm "$(outdir)/"
