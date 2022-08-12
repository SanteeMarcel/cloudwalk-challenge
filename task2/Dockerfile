FROM python:latest

WORKDIR /app

COPY rate_limit.py /app

COPY transactions.json /app

CMD [ "python", "rate_limit.py"]
