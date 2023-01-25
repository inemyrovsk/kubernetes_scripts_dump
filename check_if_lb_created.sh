function check_ingress {
	export LB_K8S="$(kubectl get ingress -n test-7 | awk '/swag-core/ {print $7}')"
	if [ "${#LB_K8S}" -gt 2 ]
	then
		echo "load balancer created"	
	else
		echo "waiting for load balancer to create"
		sleep 10
		check_ingress
	fi
}

check_ingress
