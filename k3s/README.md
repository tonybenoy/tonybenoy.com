docker build -f docker/Dockerfile -t fastapi-image .

docker volume create local_registry
docker container run -d --name registry.localhost -v local_registry:/var/lib/registry --restart always -p 5000:5000 registry:2


docker image tag fastapi-image:latest registry.localhost:5000/tonybenoy:latest
docker push registry.localhost:5000/tonybenoy:latest

k3d cluster create  --volume $HOME/.k3d/registries.yaml:/etc/rancher/k3s/registries.yaml tonybenoy -p "80:80@loadbalancer" -p "443:443@loadbalancer"


kubectl create namespace cert-manager


 kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.1.0/cert-manager.yaml

docker network connect k3d-tonybenoy registry.localhost

kubectl apply -f lets-encrypt.yaml

kubectl describe clusterissuer letsencrypt

kubectl create namespace tonybenoy

kubectl apply -f fastapi.yaml
kubectl apply -f ingress.yaml