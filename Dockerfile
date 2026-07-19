FROM python:3.11-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libgl1 \
        libglib2.0-0 \
        libsm6 \
        libxext6 \
        libxrender1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt pyproject.toml ./
RUN python -m pip install --no-cache-dir -r requirements.txt

COPY config ./config
COPY tests ./tests
COPY tools ./tools
COPY vision ./vision
COPY web_protocol ./web_protocol
COPY main.py README.md ./

EXPOSE 42420/udp 42421/udp

CMD ["python", "-m", "pytest"]