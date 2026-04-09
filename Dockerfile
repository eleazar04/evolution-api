# ==========================================
# ETAPA 1: BUILDER
# ==========================================
FROM node:20-alpine AS builder

WORKDIR /evolution

# 1. Copiar package.json
COPY package*.json ./

# 2. Instalar dependencias IGNORANDO el postinstall
RUN npm ci --ignore-scripts

# 3. Copiar TODO el proyecto (incluye .env, prisma, runWithProvider.js)
COPY . .

# 4. Generar Prisma usando el script dinámico de Evolution API
RUN node runWithProvider.js "npx prisma generate"

# 5. Compilar el proyecto
RUN npm run build

# ==========================================
# ETAPA 2: FINAL
# ==========================================
FROM node:20-alpine

WORKDIR /evolution

# Instalar dependencias del sistema
RUN apk update && apk add --no-cache tzdata ffmpeg bash openssl

# Copiar archivos desde el builder (mantuve tu estructura exacta)
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

# Ejecutar migraciones dinámicas y arrancar
CMD ["sh", "-c", "node runWithProvider.js 'npx prisma migrate deploy' && node dist/src/main.js"]
