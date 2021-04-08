SHELL=/bin/bash -o pipefail

events:
	kubectl -f apply events-generator/
	
pf-prometheus:
	kubectl -n prow-monitoring port-forward $$( kubectl -n prow-monitoring get pods --selector app=prometheus -o jsonpath={.items[0].metadata.name} ) 9090
