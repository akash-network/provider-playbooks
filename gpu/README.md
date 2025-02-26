This ansible role covers the steps required for the installation of the GPU drivers.

### Prerequisites
- Host with GPUs
- Access to Kubernetes Cluster
- Kubectl binary
- Helm binary
- Jq binary

### Install the requirements
We need to install the Kubernetes core module specified in the requirements.yml file
```
sudo apt install python3-kubernetes
ansible-galaxy install -r requirements.yml
```

### Running the playbook
```
ansible-playbook playbooks.yaml -e 'host=target' -i inv -v
```

### Configuration Variables
| Variable                 | Description                                        | Required | Default                |
|--------------------------|----------------------------------------------------|----------|------------------------|
| `nvidia_version`         | Nvidia Driver Version                              | Yes      | 565.57.01              |

### Examples
#### Deployment

```
ansible-playbook playbooks.yaml -e 'host=target' -i inv -v
No config file found; using defaults

PLAY [GPU Playbook] ************************************************************************************************************

TASK [Gathering Facts] *********************************************************************************************************
ok: [server1]

TASK [gpu : Create NVIDIA RuntimeClass manifest] *******************************************************************************
ok: [server1] => {"changed": false, "checksum": "49d907d1e756812b63f78e9258a21d062ab9f1d1", "dest": "/home/ubuntu/nvidia-runtime-class.yml", "gid": 0, "group": "root", "mode": "0644", "owner": "root", "path": "/home/ubuntu/nvidia-runtime-class.yml", "size": 87, "state": "file", "uid": 0}

TASK [gpu : Apply NVIDIA RuntimeClass] *****************************************************************************************
ok: [server1] => {"changed": false, "method": "update", "result": {"apiVersion": "node.k8s.io/v1", "handler": "nvidia", "kind": "RuntimeClass", "metadata": {"annotations": {"objectset.rio.cattle.io/applied": "H4sIAAAAAAAA/4yQvW7rMAyFX+XizIovHMOJI6BD0bFbh+6URNeqbSowFRdF4HcvhGbo0p+R+MiPh7yCzvGZF41JYCEpcDV2WsX0f61hMJCEiZeC1hgiwWCMEmDxdJEcZ36YSBUGM2cKlAn2ChJJmXJMoqVM7pV9Vs7VElPlKeeJy4JYNDDf8vQmvOxe1hEWY6NfyFqbf49Rwt19CEl+VQjNDIvlM7H+qV/P5MvQeHG803fNPGMzmMjx9ONVA+kAi/a4b2rHdDq0ne/3be8D+X3T1749dC35o3O+P3VNkd7y3T68bR8BAAD///Uj4MeVAQAA", "objectset.rio.cattle.io/id": "", "objectset.rio.cattle.io/owner-gvk": "k3s.cattle.io/v1, Kind=Addon", "objectset.rio.cattle.io/owner-name": "runtimes", "objectset.rio.cattle.io/owner-namespace": "kube-system"}, "creationTimestamp": "2025-02-26T17:31:47Z", "labels": {"objectset.rio.cattle.io/hash": "57231bea9658cf25fcdac23f1c5685ac7bbcf983"}, "managedFields": [{"apiVersion": "node.k8s.io/v1", "fieldsType": "FieldsV1", "fieldsV1": {"f:handler": {}, "f:metadata": {"f:annotations": {".": {}, "f:objectset.rio.cattle.io/applied": {}, "f:objectset.rio.cattle.io/id": {}, "f:objectset.rio.cattle.io/owner-gvk": {}, "f:objectset.rio.cattle.io/owner-name": {}, "f:objectset.rio.cattle.io/owner-namespace": {}}, "f:labels": {".": {}, "f:objectset.rio.cattle.io/hash": {}}}}, "manager": "deploy@node1", "operation": "Update", "time": "2025-02-26T17:31:47Z"}], "name": "nvidia", "resourceVersion": "336", "uid": "9ee6aa82-430b-40a5-964c-dbfe78bfdc1d"}}}

TASK [gpu : Label GPU nodes for NVIDIA support] ********************************************************************************
ok: [server1] => (item=node1) => {"ansible_loop_var": "item", "changed": false, "item": "node1", "method": "update", "result": {"apiVersion": "v1", "kind": "Node", "metadata": {"annotations": {"alpha.kubernetes.io/provided-node-ip": "10.0.1.97", "flannel.alpha.coreos.com/backend-data": "{\"VNI\":1,\"VtepMAC\":\"d2:19:ce:bc:8b:20\"}", "flannel.alpha.coreos.com/backend-type": "vxlan", "flannel.alpha.coreos.com/kube-subnet-manager": "true", "flannel.alpha.coreos.com/public-ip": "10.0.1.97", "k3s.io/hostname": "node1", "k3s.io/internal-ip": "10.0.1.97", "k3s.io/node-args": "[\"server\"]", "k3s.io/node-config-hash": "MLFMUCBMRVINLJJKSG32TOUFWB4CN55GMSNY25AZPESQXZCYRN2A====", "k3s.io/node-env": "{}", "node.alpha.kubernetes.io/ttl": "0", "volumes.kubernetes.io/controller-managed-attach-detach": "true"}, "creationTimestamp": "2025-02-26T17:31:44Z", "finalizers": ["wrangler.cattle.io/node"], "labels": {"allow-nvdp": "true", "beta.kubernetes.io/arch": "amd64", "beta.kubernetes.io/instance-type": "k3s", "beta.kubernetes.io/os": "linux", "kubernetes.io/arch": "amd64", "kubernetes.io/hostname": "node1", "kubernetes.io/os": "linux", "node-role.kubernetes.io/control-plane": "true", "node-role.kubernetes.io/master": "true", "node.kubernetes.io/instance-type": "k3s", "nvidia.com/gpu.present": "true"}, "managedFields": [{"apiVersion": "v1", "fieldsType": "FieldsV1", "fieldsV1": {"f:metadata": {"f:finalizers": {".": {}, "v:\"wrangler.cattle.io/node\"": {}}, "f:labels": {"f:node-role.kubernetes.io/control-plane": {}, "f:node-role.kubernetes.io/master": {}}}}, "manager": "k3s-supervisor@node1", "operation": "Update", "time": "2025-02-26T17:31:44Z"}, {"apiVersion": "v1", "fieldsType": "FieldsV1", "fieldsV1": {"f:metadata": {"f:annotations": {".": {}, "f:alpha.kubernetes.io/provided-node-ip": {}, "f:k3s.io/hostname": {}, "f:k3s.io/internal-ip": {}, "f:k3s.io/node-args": {}, "f:k3s.io/node-config-hash": {}, "f:k3s.io/node-env": {}, "f:node.alpha.kubernetes.io/ttl": {}, "f:volumes.kubernetes.io/controller-managed-attach-detach": {}}, "f:labels": {".": {}, "f:beta.kubernetes.io/arch": {}, "f:beta.kubernetes.io/instance-type": {}, "f:beta.kubernetes.io/os": {}, "f:kubernetes.io/arch": {}, "f:kubernetes.io/hostname": {}, "f:kubernetes.io/os": {}, "f:node.kubernetes.io/instance-type": {}}}, "f:spec": {"f:podCIDR": {}, "f:podCIDRs": {".": {}, "v:\"10.42.0.0/24\"": {}}, "f:providerID": {}}}, "manager": "k3s", "operation": "Update", "time": "2025-02-26T17:31:49Z"}, {"apiVersion": "v1", "fieldsType": "FieldsV1", "fieldsV1": {"f:metadata": {"f:labels": {"f:allow-nvdp": {}, "f:nvidia.com/gpu.present": {}}}}, "manager": "kubectl-label", "operation": "Update", "time": "2025-02-27T06:56:11Z"}, {"apiVersion": "v1", "fieldsType": "FieldsV1", "fieldsV1": {"f:metadata": {"f:annotations": {"f:flannel.alpha.coreos.com/backend-data": {}, "f:flannel.alpha.coreos.com/backend-type": {}, "f:flannel.alpha.coreos.com/kube-subnet-manager": {}, "f:flannel.alpha.coreos.com/public-ip": {}}}, "f:status": {"f:allocatable": {"f:memory": {}, "f:nvidia.com/gpu": {}}, "f:capacity": {"f:memory": {}, "f:nvidia.com/gpu": {}}, "f:conditions": {"k:{\"type\":\"DiskPressure\"}": {"f:lastHeartbeatTime": {}}, "k:{\"type\":\"MemoryPressure\"}": {"f:lastHeartbeatTime": {}}, "k:{\"type\":\"PIDPressure\"}": {"f:lastHeartbeatTime": {}}, "k:{\"type\":\"Ready\"}": {"f:lastHeartbeatTime": {}, "f:message": {}, "f:reason": {}, "f:status": {}}}, "f:images": {}, "f:nodeInfo": {"f:bootID": {}, "f:kernelVersion": {}}}}, "manager": "k3s", "operation": "Update", "subresource": "status", "time": "2025-02-27T07:06:23Z"}], "name": "node1", "resourceVersion": "15619", "uid": "aa21ac1c-32e5-44a3-96f1-a45c64aae739"}, "spec": {"podCIDR": "10.42.0.0/24", "podCIDRs": ["10.42.0.0/24"], "providerID": "k3s://node1"}, "status": {"addresses": [{"address": "10.0.1.97", "type": "InternalIP"}, {"address": "node1", "type": "Hostname"}], "allocatable": {"cpu": "252", "ephemeral-storage": "6524650321719", "hugepages-1Gi": "0", "hugepages-2Mi": "0", "memory": "1486144692Ki", "nvidia.com/gpu": "8", "pods": "110"}, "capacity": {"cpu": "252", "ephemeral-storage": "6707082984Ki", "hugepages-1Gi": "0", "hugepages-2Mi": "0", "memory": "1486144692Ki", "nvidia.com/gpu": "8", "pods": "110"}, "conditions": [{"lastHeartbeatTime": "2025-02-27T07:06:23Z", "lastTransitionTime": "2025-02-26T17:31:44Z", "message": "kubelet has sufficient memory available", "reason": "KubeletHasSufficientMemory", "status": "False", "type": "MemoryPressure"}, {"lastHeartbeatTime": "2025-02-27T07:06:23Z", "lastTransitionTime": "2025-02-26T17:31:44Z", "message": "kubelet has no disk pressure", "reason": "KubeletHasNoDiskPressure", "status": "False", "type": "DiskPressure"}, {"lastHeartbeatTime": "2025-02-27T07:06:23Z", "lastTransitionTime": "2025-02-26T17:31:44Z", "message": "kubelet has sufficient PID available", "reason": "KubeletHasSufficientPID", "status": "False", "type": "PIDPressure"}, {"lastHeartbeatTime": "2025-02-27T07:06:23Z", "lastTransitionTime": "2025-02-26T17:31:44Z", "message": "kubelet is posting ready status", "reason": "KubeletReady", "status": "True", "type": "Ready"}], "daemonEndpoints": {"kubeletEndpoint": {"Port": 10250}}, "images": [{"names": ["nvcr.io/nvidia/k8s-device-plugin@sha256:ed39e22c8b71343fb996737741a99da88ce6c75dd83b5c520e0b3d8e8a884c47", "nvcr.io/nvidia/k8s-device-plugin:v0.16.2"], "sizeBytes": 126081487}, {"names": ["docker.io/rancher/klipper-helm@sha256:73ff7ef399717ba8339559054557bd427bdafb47db112165a8c0c358d1ca0283", "docker.io/rancher/klipper-helm:v0.9.3-build20241008"], "sizeBytes": 70496341}, {"names": ["docker.io/rancher/mirrored-library-traefik@sha256:25df7bff0b414867f16a74c571c0dc84920404e45cc7780976cec77809230e09", "docker.io/rancher/mirrored-library-traefik:2.11.18"], "sizeBytes": 49449055}, {"names": ["docker.io/rancher/mirrored-coredns-coredns@sha256:82979ddf442c593027a57239ad90616deb874e90c365d1a96ad508c2104bdea5", "docker.io/rancher/mirrored-coredns-coredns:1.12.0"], "sizeBytes": 20938299}, {"names": ["docker.io/rancher/mirrored-metrics-server@sha256:dccf8474fb910fef261d31d9483d7e4c1df7b86cf4d638fb6a7d7c88bd51600a", "docker.io/rancher/mirrored-metrics-server:v0.7.2"], "sizeBytes": 19494186}, {"names": ["docker.io/rancher/local-path-provisioner@sha256:9b914881170048f80ae9302f36e5b99b4a6b18af73a38adc1c66d12f65d360be", "docker.io/rancher/local-path-provisioner:v0.0.30"], "sizeBytes": 18584855}, {"names": ["docker.io/rancher/klipper-lb@sha256:dd380f5d89a52f2a07853ff17a6048f805c1f8113b50578f3efc3efb9bcf670a", "docker.io/rancher/klipper-lb:v0.4.9"], "sizeBytes": 4990278}, {"names": ["docker.io/rancher/mirrored-pause@sha256:74c4244427b7312c5b901fe0f67cbc53683d06f4f24c6faee65d4182bf0fa893", "docker.io/rancher/mirrored-pause:3.6"], "sizeBytes": 301463}], "nodeInfo": {"architecture": "amd64", "bootID": "f41e0903-11b3-406c-bb21-41d9e897b252", "containerRuntimeVersion": "containerd://1.7.23-k3s2", "kernelVersion": "6.8.0-54-generic", "kubeProxyVersion": "v1.31.5+k3s1", "kubeletVersion": "v1.31.5+k3s1", "machineID": "d9372db8946f472f8787a2478dce7f44", "operatingSystem": "linux", "osImage": "Ubuntu 24.04.2 LTS", "systemUUID": "27d7c14b-409d-48c2-9263-b9ce3e52a6b5"}}}}

TASK [gpu : Add NVIDIA Device Plugin Helm repository] **************************************************************************
ok: [server1] => {"changed": false, "repo_name": "nvdp", "repo_url": "https://nvidia.github.io/k8s-device-plugin"}

TASK [gpu : Update Helm repositories] ******************************************************************************************
changed: [server1] => {"changed": true, "cmd": ["helm", "repo", "update"], "delta": "0:00:00.089838", "end": "2025-02-27 07:10:20.645526", "msg": "", "rc": 0, "start": "2025-02-27 07:10:20.555688", "stderr": "", "stderr_lines": [], "stdout": "Hang tight while we grab the latest from your chart repositories...\n...Successfully got an update from the \"nvdp\" chart repository\nUpdate Complete. ⎈Happy Helming!⎈", "stdout_lines": ["Hang tight while we grab the latest from your chart repositories...", "...Successfully got an update from the \"nvdp\" chart repository", "Update Complete. ⎈Happy Helming!⎈"]}

TASK [gpu : Check for required GPU node labels] ********************************************************************************
ok: [server1] => {"changed": false, "cmd": "kubectl get nodes -o json | jq -r '.items[] |  {\n  \"name\": .metadata.name, \n  \"has_allow_nvdp\": (.metadata.labels.\"allow-nvdp\" == \"true\"), \n  \"has_gpu_present\": (.metadata.labels.\"nvidia.com/gpu.present\" == \"true\")\n} | tostring'\n", "delta": "0:00:00.108017", "end": "2025-02-27 07:10:29.814669", "msg": "", "rc": 0, "start": "2025-02-27 07:10:29.706652", "stderr": "", "stderr_lines": [], "stdout": "{\"name\":\"node1\",\"has_allow_nvdp\":true,\"has_gpu_present\":true}", "stdout_lines": ["{\"name\":\"node1\",\"has_allow_nvdp\":true,\"has_gpu_present\":true}"]}

TASK [gpu : Parse node label results] ******************************************************************************************
ok: [server1] => {"ansible_facts": {"parsed_node_labels": [{"has_allow_nvdp": true, "has_gpu_present": true, "name": "node1"}]}, "changed": false}

TASK [gpu : Display nodes missing required labels] *****************************************************************************
skipping: [server1] => (item={'name': 'node1', 'has_allow_nvdp': True, 'has_gpu_present': True})  => {"ansible_loop_var": "item", "false_condition": "not (item.has_allow_nvdp and item.has_gpu_present)", "item": {"has_allow_nvdp": true, "has_gpu_present": true, "name": "node1"}}
skipping: [server1] => {"msg": "All items skipped"}

TASK [gpu : Fail if required labels are missing] *******************************************************************************
skipping: [server1] => (item={'name': 'node1', 'has_allow_nvdp': True, 'has_gpu_present': True})  => {"ansible_loop_var": "item", "changed": false, "false_condition": "not (item.has_allow_nvdp and item.has_gpu_present)", "item": {"has_allow_nvdp": true, "has_gpu_present": true, "name": "node1"}, "skip_reason": "Conditional result was False"}
skipping: [server1] => {"changed": false, "msg": "All items skipped"}

TASK [gpu : Check if any node has all required labels] *************************************************************************
ok: [server1] => (item={'name': 'node1', 'has_allow_nvdp': True, 'has_gpu_present': True}) => {"ansible_facts": {"labels_ready": true}, "ansible_loop_var": "item", "changed": false, "item": {"has_allow_nvdp": true, "has_gpu_present": true, "name": "node1"}}

TASK [gpu : Install NVIDIA Device Plugin] **************************************************************************************
[WARNING]: The default idempotency check can fail to report changes in certain cases. Install helm diff >= 3.4.1 for better
results.
ok: [server1] => {"changed": false, "command": "/usr/local/bin/helm --version=0.16.2", "status": {"app_version": "0.16.2", "chart": "nvidia-device-plugin-0.16.2", "name": "nvdp", "namespace": "nvidia-device-plugin", "revision": "1", "status": "deployed", "updated": "2025-02-27 05:47:34.309110329 +0000 UTC", "values": {"deviceListStrategy": "volume-mounts", "nodeSelector": {"allow-nvdp": "true"}, "runtimeClassName": "nvidia"}}, "stderr": "", "stderr_lines": [], "stdout": "", "stdout_lines": []}

PLAY RECAP *********************************************************************************************************************
server1            : ok=10   changed=1    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0
```
