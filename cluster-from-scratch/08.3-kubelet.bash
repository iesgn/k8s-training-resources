#!/bin/bash

source ./common.bash

#
# This part is to be executed again in the worker node
#
export KUBELET_CERT_OUT_PATH=/tmp/kubelet.crt

# Download the generated certificate (NOT THE PROPER WAY)
scp ubuntu@$CONTROLLER_PUBLIC_IP:$KUBELET_CERT_OUT_PATH "$KUBELET_CERT_PATH"
scp ubuntu@$CONTROLLER_PUBLIC_IP:$KUBERNETES_CA_CERT_PATH "$KUBERNETES_CA_CERT_PATH"

#
# Install kubectl for creating the required kubeconfig
#
wget -q "$KUBECTL_URL" -P "$KUBERNETES_BIN_DIR"
chmod +x "$KUBERNETES_BIN_DIR/kubectl"

#
# Create kubeconfig for kubelet
#
kubectl config set-cluster k8s-training --certificate-authority=$KUBERNETES_CA_CERT_PATH --embed-certs=true --server=https://${CONTROLLER_PRIVATE_IP}:6443 --kubeconfig=${KUBELET_KUBECONFIG_PATH}
kubectl config set-credentials system:node:${HOSTNAME} --client-certificate=$KUBELET_CERT_PATH --client-key=$KUBELET_KEY_PATH --embed-certs=true --kubeconfig=${KUBELET_KUBECONFIG_PATH}
kubectl config set-context default --cluster=k8s-training --user=system:node:${HOSTNAME} --kubeconfig=${KUBELET_KUBECONFIG_PATH}
kubectl config use-context default --kubeconfig=${KUBELET_KUBECONFIG_PATH}

#
# Install dependencies
#

## containerd
wget -q $CONTAINERD_TARBALL_URL -P /tmp
tar xf "/tmp/$CONTAINERD_TARBALL_NAME" -C /

## cni
mkdir -p /opt/cni/bin
mkdir -p /etc/cni/net.d
wget -q $CNI_TARBALL_URL -P /tmp
tar xf "/tmp/$CNI_TARBALL_NAME" -C /opt/cni/bin/

## Start containerd
systemctl enable containerd.service
systemctl start containerd

#
# Install kubelet
#

echo "Installing kubelet"

## Download
wget -q "$KUBELET_URL" -P "$KUBERNETES_BIN_DIR"
chmod +x "$KUBERNETES_BIN_DIR/kubelet"

## Create systemd service
cat << EOF | sudo tee "$KUBELET_SYSTEMD_SERVICE_PATH"
[Unit]
Description=kubelet

[Service]
ExecStart=${KUBERNETES_BIN_DIR}/kubelet \\
  --kubeconfig=${KUBELET_KUBECONFIG_PATH} \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --network-plugin=cni \\
  --cni-conf-dir=/etc/cni/net.d \\
  --cni-bin-dir=/opt/cni/bin \\
  --client-ca-file=${KUBERNETES_CA_CERT_PATH} \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kubelet.service
systemctl restart kubelet.service

# Cleanup
rm /tmp/kubelet* -rf

