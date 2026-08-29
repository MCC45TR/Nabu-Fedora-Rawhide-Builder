.PHONY: test test-core test-limine-core check doctor

test:
	./tests/test_builder.sh
	./tests/test_core_builder.sh
	./tests/test_gnome_builder.sh
	./tests/test_limine_core_builder.sh

test-core:
	./tests/test_core_builder.sh

test-limine-core:
	./tests/test_limine_core_builder.sh

check: test
	bash -n Nabu-Fedora-Rawhide-Builder.sh tests/test_builder.sh tests/test_core_builder.sh \
		tests/test_gnome_builder.sh \
		core-builder/build-core.sh core-builder/container-compose.sh \
		core-builder/lib/common.sh core-builder/lib/verify.sh \
		limine-core-builder/build-core.sh limine-core-builder/container-compose.sh \
		limine-core-builder/lib/common.sh limine-core-builder/lib/verify.sh \
		tests/test_limine_core_builder.sh \
		gnome-builder/build-gnome.sh gnome-builder/container-compose.sh \
		gnome-builder/lib/rpm-special-modes.sh

doctor:
	./Nabu-Fedora-Rawhide-Builder.sh doctor
