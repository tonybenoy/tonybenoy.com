# tonybenoy.com

My wesite source code moved to starlette/fastapi.

```
docker build -f ./docker/. -t website .
```

```
docker run  --net=host -p 80:80 -it website
```
