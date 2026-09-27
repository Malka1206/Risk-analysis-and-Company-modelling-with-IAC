FROM python:3.11-slim

RUN pip install --no-cache-dir paramiko==3.4.0

WORKDIR /app
COPY external/hospital/hospital_submit_sample.py external/hospital/hospital_fetch_result.py ./
COPY sample-data/ /samples/

CMD ["tail", "-f", "/dev/null"]
