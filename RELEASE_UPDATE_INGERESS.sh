  test_records:
    executor: python
    working_directory: << pipeline.parameters.workingdir >>
    parameters:
      ENV_NAME: { type: string }
    steps:
      - attach_workspace:
          at: << pipeline.parameters.workingdir >>
      - run:
          name: check DNS record
          command: |
            sudo apt update -y && sudo apt install -y gettext-base sed jq
            sudo pip install awscli --upgrade
            curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.21.2/2021-07-05/bin/linux/amd64/kubectl
            chmod +x ./kubectl
            sudo mv ./kubectl /usr/local/bin/kubectl
            export ENV_NAME=<< parameters.ENV_NAME >>
            echo $ENV_NAME
            aws eks --region $AWS_DEFAULT_REGION update-kubeconfig --name swag-test-k8s
            export ENV_NAME=<< parameters.ENV_NAME >>
            echo $ENV_NAME
            export LB_K8S="$(kubectl get ingress -n $ENV_NAME | awk '/swag-core/ {print $7}')"
            export RECORD_NAME_AWS_IP="$(aws route53 list-resource-record-sets --hosted-zone-id ${HOSTED_ZONE_ID} --query "ResourceRecordSets[?Name == '${ENV_NAME}.swag.com.'].ResourceRecords[0].Value" --output text)"
            export RECORD_NAME_AWS_ALIAS="$(aws route53 list-resource-record-sets --hosted-zone-id ${HOSTED_ZONE_ID} --query "ResourceRecordSets[?Name == '${ENV_NAME}.swag.com.'].AliasTarget.DNSName" --output text)"
            echo "lb_k8s:"
            echo $LB_K8S
            function check_ingress {
                if [ "${#LB_K8S}" -gt 6 ]
                then
                    echo "load balancer created"	
                else
                    echo "waiting for load balancer to create"
                    sleep 10
                    export LB_K8S="$(kubectl get ingress -n $ENV_NAME | awk '/swag-core/ {print $7}')"
                    check_ingress
                fi
            }
            
            check_ingress

            if [ "${LB_K8S}" = "${RECORD_NAME_AWS_IP}" ] || [ "${LB_K8S}" = "${RECORD_NAME_AWS_ALIAS}" ] 
            then
              echo "records are equals"
            else
                export DOMAINS=("${ENV_NAME}." "${ENV_NAME}-postal." "${ENV_NAME}-sendoso.")
                for DOMAIN in ${DOMAINS[@]}
                do
                    export DOMAIN=$DOMAIN
                    echo $DOMAIN
                    cp << pipeline.parameters.workingdir >>/.circleci/domain.json << pipeline.parameters.workingdir >>/.circleci/domain-${DOMAIN}.json
                    envsubst < ./.circleci/domain-${DOMAIN}.json > ./.circleci/domain-${DOMAIN}-upd.json
                    aws route53 change-resource-record-sets --hosted-zone-id ${HOSTED_ZONE_ID} --output text --change-batch file://<< pipeline.parameters.workingdir >>/.circleci/domain-${DOMAIN}-upd.json
                    echo "updated"
                done
            fi
