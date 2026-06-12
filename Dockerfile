FROM postgres:latest

WORKDIR /app

COPY . .

ENTRYPOINT ["sh", "-c", "for f in $(ls -1 *.sql | sort); do psql -h $PGHOST -p $PGPORT -U $PGUSER -d $PGDATABASE -f $f || exit 1; done"]
