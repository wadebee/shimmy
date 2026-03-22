.PHONY: test-shimmy install-shimmy uninstall-shimmy test-shims install-shims

test-shimmy:
	./shimmy test

install-shimmy:
	./shimmy install

uninstall-shimmy:
	./shimmy uninstall

test-shims: test-shimmy

install-shims: install-shimmy
