# Deploy nginx 

kubectl create ns sidecar-cont-example

kubectl create -n sidecar-cont-example -f yaml/

# Check the init containers with kubectl describe

# Delete the namespace

kubectl delete ns sidecar-cont-example
