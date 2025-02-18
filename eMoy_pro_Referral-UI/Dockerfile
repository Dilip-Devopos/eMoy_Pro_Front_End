# Use the official NGINX image
FROM nginx:alpine

# Set the working directory
WORKDIR /usr/share/nginx/html

# Remove the default NGINX static files
RUN rm -rf ./*

# Copy the Flutter build output to NGINX web root
COPY /web /usr/share/nginx/html

# Expose port 80 for NGINX
EXPOSE 80

# Start NGINX
CMD ["nginx", "-g", "daemon off;"]
