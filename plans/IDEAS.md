# Strategies to Beat the 2-VM Limit on Apple Silicon:
Remote Connections (True Concurrency): If you need truly concurrent environments, you must run the additional Podman instances on external Linux servers (or a Linux VM managed outside of podman machine, e.g., via UTM or Multipass) and add them as remote connections:
## Add an external server as a connection
podman system connection add external-vm ssh://user@192.168.1.50/run/podman/podman.sock

## Now you can talk to "external-vm" while your local "default" machine is running
podman --connection external-vm ps# 

### Re: Allow multiple Podman Machines to run
TL;DR
On darwin the single-VM rule is enforced by one gate, not by deep architectural coupling.
Almost all the per-machine host-side plumbing (gvproxy socket, API socket, SSH port, vfkit endpoint) is already namespaced per machine.
The "which machine the client talks to" concept is already separable and switchable (named connections / podman system connection default / CONTAINER_HOST).
For anyone who needs concurrent VMs on macOS right now, Lima does it out of the box, with podman acting as a plain remote client.
Where the limit actually lives
The block happens at podman machine start, gated on the provider's RequireExclusiveActive():

Check: checkExclusiveActiveVM() — pkg/machine/shim/host.go
Gate: if mp.RequireExclusiveActive() { ... } in Start() — pkg/machine/shim/host.go
Per-provider flag:
applehv → true (pkg/machine/applehv/stubber.go)
libkrun → true (pkg/machine/libkrun/stubber.go)
qemu → true (pkg/machine/qemu/stubber.go)
hyperv → true (pkg/machine/hyperv/stubber.go)
wsl → false (pkg/machine/wsl/stubber.go) — which is why WSL already runs multiple machines in parallel.
The check keys off live VM state: State() probes the actual hypervisor (vfkit REST endpoint for applehv, QMP socket for qemu). So you can't keep a second VM "warm but unmanaged" — if the process is alive, it counts as Running and trips the gate. There is no detach/pause concept; Stop() always tears the hypervisor down.

What's already per-machine (so wouldn't collide)
Resource	Per-machine today?
gvproxy listening socket ({name}-gvproxy.sock)	✅
API socket ({name}-api.sock)	✅
SSH port (allocated per machine)	✅
vfkit REST endpoint (random port per machine)	✅
Named connection + default-connection switching	✅
gvproxy pidfile/log (/tmp/podman/gvproxy.pid)	❌ shared
/var/run/docker.sock + global podman.sock symlink	❌ singleton (by design)
The genuinely shared bits are the gvproxy pidfile and the two "well-known" docker-compat sockets — and the docker.sock path already tolerates multiple machines: first to start claims it, later machines silently fall back to their own machine-local socket (pkg/machine/shim/networking_unix.go). Those sockets are really just the host-side equivalent of "which connection is default".

Why this matters for the feature request
The maintainer's "reasons deeper than podman" (gvproxy + the socket forwarders) are real, but narrower than they sound: the per-VM forwarding is already isolated, and the shared sockets already degrade gracefully. The hard stop is the one RequireExclusiveActive() gate.

That suggests a much smaller, opt-in ask than "transparent multi-VM with shared forwarding":

An opt-in flag to allow multiple running VMs, with explicit connection selection — i.e. all N stay warm, exactly one owns the unqualified docker.sock/default connection at a time, and you pick the active one with podman system connection default <name> (or target any of them directly via CONTAINER_HOST).

That model needs essentially just the gate relaxed; the selection mechanism and per-machine isolation already exist. It avoids the genuinely hard problem (multiple machines transparently sharing one docker.sock) by making selection explicit.

Workaround today: Lima
Lima runs N concurrent VMs on the same vfkit/AVF substrate. Crucially, Lima ships a podman template, so each VM can run a real podman service and expose a libpod socket — meaning you stay in pure podman remote land, no nerdctl or docker client needed:

limactl start --name vm1 template://podman
limactl start --name vm2 template://podman      # both stay warm — no swap dance

#### wire each VM's forwarded podman socket as a named connection, then just switch:
podman system connection default vm1
podman ps                                        # talks to vm1
podman system connection default vm2
podman ps                                        # now talks to vm2
This is exactly the "keep all warm, switch which one is active" workflow — podman system connection default is doing the switching against ordinary podman services that happen to live in Lima VMs. RequireExclusiveActive() never enters into it: it only gates podman machine start and only counts podman machines, which Lima VMs are not.

Two things worth knowing:

The switch works because podman system connection / podman --remote speak the libpod API, so the endpoint must be a podman service — which the podman template provides. (A plain containerd/docker socket would not work with podman remote; that's the only case where you'd reach for nerdctl.)
Standard OCI image tarballs load into a podman-template VM via podman load -i, same as podman machi