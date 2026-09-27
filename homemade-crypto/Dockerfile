FROM python:3.11-slim

# Fixed IDs matching sftp-server/entrypoint.sh, so this container can write
# into the shared /exchange/outbound directory (owned by biolab_admin:biolab-svc,
# mode 770) without needing root.
RUN groupadd -g 2000 biolab-svc && \
    useradd -u 1001 -g biolab-svc -m -s /usr/sbin/nologin biolab_admin

WORKDIR /app
COPY crypto_maison.py watcher.py ./

USER 1001:2000

CMD ["python", "watcher.py"]
