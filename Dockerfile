FROM nginx:alpine

ARG FAULTY_RELEASE=false

COPY index.html /usr/share/nginx/html/index.html
COPY health.html /usr/share/nginx/html/health.html

# Deliberately introduce a fault when requested by Jenkins.
RUN if [ "$FAULTY_RELEASE" = "true" ]; then \
        rm -f /usr/share/nginx/html/health.html; \
    fi

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]