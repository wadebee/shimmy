.PHONY: test-shimmy install-shimmy test-shims install-shims

test-shimmy:
	./scripts/test-shimmy.sh

install-shimmy:
	./scripts/install-shimmy.sh

test-shims: test-shimmy

install-shims: install-shimmy