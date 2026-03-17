.PHONY: test-shimmy install-shimmy uninstall-shimmy test-shims install-shims

test-shimmy:
	./scripts/test-shimmy.sh

install-shimmy:
	./scripts/install-shimmy.sh

uninstall-shimmy:
	./scripts/install-shimmy.sh --uninstall

test-shims: test-shimmy

install-shims: install-shimmy
