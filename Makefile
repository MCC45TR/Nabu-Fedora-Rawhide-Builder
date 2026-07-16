.PHONY: test check doctor

test:
	./tests/test_builder.sh

check: test
	bash -n Nabu-Fedora-Rawhide-Builder.sh tests/test_builder.sh

doctor:
	./Nabu-Fedora-Rawhide-Builder.sh doctor
