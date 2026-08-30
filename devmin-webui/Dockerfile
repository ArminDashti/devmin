# syntax=docker/dockerfile:1
# Build from repo root: docker build -t pc-armin/devmin-webui:latest .

FROM node:22-alpine AS build
WORKDIR /src
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=build /src/dist /usr/share/nginx/html
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
ENV API_HOST=devmin-api
ENV API_PORT=8195
EXPOSE 80
