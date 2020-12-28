FROM python:latest
RUN apt update -y
RUN apt upgrade -y

ADD ./src/requirements.txt /app/requirements.txt
RUN pip install -r /app/requirements.txt

COPY src/ /src
# WORKDIR /src/

CMD ["gunicorn", "-b 0.0.0.0:8000","src.main:app", "-w 1", "-k uvicorn.workers.UvicornWorker", "--preload"]
