#!/bin/bash

# Kubernetes HA Cluster Deployment Script
# Usage: ./deploy.sh

set -e

echo "=== Kubernetes HA Cluster Deployment ==="
echo "This script will deploy a Kubernetes HA cluster using Ansible"
echo ""

# Check if Ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    echo "Error: Ansible is not installed. Please install Ansible first."
    echo "Ubuntu/Debian: sudo apt install ansible"
    echo "CentOS/RHEL: sudo yum install ansible"
    echo "macOS: brew install ansible"
    exit 1
fi

# Check if inventory file exists
if [ ! -f "inventory.ini" ]; then
    echo "Error: inventory.ini file not found."
    echo "Please create and configure the inventory.ini file with your server details."
    exit 1
fi

# Display inventory information
echo "Current inventory configuration:"
echo "================================"
cat inventory.ini
echo ""

read -p "Do you want to proceed with this configuration? (y/N): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo "Starting deployment..."
echo "======================"

# Test connectivity to all hosts
echo "1. Testing connectivity to all hosts..."
ansible all -i inventory.ini -m ping

if [ $? -ne 0 ]; then
    echo "Error: Cannot connect to one or more hosts. Please check:"
    echo "- SSH connectivity"
    echo "- SSH keys are properly configured"
    echo "- User permissions"
    exit 1
fi

echo ""
echo "2. Starting Kubernetes cluster deployment..."

# Run the main playbook
ansible-playbook -i inventory.ini k8s-cluster.yml

if [ $? -eq 0 ]; then
    echo ""
    echo "=== Deployment Completed Successfully! ==="
    echo ""
    echo "Your Kubernetes HA cluster is now ready."
    echo ""
    echo "To access the cluster:"
    echo "1. SSH to any master node"
    echo "2. Run: kubectl get nodes"
    echo "3. Run: kubectl get pods -A"
    echo ""
    echo "Load Balancer Endpoint: ${CONTROL_PLANE_ENDPOINT:-10.10.7.220:6443}"
    echo ""
else
    echo ""
    echo "=== Deployment Failed ==="
    echo "Please check the error messages above and fix any issues."
    exit 1
fi