"""
BioLab Analytics - compute node (Description.md section 3.1)

Real, functional (simplified) genomic analysis pipeline:
  - POST /analyze with a FASTA-like file + a "barcode" field
  - Computes sequence length, GC content, and a deterministic mock
    variant-detection pass (NOT real bioinformatics -- a toy pipeline,
    but the input->processing->output flow is genuinely executed).
  - Automatically uploads the raw result file to MinIO under the SAME
    barcode -- no patient identity ever transits through this service,
    only the barcode (see Plan_Maquette.txt section 0, step 4).

Deliberate weakness (documented in Description.md section 3.2 / 6.4):
  MinIO now serves HTTPS with a real certificate signed by BioLab's
  internal CA (see pki/). This service DELIBERATELY disables certificate
  verification anyway (boto3 client instantiated with verify=False) -- a
  concrete, documented inconsistency in the internal PKI: the cert exists
  and is valid, but this particular code path doesn't check it.
"""

import hashlib
import io
import json
import os
import uuid
from datetime import datetime, timezone

import boto3
from botocore.client import Config
from flask import Flask, jsonify, request

app = Flask(__name__)

MINIO_ENDPOINT = os.environ.get("MINIO_ENDPOINT", "https://minio:9000")
MINIO_ACCESS_KEY = os.environ.get("MINIO_ACCESS_KEY", "minioadmin")
MINIO_SECRET_KEY = os.environ.get("MINIO_SECRET_KEY", "minioadmin123")
MINIO_BUCKET = os.environ.get("MINIO_BUCKET", "raw-results")

# Deliberate weakness: certificate verification disabled on this flow.
# See module docstring above / Description.md section 6.4.
VERIFY_TLS = False


def s3_client():
    return boto3.client(
        "s3",
        endpoint_url=MINIO_ENDPOINT,
        aws_access_key_id=MINIO_ACCESS_KEY,
        aws_secret_access_key=MINIO_SECRET_KEY,
        config=Config(signature_version="s3v4"),
        verify=VERIFY_TLS,
    )


def parse_fasta(raw_text: str):
    """Very small, dependency-free FASTA parser."""
    header = None
    sequence_parts = []
    for line in raw_text.splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith(">"):
            header = line[1:].strip()
        else:
            sequence_parts.append(line.upper())
    sequence = "".join(sequence_parts)
    return header, sequence


def analyze_sequence(sequence: str, barcode: str) -> dict:
    length = len(sequence)
    gc_count = sequence.count("G") + sequence.count("C")
    gc_content = round((gc_count / length) * 100, 2) if length else 0.0

    # Deterministic "mock variant calling": not real bioinformatics, but a
    # reproducible, non-random output derived from the sequence content, so
    # the same input always yields the same demo result.
    digest = hashlib.sha256((barcode + sequence).encode("utf-8")).hexdigest()
    mock_variant_count = int(digest[:4], 16) % 12  # 0-11, deterministic

    return {
        "barcode": barcode,
        "sequence_length": length,
        "gc_content_percent": gc_content,
        "mock_variants_detected": mock_variant_count,
        "analysis_id": str(uuid.uuid4()),
        "analyzed_at": datetime.now(timezone.utc).isoformat(),
        "pipeline": "biolab-toy-pipeline-v1",
    }


@app.route("/health", methods=["GET"])
def health():
    return jsonify(status="ok")


@app.route("/analyze", methods=["POST"])
def analyze():
    barcode = request.form.get("barcode")
    if not barcode:
        return jsonify(error="missing 'barcode' form field"), 400

    if "file" not in request.files:
        return jsonify(error="missing 'file' upload"), 400

    uploaded = request.files["file"]
    raw_text = uploaded.read().decode("utf-8", errors="replace")

    header, sequence = parse_fasta(raw_text)
    if not sequence:
        return jsonify(error="no sequence data found in uploaded file"), 400

    result = analyze_sequence(sequence, barcode)
    result["source_header"] = header

    result_bytes = json.dumps(result, indent=2).encode("utf-8")
    object_key = f"{barcode}.json"

    client = s3_client()
    client.put_object(
        Bucket=MINIO_BUCKET,
        Key=object_key,
        Body=io.BytesIO(result_bytes),
        ContentType="application/json",
    )

    return jsonify(
        status="stored",
        bucket=MINIO_BUCKET,
        object_key=object_key,
        result=result,
    ), 201


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
