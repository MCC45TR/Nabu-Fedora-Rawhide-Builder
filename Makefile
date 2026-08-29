.PHONY: test test-core check doctor

test:
	./tests/test_builder.sh
	./tests/test_core_builder.sh

test-core:
	./tests/test_core_builder.sh

check: test
	bash -n Nabu-Fedora-Rawhide-Builder.sh tests/test_builder.sh tests/test_core_builder.sh \
		core-builder/build-core.sh core-builder/container-compose.sh \
		core-builder/lib/common.sh core-builder/lib/verify.sh

doctor:
	./Nabu-Fedora-Rawhide-Builder.sh doctor
