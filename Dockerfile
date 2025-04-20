# Stage 1: Build frontend
FROM node:latest AS build-js

RUN npm install gulp gulp-cli -g

WORKDIR /build
COPY . .
RUN npm install --include=dev
RUN gulp


# Stage 2: Build backend
FROM golang:1.15.2 AS build-golang

WORKDIR /app
COPY . .
RUN go get -v && go build -o gophish .


# Final stage: Runtime container
FROM debian:stable-slim

# Install needed packages
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        golang \
        gcc \
        g++ \
        libc6-dev \
        libsqlite3-dev \
        pkg-config \
        make \
        jq \
        libcap2-bin \
        ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /opt/gophish

# Copy full source code and build Gophish in-place (solves exec issue)
COPY . .
RUN go build -o gophish .
RUN chmod +x gophish

# Copy UI assets
COPY --from=build-js /build/static/js/dist/ ./static/js/dist/
COPY --from=build-js /build/static/css/dist/ ./static/css/dist/
COPY --from=build-golang /go/src/github.com/gophish/gophish/config.json ./
RUN chown app:app config.json

RUN setcap 'cap_net_bind_service=+ep' /opt/gophish/gophish

USER root

RUN sed -i 's/127.0.0.1/0.0.0.0/g' config.json

EXPOSE 8080 8081

CMD ["./gophish"]
