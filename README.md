# Kubernetes Bootstrap

Kubernetes installation on Ubuntu 16+ with Calico CNI (with hostPort enabled)
and private Docker Image registry DaemonSet on each node.

Bootstrap provides:

* Kubernetes installation via `kubeadm`,
* Kubernetes initialization via `kubeadm` with pods CIDR 192.168.0.0/16 (Calico
  CNI),
* Calico CNI configuration with chained hostmap plugin (requirement for
  hostPort), hostPort is restricted to localhost only for each node for
  security,
* Docker Image Registry via DaemonSet on each node (`localhost:5000`).

# Requirements

* Ubuntu 16+,
* 2 CPU, 2Gb RAM.

# Usage

Commands starting with `@@` requires root login (or sudo) at target host.

All required parameters should be specified as variables assignment in form
of `make <var>=<value>... <command>

## `make @@install`

Installs kubeadm to target host.

Parameters:

* `host` — target host.

## `make @@init`

Initializes kubernetes master, Calico CNI and Docker Image Registry.

Copy join token from command output to join additional nodes.

Parameters:

* `host` — target host.

## `make @@join`

Joins target host to kubernetes master.

Parameters:

* `host` — target host,
* `token` — token to join host to master,
* `master` — master server address (`<host>:<port>`).

## `make @@create-user`

Create user certificate and key, signs user certificate using server key and
downloads them back.

Parameters:

* `host` — target host,
* `username` — user name (`CN=` section in certtificate),
* `organization` — org name (`O=` section in certificate),
* `days` — certificate expiration time.

## `make @connect-registry`

Connects Docker Image Registry to local machine. Imaage Registry will be
available at address `localhost:5000`.
