# tonybenoy.com

My wesite source code moved to starlette/fastapi.

```
docker build -f docker/Dockerfile -t  website .
```

```
docker run  --net=host -p 8000:8000 -it website
```
