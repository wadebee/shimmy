# OpenShift CLI 4.20 image build

`Containerfile` receives the configured Red Hat OpenShift 4.20 manifest-list
digest through its required build argument. It sets `/work` and exposes `oc`.
