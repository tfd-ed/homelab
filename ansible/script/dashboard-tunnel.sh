#!/bin/bash
echo "Creating SSH tunnel to Kubernetes Dashboard..."
echo "Dashboard will be available at: https://localhost:8443"
echo "Press Ctrl+C to stop the tunnel"
ssh -L 8443:localhost:30443 -i /Users/kimang/Documents/ProgrammingProjects/homelab-journey/ansible/playbooks/kubernetes/../../ssh-keys/vm-key ubuntu@192.168.100.201
