#!/bin/bash

dnf install python3.11-pip ansible -y | tee -a /opt/userdata.log
pip3.11 install botocore boto3 | tee -a /opt/userdata.log
ansible-pull -i localhost, -U https://github.com/yamunasreeoggu/infra_ansible main.yml -e role_name=${role_name} -e env=${env} | tee -a /opt/userdata.log
