# Minimal image for testing build → push → central sign flow.
FROM alpine:3.19
RUN echo "demo-image-sign-keyless" > /app.txt
CMD ["cat", "/app.txt"]
