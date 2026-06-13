#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "=== 1. Sprawdzenie logowania do Azure CLI ==="
if ! az account show >/dev/null 2>&1; then
  az login
fi

echo "=== 2. Sprawdzenie klucza SSH ==="
if [ ! -f "$HOME/.ssh/id_rsa.pub" ]; then
  echo "Brak klucza SSH. Tworze nowa pare kluczy..."
  ssh-keygen -t rsa -b 2048 -N "" -f "$HOME/.ssh/id_rsa"
fi

echo "=== 3. Terraform: init / plan / apply ==="
cd "$ROOT_DIR/lab03-terraform"
terraform init
terraform plan
terraform apply -auto-approve

echo "=== 4. Pobieranie IP maszyny wirtualnej ==="
VM_IP="$(terraform output -raw vm_public_ip)"
echo "VM_IP=$VM_IP"

echo "=== 5. Oczekiwanie na SSH ==="
while ! nc -z -v -w5 "$VM_IP" 22; do
    echo "Maszyna sie uruchamia, ponowna proba za 5 sekund..."
    sleep 5
done

echo "=== 6. Przygotowanie inventory Ansible ==="
cd "$ROOT_DIR/lab04-ansible"
cp inventory.ini.template inventory.ini
sed -i "s/<PUBLIC_IP>/$VM_IP/g" inventory.ini

echo "=== 6. Przygotowanie inventory Ansible ==="
cd "$ROOT_DIR/lab04-ansible"
cp inventory.ini.template inventory.ini
sed -i "s/<PUBLIC_IP>/$VM_IP/g" inventory.ini

echo "=== 6.1 Przygotowanie pliku index.html ==="
cp files/index.html.template files/index.html

echo "=== 7. Instalacja Apache przez Ansible ==="
export ANSIBLE_HOST_KEY_CHECKING=False
ansible-playbook -i inventory.ini playbook-apache-task.yml

echo
echo "=== Gotowe ==="
echo "Apache task:     http://$VM_IP"
