# OpenShift CLI 4.22 image build

`Containerfile` wraps the Red Hat OpenShift 4.22 CLI manifest-list digest so
Podman selects the correct supported architecture. It sets the working
directory to `/work` and exposes `oc` as its entrypoint.
