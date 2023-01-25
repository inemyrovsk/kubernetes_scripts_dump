export ENV_NAME=test-its-k8s
LB_K8S="$(kubectl get ingress -n test-8 | awk '/swag-core/ {print $7}')"
RECORD_NAME_AWS="$(aws route53 list-resource-record-sets --hosted-zone-id Z3M1YF5ZWG1EBI --query "ResourceRecordSets[?Name == '${ENV_NAME}.swag.com.'].ResourceRecords[0].Value" --output text)"
echo $LB_K8S
echo $RECORD_NAME_AWS

if [ "${LB_K8S}" = "${RECORD_NAME_AWS}i" ] 
then
  echo "records are equals"
else
    declare -a DOMAINS=(
                       "${ENV_NAME}"
                       "${ENV_NAME}-postal"
                       "${ENV_NAME}-sendoso"
                       )
    for DOMAIN in DOMAINS
    do
        aws route53 change-resource-record-sets --hosted-zone-id Z3M1YF5ZWG1EBI --output text --change-batch '{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"${DOMAIN}.swag.com","Type":"CNAME","TTL":300,"ResourceRecords":[{"Value":"${LB_K8S}"}]}}]}'
    done
fi
