ARG BUILDPLATFORM=linux/amd64
FROM --platform=$BUILDPLATFORM ruby:2.6.10-alpine
WORKDIR /app

RUN apk update && apk add bash sudo make --no-cache

COPY . .
