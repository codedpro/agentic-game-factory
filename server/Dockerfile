# The server is stdlib-only Python, so this image needs no build step and no packages.
# slim, not alpine: alpine's musl makes hashlib.scrypt noticeably slower, and password
# hashing cost is the one thing here that is deliberately expensive.
FROM python:3.12-slim

# Run as a non-root user. The server takes untrusted input from the internet, so a
# container escape should not land on root.
RUN useradd --system --uid 10001 --create-home --home-dir /app appuser
WORKDIR /app

COPY --chown=appuser:appuser scoreboard.py accounts.py purchases.py bazaar.py ./

# The database and the secrets live on mounted volumes, never in the image layers —
# baking either in would ship credentials inside a distributable artifact.
ENV SCOREBOARD_DB=/data/scores.db \
    MYKET_KEY_FILE=/secrets/myket_access_key.txt \
    BAZAAR_OAUTH_FILE=/secrets/bazaar_oauth.json \
    PORT=3000 \
    PYTHONUNBUFFERED=1

USER appuser
EXPOSE 3000

# Uses the app's own liveness route, so the check fails if the HTTP layer is wedged
# rather than merely if the process is alive.
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD python3 -c "import urllib.request,sys; \
        sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:3000/healthz', \
        timeout=4).status==200 else 1)"

CMD ["python3", "scoreboard.py"]
