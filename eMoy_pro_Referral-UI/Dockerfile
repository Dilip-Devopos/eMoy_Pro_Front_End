FROM python:3.9-alpine

# Set the working directory
WORKDIR /app

# Copy Flutter web build files
COPY build/web /app

# Expose port 30008
EXPOSE 30008

# Start Python HTTP Server on port 30008
CMD ["python", "-m", "http.server", "30008"]
