#!/bin/sh

docker-compose up -d

for nw in 0 1 2 3; do
	nw_cidr=$(docker network inspect -f '{{ (index .IPAM.Config 0).Subnet }}' \
		nwtest_nw${nw})
	if_cidr=$(docker exec -it nwtest_server_1 ip addr show eth${nw} |
		awk '$1 == "inet" {print $2}')

	nw_net=$(ipcalc -n $nw_cidr | cut -f2 -d=)
	if_net=$(ipcalc -n $if_cidr | cut -f2 -d=)

	echo "nw${nw} $nw_net eth${nw} ${if_net}"

	if [ "$if_net" != "$nw_net" ]; then
		echo "MISMATCH: nw${nw} = $nw_net, eth${nw} = $if_net" >&2
	fi
done

docker-compose stop
