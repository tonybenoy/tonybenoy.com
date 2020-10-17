FROM python:latest
RUN apt update -y
RUN apt upgrade -y

ADD ./src/requirements.txt /app/requirements.txt
RUN pip install -r /app/requirements.txt

COPY src/ /src
# WORKDIR /src/

CMD ["gunicorn", "src.main:app", "-w 4", "-k uvicorn.workers.UvicornWorker", "--preload"]