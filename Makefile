@@install:
	$(call !check-var,host)

	@$(!ssh) "apt-get update && apt-get install -y apt-transport-https"
	@$(!ssh) "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -"
	@$(!ssh) "echo deb http://apt.kubernetes.io/ kubernetes-xenial main >> /etc/apt/sources.list.d/kubernetes.list"
	@$(!ssh) "apt-get update && apt-get install -y kubelet kubeadm docker.io"
	@$(!ssh) "curl -Lo /usr/local/bin/calicoctl https://www.projectcalico.org/builds/calicoctl && chmod +x /usr/local/bin/calicoctl"

@@init:
	$(call !check-var,host)

	@$(!ssh) "kubeadm init --pod-network-cidr=192.168.0.0/16"
	@$(!ssh) "mkdir -p ~/.kube"
	@$(!ssh) "cp /etc/kubernetes/admin.conf ~/.kube/config"
	@$(!ssh) <$(make-dir)/calico.yaml "kubectl apply -f -"
	@$(eval _etcd = http://10.96.232.136:6666)
	@$(!ssh) sh -s <<< "while ! curl -s $(_etcd)/version; do :; done; echo"
	@$(!ssh) <$(make-dir)/image-registry-policy.yaml "ETCD_ENDPOINTS=$(_etcd) echo calicoctl apply -f -"
	@$(!ssh) <$(make-dir)/image-registry.yaml "kubectl apply -f -"
	@$(!ssh) "kubectl cluster-info"
	@$(!ssh) "kubeadm token list"

@@join:
	$(call !check-var,host)
	$(call !check-var,token)
	$(call !check-var,master)

	@$(!ssh) "kubeadm join --token=$(token) $(master)"

@@create-user:
	$(call !check-var,host)
	$(call !check-var,username)
	$(call !check-var,organization)
	$(call !check-var,days)

	$(eval _tmpdir = $(shell $(!ssh) mktemp -d))

	@mkdir -p $(username)

	@$(!ssh) openssl genrsa -out $(_tmpdir)/$(username).key 2048
	@$(!ssh) openssl req -new -key $(_tmpdir)/$(username).key \
		-out $(_tmpdir)/$(username).csr -subj "/CN=$(username)/O=$(organization)"
	@$(!ssh) openssl x509 -req -in $(_tmpdir)/$(username).csr \
		-CA $(kube-ca-dir)/ca.crt -CAkey $(kube-ca-dir)/ca.key \
		-CAcreateserial -out $(_tmpdir)/$(username).crt -days $(days)

	@$(!ssh) cat $(_tmpdir)/$(username).crt > $(username)/$(username).crt
	@$(!ssh) cat $(_tmpdir)/$(username).key > $(username)/$(username).key
	@$(!ssh) cat $(kube-ca-dir)/ca.crt > $(username)/ca.crt

	@$(!ssh) rm -rf $(_tmpdir)

@connect-registry:
	$(!check-kubectl)

	@kubectl port-forward --namespace kube-system $$( \
		kubectl get pods \
			--namespace kube-system -l k8s-app=kube-image-registry-upstream \
			-o template --template '{{range .items}}{{.metadata.name}} {{.status.phase}}{{"\n"}}{{end}}' \
				| grep Running | head -1 | cut -f1 -d' ' \
		) \
		5000:5000

kube-ca-dir = /etc/kubernetes/pki

make-dir = $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

!ssh = ssh -o StrictHostKeyChecking=no $(_ssh_flags) $(host) sudo
!check-kubectl = $(call !check-binary,kubectl)

define !check-var
	$(eval
        ifeq '$($(1))' ''
            $$(error prerequisite failed: variable '$(1)' is not set at call time)
        endif
	)
endef

define !check-binary
	$(eval
        ifeq '$(shell which $(1) 2>&-)' ''
            $$(error prerequisite failed: binary '$(1)' is not found in PATH)
        endif
	)
endef
