FROM postgres
ENV POSTGRES_PASSWORD 12345
ENV POSTGRES_DB transactions
COPY structure.sql /docker-entrypoint-initdb.d/
