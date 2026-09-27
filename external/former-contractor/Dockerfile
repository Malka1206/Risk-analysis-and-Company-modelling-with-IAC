FROM python:3.11-slim

RUN pip install --no-cache-dir paramiko==3.4.0

WORKDIR /app
COPY external/former-contractor/residual_access_demo.py .

CMD ["tail", "-f", "/dev/null"]
