The rook-ceph installation playbook.

It will install the complete rook-ceph operator, the rook-ceph cluster and will do the finalizing tasks like labeling the storage class.

##HOW TO USE:
1. Install helm: `curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash`
2. run `./generate-rook-ceph-cluster-config.sh`
3. `cd ~/kubespray`
4. run the playbook using `ansible-playbook -i inventory/akash/hosts.yaml -b -v --private-key=~/.ssh/id_rsa cluster.yml -e 'host=all' -t rook-ceph`

