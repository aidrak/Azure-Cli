echo "[INFO] Waiting for VM to be fully ready..."

MAX_ATTEMPTS=20
SLEEP_INTERVAL=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  ATTEMPT=$((ATTEMPT + 1))
  echo "[INFO] Attempt $ATTEMPT of $MAX_ATTEMPTS: Checking VM agent status..."

  # Check VM agent status
  VM_AGENT_STATUS=$(az vm get-instance-view \
    --resource-group "RG-Azure-VDI-01" \
    --name "gm-temp-vm" \
    --query "instanceView.vmAgent.statuses[0].displayStatus" \
    --output tsv 2>/dev/null)

  echo "[INFO] VM Agent Status: $VM_AGENT_STATUS"

  if [[ "$VM_AGENT_STATUS" == "Ready" ]]; then
    echo "[SUCCESS] VM agent is ready"

    # Try a simple run-command to verify it's actually working
    echo "[INFO] Testing run-command capability..."
    if az vm run-command invoke \
      --resource-group "RG-Azure-VDI-01" \
      --name "gm-temp-vm" \
      --command-id RunPowerShellScript \
      --scripts "Write-Host 'VM is ready'" \
      --output json > artifacts/outputs/golden-image-validate-vm-test.json 2>&1; then
      echo "[SUCCESS] VM is fully ready and accepting run-commands"
      exit 0
    else
      echo "[WARNING] VM agent reports ready but run-command failed, waiting..."
    fi
  fi

  if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
    echo "[INFO] Waiting ${SLEEP_INTERVAL}s before next attempt..."
    sleep $SLEEP_INTERVAL
  fi
done

echo "[ERROR] VM failed to become ready after $((MAX_ATTEMPTS * SLEEP_INTERVAL)) seconds"
exit 1
