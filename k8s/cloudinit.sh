#!/bin/bash

set -e

K8S_VERSION="1.34.2-1.1"
K8S_SHORT_VERSION="v1.34"
apt-get update && apt-get upgrade -y
apt install apt-transport-https tree bash-completion software-properties-common ca-certificates socat -y

# configure networking for k8s
modprobe overlay 
modprobe br_netfilter

cat > /etc/sysctl.d/kubernetes.conf << BLOCK
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1 
BLOCK

sysctl --system

# install gpg keys
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
| gpg --dearmor -o /etc/apt/keyrings/docker.gpg

curl -fsSL https://pkgs.k8s.io/core:/stable:/${K8S_SHORT_VERSION}/deb/Release.key \
| gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# add apt sources
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/${K8S_SHORT_VERSION}/deb/ /" \
| tee /etc/apt/sources.list.d/kubernetes.list

apt-get update

# install containerd
apt-get install containerd.io -y
containerd config default | tee /etc/containerd/config.toml
sed -e 's/SystemdCgroup = false/SystemdCgroup = true/' -i /etc/containerd/config.toml
systemctl restart containerd

# install k8s components
apt-get install -y kubeadm=$K8S_VERSION kubelet=$K8S_VERSION kubectl=$K8S_VERSION
