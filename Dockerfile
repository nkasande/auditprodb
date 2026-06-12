FROM node:20-alpine
WORKDIR /app
COPY . .
RUN npm install pg
COPY init.js init.js
ENTRYPOINT ["node", "init.js"]
