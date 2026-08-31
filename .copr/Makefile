.PHONY: srpm

package_dir := $(patsubst %/,%,$(dir $(spec)))

srpm:
	@test -n "$(spec)" || { echo "COPR did not provide spec=..." >&2; exit 2; }
	$(MAKE) -C "$(package_dir)" srpm outdir="$(outdir)" spec="$(spec)"
