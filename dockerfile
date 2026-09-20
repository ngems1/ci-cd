FROM node:20-alpine AS build
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force
COPY . .

FROM node:20-alpine AS production
ENV NODE_ENV=production
WORKDIR /usr/src/app
COPY --from=build /usr/src/app ./
USER node
EXPOSE 8080
CMD [ "node", "server.js" ]