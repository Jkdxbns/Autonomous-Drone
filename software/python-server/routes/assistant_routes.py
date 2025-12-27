"""Assistant routes - handles two-pass LLM pipeline requests."""

from flask import Blueprint, request, jsonify, Response, stream_with_context
from services.assistant_service import AssistantService
from services.lm_service import LMService
import models.device_model as registry_module

bp = Blueprint('assistant', __name__)

# Initialize services (lazy initialization for assistant_service)
assistant_service = None
lm_service = LMService()


def get_assistant_service():
    """Get or create assistant service instance (lazy initialization)."""
    global assistant_service
    if assistant_service is None:
        assistant_service = AssistantService(registry_module.device_registry)
    return assistant_service


@bp.route('/lm/query', methods=['POST'])
def handle_assistant_request():
    """Main assistant endpoint - two-pass pipeline.
    
    Request body (JSON):
        {
            "user_query": str,
            "source_device_mac": str,
            "lm_model": str (optional)
        }
    
    Returns:
        For text-generation: SSE stream
        For bt-control: JSON response
    """
    try:
        data = request.get_json() or {}
        user_query = data.get('user_query')
        source_mac = data.get('source_device_mac')
        lm_model = data.get('lm_model')
        
        print("\n" + "="*80)
        print("[ASSISTANT] POST /lm/query called")
        print("="*80)
        print(f"[DEBUG] Request data:")
        print(f"  user_query: {user_query}")
        print(f"  source_device_mac: {source_mac}")
        print(f"  lm_model: {lm_model}")
        
        if not user_query:
            return jsonify({
                "status": "error",
                "error": {
                    "code": "MISSING_QUERY",
                    "message": "Missing 'user_query' field"
                }
            }), 400
        
        if not source_mac:
            return jsonify({
                "status": "error",
                "error": {
                    "code": "MISSING_SOURCE_MAC",
                    "message": "Missing 'source_device_mac' field"
                }
            }), 400
        
        # Call assistant service
        print(f"[ASSISTANT] Calling handle_request()...")
        result = get_assistant_service().handle_request(user_query, source_mac, lm_model)
        
        # Check if text-generation (streaming)
        if result.get('use_streaming'):
            print(f"[ASSISTANT] Streaming response for text-generation")
            print("="*80 + "\n")
            # Return SSE stream
            return stream_text_generation(result['user_query'], lm_model)
        
        # bt-control or error: Return JSON
        if result.get('status') == 'error':
            print(f"[ASSISTANT] Error result: {result}")
            print("="*80 + "\n")
            return jsonify(result), 500
        
        print(f"[ASSISTANT] Success result: {result.get('status')}")
        print("="*80 + "\n")
        return jsonify(result), 200
    
    except Exception as e:
        print(f"[ASSISTANT_ROUTES] Error: {e}")
        import traceback
        traceback.print_exc()
        print("="*80 + "\n")
        
        return jsonify({
            "status": "error",
            "error": {
                "code": "INTERNAL_ERROR",
                "message": str(e)
            }
        }), 500


def stream_text_generation(user_query: str, lm_model: str = None):
    """Stream text generation response using SSE.
    
    Args:
        user_query: User's question
        lm_model: Optional LM model identifier
    
    Returns:
        SSE stream response
    """
    def generate():
        try:
            import json
            from services.catalog_service import CatalogService
            
            catalog_service = CatalogService()
            model_identifier = catalog_service.resolve_lm_model(lm_model)
            
            print(f"[STREAMING] Resolved Gemini model: {model_identifier}")
            print(f"[STREAMING] User query: {user_query}")
            
            # Status event
            yield f"event: status\ndata: {json.dumps({'status': 'generating'})}\n\n"
            
            # Generate streaming response
            response = lm_service.generate_content(
                prompt=user_query,
                model_identifier=model_identifier,
                stream=True
            )
            
            chunk_count = 0
            for chunk in response:
                if chunk.text:
                    chunk_count += 1
                    yield f"event: data\ndata: {json.dumps({'chunk': chunk.text})}\n\n"
            
            print(f"[STREAMING] Completed - sent {chunk_count} chunks")
            
            # Done event
            yield f"event: done\ndata: {json.dumps({'status': 'complete'})}\n\n"
        
        except Exception as e:
            print(f"[STREAMING] Error: {e}")
            yield f"event: error\ndata: {json.dumps({'error': str(e)})}\n\n"
    
    return Response(stream_with_context(generate()), mimetype='text/event-stream')
