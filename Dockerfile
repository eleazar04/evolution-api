FROM node:24-alpine AS builder

RUN apk update && \
    apk add --no-cache git ffmpeg wget curl bash openssl

LABEL version="2.3.1" description="Api to control whatsapp features through http requests." 
LABEL maintainer="Davidson Gomes" git="https://github.com/DavidsonGomes"
LABEL contact="contato@evolution-api.com"

WORKDIR /evolution

FROM node:20-alpine

WORKDIR /app

# ==========================================
# ETAPA 1: BUILDER (Aquí falla)
# ==========================================
FROM node:20-alpine AS builder

WORKDIR /evolution

# 1. Copiar package.json
COPY package*.json ./

# 2. Copiar Prisma ANTES de instalar
COPY prisma ./prisma

# 3. Instalar SIN --silent para ver el error real
RUN npm ci

# 4. Generar Prisma
RUN npx prisma generate

# 5. Copiar todo el código fuente
COPY . .

# 6. Compilar el proyecto
RUN npm run build

# ==========================================
# ETAPA 2: FINAL (La que muestra tus logs)
# ==========================================
FROM node:20-alpine

WORKDIR /evolution

# Instalar dependencias necesarias en producción (ej. openssl)
RUN apk add --no-cache openssl

# Copiar archivos desde la etapa builder
COPY --from=builder /evolution/package*.json ./
COPY --from=builder /evolution/prisma ./prisma
COPY --from=builder /evolution/dist ./dist
COPY --from=builder /evolution/node_modules ./node_modules
COPY --from=builder /evolution/public ./public
COPY --from=builder /evolution/.env ./.env
COPY --from=builder /evolution/Docker ./Docker
COPY --from=builder /evolution/tsup.config.ts ./tsup.config.ts
COPY --from=builder /evolution/runWithProvider.js ./runWithProvider.js
COPY --from=builder /evolution/manager ./manager

# Ejecutar migraciones y arrancar
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/src/main.js"]

COPY ./src ./src
COPY ./public ./public
COPY ./prisma ./prisma
COPY ./manager ./manager
COPY ./.env.example ./.env
COPY ./runWithProvider.js ./

COPY ./Docker ./Docker

RUN chmod +x ./Docker/scripts/* && dos2unix ./Docker/scripts/*

RUN ./Docker/scripts/generate_database.sh

RUN npm run build

FROM node:24-alpine AS final

RUN apk update && \
    apk add tzdata ffmpeg bash openssl

ENV TZ=America/Sao_Paulo
ENV DOCKER_ENV=true

WORKDIR /evolution

COPY --from=builder /evolution/package.json ./package.json
COPY --from=builder /evolution/package-lock.json ./package-lock.json

COPY --from=builder /evolution/node_modules ./node_modules
COPY --from=builder /evolution/dist ./dist
COPY --from=builder /evolution/prisma ./prisma
COPY --from=builder /evolution/manager ./manager
COPY --from=builder /evolution/public ./public
COPY --from=builder /evolution/.env ./.env
COPY --from=builder /evolution/Docker ./Docker
COPY --from=builder /evolution/runWithProvider.js ./runWithProvider.js
COPY --from=builder /evolution/tsup.config.ts ./tsup.config.ts

ENV DOCKER_ENV=true

EXPOSE 8080

ENTRYPOINT ["/bin/bash", "-c", ". ./Docker/scripts/deploy_database.sh && npm run start:prod" ]
