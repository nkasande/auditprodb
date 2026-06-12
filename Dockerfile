FROM postgres:latest

WORKDIR /app

COPY . .

RUN chmod +x start.sh

ENTRYPOINT ["/bin/bash", "start.sh"]
