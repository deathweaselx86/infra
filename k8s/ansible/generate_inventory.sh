#!/bin/bash

# Run this from the k8s/ directory: ./ansible/generate_inventory.sh

set -e

cd "$(dirname "$0")/.."

echo "Fetching Terraform outputs..."

BASTION_IP=$(terraform output -raw bastion_public_ip)
CONTROL_PLANE_IP=$(terraform output -raw control_plane_private_ip)
WORKER_IPS=$(terraform output -json worker_private_ips | jq -r '.[]')
BURSTABLE_WORKER_IPS=$(terraform output -json burstable_worker_private_ips | jq -r '.[]')

cat > ansible/inventory.yml <<EOF
all:
  vars:
    ansible_user: ubuntu
    ansible_ssh_private_key_file: ~/.ssh/id_ed25519
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -q ubuntu@${BASTION_IP}"'

  children:
    bastion:
      hosts:
        bastion:
          ansible_host: ${BASTION_IP}
          ansible_ssh_common_args: '-o StrictHostKeyChecking=no'

    control_plane:
      hosts:
        k8s-control-plane:
          ansible_host: ${CONTROL_PLANE_IP}

    workers:
      hosts:
EOF

worker_index=0
for ip in ${WORKER_IPS}; do
  cat >> ansible/inventory.yml <<EOF
        worker-${worker_index}:
          ansible_host: ${ip}
EOF
  worker_index=$((worker_index + 1))
done

burstable_index=0
for ip in ${BURSTABLE_WORKER_IPS}; do
  cat >> ansible/inventory.yml <<EOF
        burstable-worker-${burstable_index}:
          ansible_host: ${ip}
EOF
  burstable_index=$((burstable_index + 1))
done

echo ""
echo "Inventory generated at ansible/inventory.yml"
echo ""
echo "Test with: ansible all -i ansible/inventory.yml -m ping"
