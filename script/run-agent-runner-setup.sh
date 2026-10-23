#!/bin/bash
# Set up the isolated AI fix agent runner on ai-vm, in the safe order.
# Plan: tfd-blog-next/docs/AI_OPS_AGENT.md, section 5.5.
#   ./script/run-agent-runner-setup.sh software   # Docker, Node, pnpm, gh, runner files (no registration)
#   ./script/run-agent-runner-setup.sh firewall   # Proxmox firewall for VM 108 (arms a 5 minute lock-out rollback)
#   ./script/run-agent-runner-setup.sh confirm    # cancel the rollback after checking SSH and the web UI
#   ./script/run-agent-runner-setup.sh snapshot   # after registering the runner: take the clean snapshot
# Extra arguments go to ansible-playbook (for example --check --diff).
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../ansible"

STEP="${1:-}"
[ -n "$STEP" ] && shift
case "$STEP" in
  software) ansible-playbook playbooks/services/agent-runner-setup.yml "$@" ;;
  firewall) ansible-playbook playbooks/networking/agent-runner-firewall.yml "$@" ;;
  confirm)  ansible-playbook playbooks/networking/agent-runner-firewall.yml -e agent_fw_confirm=true --tags confirm "$@" ;;
  snapshot) ansible-playbook playbooks/networking/agent-runner-firewall.yml -e agent_take_snapshot=true --tags snapshot "$@" ;;
  *) sed -n 2,9p "$0"; exit 1 ;;
esac
