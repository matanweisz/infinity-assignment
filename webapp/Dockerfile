# Dockerfile for my Node.js web application with Vault secret as a build argument

# Build stage
# Node.js Alpine image for minimal size
FROM node:24-alpine AS builder

WORKDIR /app

# Copy the package.json file and install dependencies 
COPY package.json ./
RUN npm install --production

# Runtime stage
# Node.js Alpine image for minimal size
FROM node:24-alpine AS runtime

WORKDIR /app

# Copy dependencies from builder stage
COPY --from=builder /app/node_modules ./node_modules

# Copy application code
COPY src/* ./

# Accept the Vault secret as a build argument
ARG ASSIGNMENT_SECRET

# Fail the build if the secret is missing
RUN test -n "$ASSIGNMENT_SECRET" || (echo "Build Failed: Missing the ASSIGNMENT_SECRET" && exit 1)

# Set the secret as an environment variable in the image
ENV ASSIGNMENT_SECRET=$ASSIGNMENT_SECRET

# Expose the application port
EXPOSE 3000

# Start the application
CMD ["npm", "start"]
