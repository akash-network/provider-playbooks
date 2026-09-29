#!/bin/bash
#
# Version: 0.2 - 25 March 2023
# Files:
# - /usr/local/bin/akash-force-new-replicasets.sh
# - /etc/cron.d/akash-force-new-replicasets
#
# Description:
# This workaround goes through the newest deployments/replicasets, pods of which can't get deployed due to "insufficient resources" errors and it then removes the older replicasets leaving the newest (latest) one.
# This is only a workaround until a better solution to https://github.com/akash-network/support/issues/82 is found.
#

kubectl get deployment -l akash.network/manifest-service -A -o=jsonpath='{range .items[*]}{.metadata.namespace} {.metadata.name}{"\n"}{end}' |
  while read ns app; do
    kubectl -n $ns rollout status --timeout=10s deployment/${app} >/dev/null 2>&1
    rc=$?
    if [[ $rc -ne 0 ]]; then
      if kubectl -n $ns describe pods | grep -q "Insufficient"; then
        OLD="$(kubectl -n $ns get replicaset -o json -l akash.network/manifest-service --sort-by='{.metadata.creationTimestamp}' | jq -r '(.items | reverse)[1:][] | .metadata.name')"
        for i in $OLD; do kubectl -n $ns delete replicaset $i; done
      fi
    fi
  done
