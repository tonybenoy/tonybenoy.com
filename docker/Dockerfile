FROM python:3.8.3-slim
RUN apt update -y


ADD ./src/requirements.txt /app/requirements.txt
RUN pip install -r /app/requirements.txt

COPY src/ /src
WORKDIR /src/

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "4000"]
