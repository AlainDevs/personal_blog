# Stage 1: Build the Dart server
FROM dart:stable AS build-dart

WORKDIR /app

# Copy and get Dart dependencies
COPY pubspec.* ./
RUN dart pub get

# Copy the rest of the application source code.
COPY . .

# Compile the Dart server
RUN dart compile exe lib/server.dart -o /app/server

# Stage 2: Build the CSS
FROM node:20 AS build-css

WORKDIR /app

# Copy package.json and install Node.js dependencies
COPY package*.json ./
RUN npm install

# Copy the rest of the web files and tailwind config
COPY web/ ./web/
COPY tailwind.config.js ./

# Build the CSS
RUN npm run build:css

# Stage 3: Final image
FROM debian:bullseye-slim

WORKDIR /app

# Copy the compiled server from the Dart build stage
COPY --from=build-dart /app/server /app/server

# Copy the built CSS and other web assets from the CSS build stage
COPY --from=build-css /app/web/ /app/web/

# Expose the port the server will listen on.
EXPOSE 8080

# Set the entry point to run the server.
ENTRYPOINT ["/app/server"]