FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY modbus_device.py .

EXPOSE 502

CMD ["python", "modbus_device.py"]
