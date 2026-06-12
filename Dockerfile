FROM postgres:latest

RUN apt-get update && apt-get install -y bash && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY *.sql ./

CMD ["bash", "start.sh"]
