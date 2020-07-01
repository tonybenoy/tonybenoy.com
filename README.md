# tonybenoy.com

My wesite source code

```
docker build -f ./docker/. -t website .
```

```
docker run  --net=host -p 80:80 -it website
```
