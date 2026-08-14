# ==========================================
# Dockerfile for React JS Zomato Clone
# ==========================================
# Architecture: Multi-Stage Build
# Instructor: SRINIVAS
# ==========================================

# ------------------------------------------
# STAGE 1: The Builder Environment
# ------------------------------------------
# Use Node 18 Alpine as the base image for building the application
FROM node:18-alpine AS builder

# Set the working directory inside the container
WORKDIR /app

# Copy only the package files first to leverage Docker layer caching
COPY package*.json ./

# Install dependencies strictly from package-lock.json for consistent builds
# We use 'npm ci' (Clean Install) instead of 'npm install' for reliable CI/CD pipelines
RUN npm ci

# Copy the rest of the application source code into the container
COPY . .

# IMPORTANT FIX: Bypass the ESLint dependency conflict in Create React App
ENV SKIP_PREFLIGHT_CHECK=true

# IMPORTANT FIX: Enable legacy OpenSSL algorithms for older Webpack compatibility in Node 18+
ENV NODE_OPTIONS=--openssl-legacy-provider

# Compile the React application into optimized, static production files
# This creates a 'build' (or 'dist') directory containing the final assets
RUN npm run build


# ------------------------------------------
# STAGE 2: The Production Environment
# ------------------------------------------
# Use a lightweight Nginx Alpine image to serve the static content
FROM nginx:alpine

# Remove the default Nginx index page and static assets
RUN rm -rf /usr/share/nginx/html/*

# Copy ONLY the optimized static files from Stage 1 into the Nginx web root
# We leave behind the source code, node_modules, and the Node runtime entirely!
COPY --from=builder /app/build /usr/share/nginx/html

# Expose port 80 (Standard HTTP port for Nginx)
EXPOSE 80

# Start the Nginx server and keep it running in the foreground
CMD ["nginx", "-g", "daemon off;"]
