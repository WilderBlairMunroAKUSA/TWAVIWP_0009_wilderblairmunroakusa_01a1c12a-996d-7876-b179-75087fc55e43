python3 - <<'PY'
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler

class Quiet(SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

ThreadingHTTPServer(("", 8765), Quiet).serve_forever()
PY
