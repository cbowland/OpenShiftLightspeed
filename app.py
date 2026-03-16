import json
import os
import time
from functools import wraps

from dotenv import load_dotenv
load_dotenv()

from flask import Flask, jsonify, render_template, request, abort, redirect, url_for
from prometheus_client import (
    Counter,
    Histogram,
    Gauge,
    generate_latest,
    CONTENT_TYPE_LATEST,
)

app = Flask(__name__)

# ---------------------------------------------------------------------------
# Configuration (injected via ConfigMap env vars)
# ---------------------------------------------------------------------------
CATALOG_TITLE = os.environ.get("CATALOG_TITLE", "Bowland Widget Catalog")
ITEMS_PER_PAGE = int(os.environ.get("ITEMS_PER_PAGE", "12"))
ENABLE_ADMIN = os.environ.get("ENABLE_ADMIN", "true").lower() == "true"
ADMIN_API_KEY = os.environ.get("ADMIN_API_KEY", os.urandom(32).hex())

# ---------------------------------------------------------------------------
# Prometheus metrics
# ---------------------------------------------------------------------------
REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status"],
)
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["method", "endpoint"],
)
WIDGETS_GAUGE = Gauge("widget_catalog_size", "Number of widgets in the catalog")

# ---------------------------------------------------------------------------
# In-memory widget store
# ---------------------------------------------------------------------------
_DEFAULT_WIDGETS = [
    {"id": 1, "name": "Sprocket A",      "category": "Sprockets",    "price": 4.99,   "description": "Standard steel sprocket, 12-tooth."},
    {"id": 2, "name": "Gear Assembly B",  "category": "Gears",        "price": 29.95,  "description": "Pre-assembled brass gear set for Model 7 line."},
    {"id": 3, "name": "Flanged Bearing",  "category": "Bearings",     "price": 12.50,  "description": "Self-aligning flanged bearing, rated to 5000 RPM."},
    {"id": 4, "name": "Rubber Gasket XL", "category": "Seals",        "price": 1.75,   "description": "High-temp silicone gasket for exhaust manifolds."},
    {"id": 5, "name": "Titanium Bolt M8", "category": "Fasteners",    "price": 0.89,   "description": "Grade-5 titanium hex bolt, M8x30mm."},
    {"id": 6, "name": "Control Valve V3", "category": "Valves",       "price": 74.00,  "description": "Pneumatic control valve with 4-20 mA interface."},
    {"id": 7, "name": "Carbon Brush Set", "category": "Electrical",   "price": 8.40,   "description": "Replacement carbon brushes for 3-phase motors."},
]


def _load_widgets():
    """Load widgets from a ConfigMap-mounted JSON file if available,
    otherwise fall back to the built-in defaults."""
    catalog_path = os.environ.get("WIDGET_CATALOG_PATH")
    if catalog_path and os.path.isfile(catalog_path):
        with open(catalog_path) as f:
            widgets = json.load(f)
        app.logger.info("Loaded %d widgets from %s", len(widgets), catalog_path)
        return widgets
    app.logger.info("No WIDGET_CATALOG_PATH set; using built-in defaults")
    return list(_DEFAULT_WIDGETS)


WIDGETS = _load_widgets()
_next_id = max((w["id"] for w in WIDGETS), default=0) + 1
WIDGETS_GAUGE.set(len(WIDGETS))


def _find_widget(widget_id):
    return next((w for w in WIDGETS if w["id"] == widget_id), None)


# ---------------------------------------------------------------------------
# Metrics middleware
# ---------------------------------------------------------------------------
def track_metrics(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        start = time.time()
        try:
            response = f(*args, **kwargs)
            status = response[1] if isinstance(response, tuple) else 200
        except Exception:
            status = 500
            raise
        finally:
            elapsed = time.time() - start
            REQUEST_COUNT.labels(request.method, request.path, status).inc()
            REQUEST_LATENCY.labels(request.method, request.path).observe(elapsed)
        return response
    return wrapper


# ---------------------------------------------------------------------------
# Health probes
# ---------------------------------------------------------------------------
@app.route("/healthz")
def healthz():
    return jsonify({"status": "ok"}), 200


@app.route("/readyz")
def readyz():
    return jsonify({"status": "ready"}), 200


# ---------------------------------------------------------------------------
# Prometheus metrics endpoint
# ---------------------------------------------------------------------------
@app.route("/metrics")
def metrics():
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}


# ---------------------------------------------------------------------------
# Web UI
# ---------------------------------------------------------------------------
@app.route("/")
@track_metrics
def index():
    page = request.args.get("page", 1, type=int)
    start = (page - 1) * ITEMS_PER_PAGE
    end = start + ITEMS_PER_PAGE
    page_widgets = WIDGETS[start:end]
    total_pages = max(1, -(-len(WIDGETS) // ITEMS_PER_PAGE))  # ceiling division
    return render_template(
        "index.html",
        widgets=page_widgets,
        title=CATALOG_TITLE,
        page=page,
        total_pages=total_pages,
        enable_admin=ENABLE_ADMIN,
    )


# ---------------------------------------------------------------------------
# Admin UI
# ---------------------------------------------------------------------------
@app.route("/admin")
@track_metrics
def admin():
    if not ENABLE_ADMIN:
        abort(403)
    return render_template(
        "admin.html",
        widgets=WIDGETS,
        title=CATALOG_TITLE,
        enable_admin=ENABLE_ADMIN,
    )


# ---------------------------------------------------------------------------
# REST API
# ---------------------------------------------------------------------------
@app.route("/api/widgets")
@track_metrics
def api_list_widgets():
    return jsonify(WIDGETS), 200


@app.route("/api/widgets/<int:widget_id>")
@track_metrics
def api_get_widget(widget_id):
    widget = _find_widget(widget_id)
    if widget is None:
        abort(404)
    return jsonify(widget), 200


@app.route("/api/widgets", methods=["POST"])
@track_metrics
def api_create_widget():
    global _next_id

    if not ENABLE_ADMIN:
        return jsonify({"error": "Admin API is disabled"}), 403

    key = request.headers.get("X-API-Key", "")
    if key != ADMIN_API_KEY:
        return jsonify({"error": "Invalid or missing API key"}), 401

    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "Request body must be JSON"}), 400

    for field in ("name", "category", "price", "description"):
        if field not in data:
            return jsonify({"error": f"Missing required field: {field}"}), 400

    widget = {
        "id": _next_id,
        "name": data["name"],
        "category": data["category"],
        "price": float(data["price"]),
        "description": data["description"],
    }
    _next_id += 1
    WIDGETS.append(widget)
    WIDGETS_GAUGE.set(len(WIDGETS))
    return jsonify(widget), 201


@app.route("/api/widgets/<int:widget_id>", methods=["PUT"])
@track_metrics
def api_update_widget(widget_id):
    if not ENABLE_ADMIN:
        return jsonify({"error": "Admin API is disabled"}), 403

    key = request.headers.get("X-API-Key", "")
    if key != ADMIN_API_KEY:
        return jsonify({"error": "Invalid or missing API key"}), 401

    widget = _find_widget(widget_id)
    if widget is None:
        return jsonify({"error": "Not found"}), 404

    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "Request body must be JSON"}), 400

    for field in ("name", "category", "price", "description"):
        if field in data:
            widget[field] = float(data[field]) if field == "price" else data[field]

    return jsonify(widget), 200


@app.route("/api/widgets/<int:widget_id>", methods=["DELETE"])
@track_metrics
def api_delete_widget(widget_id):
    if not ENABLE_ADMIN:
        return jsonify({"error": "Admin API is disabled"}), 403

    key = request.headers.get("X-API-Key", "")
    if key != ADMIN_API_KEY:
        return jsonify({"error": "Invalid or missing API key"}), 401

    widget = _find_widget(widget_id)
    if widget is None:
        return jsonify({"error": "Not found"}), 404

    WIDGETS.remove(widget)
    WIDGETS_GAUGE.set(len(WIDGETS))
    return jsonify({"status": "deleted"}), 200


# ---------------------------------------------------------------------------
# Error handlers
# ---------------------------------------------------------------------------
@app.errorhandler(404)
def not_found(_):
    return jsonify({"error": "Not found"}), 404


@app.errorhandler(500)
def server_error(_):
    return jsonify({"error": "Internal server error"}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=True)
