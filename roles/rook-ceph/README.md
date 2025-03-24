The rook-ceph installation playbook.

It will install the complete rook-ceph operator, the rook-ceph cluster and will do the finalizing tasks like labeling the stora class.

##HOW TO USE:
1. run ceph-questionnaire.sh
2. run generate-rook-ceph-config-from-template.sh
3. create the inventory file that will be used to build the rook-ceph cluster. An example inventory file is included.
4. run the playbook using `ansible-playbook -i inventory rook-ceph-playbook.yml`. If you want to run any of the components manually you can do this by running `ansible-playbook -i inventory rook-ceph-playbook.yml --tags rook-ceph-finalize
 --tags rook-ceph-finalize` to just run the finalizers.

