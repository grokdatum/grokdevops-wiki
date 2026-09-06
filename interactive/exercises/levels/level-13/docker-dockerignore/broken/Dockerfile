FROM node:18-slim
WORKDIR /app
COPY package.json .
RUN npm install
COPY node_modules/ ./node_modules/
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
