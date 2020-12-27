# tonybenoy.com

My wesite source code moved to starlette/fastapi.

## K3d setup
```
k3d cluster create  mycluster
```

```
kubectl create namespace tonybenoy
```

```
kubectl create namespace cert-manager
```

```
docker build -f docker/Dockerfile -t  website .
```

```
docker run  --net=host -p 4000:4000 -it website
```
