# OpenShift CLI 4.18 image build

`Containerfile` receives the configured Red Hat OpenShift 4.18 manifest-list
digest through its required build argument. It sets `/work` and exposes `oc`.
