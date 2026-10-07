FROM postgres

EXPOSE 5432

COPY init.sql /docker-entrypoint-initdb.d/init.sql

ENV POSTGRES_DB=microservices_db
ENV POSTGRES_USER=app
