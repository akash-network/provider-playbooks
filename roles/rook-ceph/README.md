The rook-ceph installation playbook.

It will install the complete rook-ceph operator, the rook-ceph cluster and will do the finalizing tasks like labeling the stora class.

##HOW TO USE:
1. Install helm: `curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash`
2. `mkdir -p ~/kubespray/roles/rook-ceph
3. copy the contents of this directory into ~/kubespray/roles/rook-ceph
4. `cp ~/kubespray/roles/rook-ceph/rook-ceph.yml ~/kubespray/`
5. `cp ~/kubespray/roles/rook-ceph/rook-ceph-playbook.yml ~/kubespray/`
6. `cd ~/kubespray/roles/rook-ceph`
7. run `./generate-rook-ceph-cluster-config.sh`
8. `cd ~/kubespray`
9. run the playbook using `ansible-playbook -i inventory/akash/hosts.yaml -b -v --private-key=~/.ssh/id_rsa rook-ceph.yml`

