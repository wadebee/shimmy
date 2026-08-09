# OpenShift CLI 4.22 image build

`Containerfile` receives the configured Red Hat OpenShift 4.22 manifest-list
digest through its required build argument. It sets `/work` and exposes `oc`.
