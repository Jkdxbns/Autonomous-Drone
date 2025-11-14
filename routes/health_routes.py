"""Health and catalog endpoints."""

from flask import Blueprint, jsonify
from services.catalog_service import CatalogService

bp = Blueprint("health", __name__)

# Initialize catalog service
catalog_service = CatalogService()


@bp.get("/catalog")
def catalog():
    """Return the model catalog with status wrapper."""
    catalog_data = catalog_service.get_catalog_for_app()
    return jsonify({"status": "success", "data": catalog_data}), 200


@bp.get("/health")
def health():
    """Health check endpoint."""
    return jsonify(status="ok"), 200
