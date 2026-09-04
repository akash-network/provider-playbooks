# GPU role

This role installs NVIDIA GPU Operator on clean Ubuntu 24.04 GPU nodes. It does
not install host drivers, the host Container Toolkit, or the standalone NVIDIA
device plugin.

Defaults are centralized in `versions.yml`. The setup wizard identifies NVIDIA
devices by PCI vendor/product ID using a pinned Akash `provider-configs`
database and enables Fabric Manager automatically when a detected profile uses
an SXM interface. Helm returns after accepting the release; GPU driver and
runtime reconciliation continues asynchronously. Existing providers using host
drivers must follow the GPU Operator migration guide before running this role.
