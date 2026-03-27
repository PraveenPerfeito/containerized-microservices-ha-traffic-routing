#!/bin/bash
# =============================================================================
# SkillfyBank Docker Swarm Setup Script
# Creates a multi-manager, multi-worker swarm cluster and deploys the stack
# =============================================================================

set -euo pipefail

# ----- Configuration ---------------------------------------------------------
STACK_NAME="skillfybank"
STACK_FILE="$(dirname "$0")/docker-stack.yml"
DRIVER="virtualbox"          # change to vmwarefusion / hyperv as needed

MANAGERS=("manager1" "manager2" "manager3")
WORKERS=("worker1" "worker2")

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Colour

log()   { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
step()  { echo -e "\n${BLUE}==> $*${NC}"; }

# ----- Helper: create a docker-machine if it doesn't exist -------------------
create_machine() {
    local name="$1"
    if docker-machine ls --format '{{.Name}}' | grep -q "^${name}$"; then
        warn "Machine '${name}' already exists – skipping creation."
    else
        log "Creating machine: ${name}"
        docker-machine create --driver "${DRIVER}" "${name}"
    fi
}

# ----- Helper: run a command on a remote machine -----------------------------
machine_run() {
    local machine="$1"; shift
    docker-machine ssh "${machine}" "$@"
}

# =============================================================================
# STEP 1 – Create Docker Machines
# =============================================================================
step "Creating Docker Machines"
for m in "${MANAGERS[@]}"; do
    create_machine "${m}"
done
for w in "${WORKERS[@]}"; do
    create_machine "${w}"
done

log "All machines created."
docker-machine ls

# =============================================================================
# STEP 2 – Initialise Swarm on manager1
# =============================================================================
step "Initialising Swarm on manager1"
MANAGER1_IP=$(docker-machine ip manager1)

machine_run manager1 docker swarm init --advertise-addr "${MANAGER1_IP}"
log "Swarm initialised on manager1 (IP: ${MANAGER1_IP})"

# Retrieve join tokens
MANAGER_TOKEN=$(machine_run manager1 docker swarm join-token manager -q)
WORKER_TOKEN=$(machine_run manager1 docker swarm join-token worker  -q)

log "Manager join token: ${MANAGER_TOKEN}"
log "Worker  join token: ${WORKER_TOKEN}"

# =============================================================================
# STEP 3 – Join additional managers
# =============================================================================
step "Joining additional managers to the swarm"
for m in manager2 manager3; do
    log "Joining ${m} as manager"
    machine_run "${m}" \
        docker swarm join \
            --token "${MANAGER_TOKEN}" \
            "${MANAGER1_IP}:2377"
    log "${m} joined as manager."
done

# =============================================================================
# STEP 4 – Join workers
# =============================================================================
step "Joining workers to the swarm"
for w in "${WORKERS[@]}"; do
    log "Joining ${w} as worker"
    machine_run "${w}" \
        docker swarm join \
            --token "${WORKER_TOKEN}" \
            "${MANAGER1_IP}:2377"
    log "${w} joined as worker."
done

# =============================================================================
# STEP 5 – Verify cluster membership
# =============================================================================
step "Verifying cluster node membership"
machine_run manager1 docker node ls

# =============================================================================
# STEP 6 – Deploy the SkillfyBank stack
# =============================================================================
step "Deploying stack '${STACK_NAME}'"

# Copy the stack file to manager1 so it can deploy from there
docker-machine scp "${STACK_FILE}" manager1:/tmp/docker-stack.yml

machine_run manager1 \
    docker stack deploy \
        --compose-file /tmp/docker-stack.yml \
        --with-registry-auth \
        "${STACK_NAME}"

log "Stack '${STACK_NAME}' deployed."

# =============================================================================
# STEP 7 – Wait for services to start and show status
# =============================================================================
step "Waiting 30 seconds for services to stabilise..."
sleep 30

step "Service status"
machine_run manager1 docker stack services "${STACK_NAME}"

step "Stack tasks (containers)"
machine_run manager1 docker stack ps "${STACK_NAME}" --no-trunc

# =============================================================================
# STEP 8 – Print access URLs
# =============================================================================
step "Access URLs"
echo -e "${GREEN}Account Service     :${NC} http://${MANAGER1_IP}:3000"
echo -e "${GREEN}Transaction Service :${NC} http://${MANAGER1_IP}:8080"
echo -e "${GREEN}Notification Service:${NC} http://${MANAGER1_IP}:5000"
echo
log "SkillfyBank swarm setup complete!"
