"""Language Model (LM) endpoints for text generation."""

import tempfile
from flask import Blueprint, request, Response, stream_with_context, jsonify
from services.lm_service import LMService
from services.stt_service import STTService
from services.catalog_service import CatalogService
import models.device_model as registry_module

bp = Blueprint("lm", __name__)

# Initialize services
lm_service = LMService()
stt_service = STTService()
catalog_service = CatalogService()


@bp.post("/lm/generate")
def generate():
    """Generate text using LM only (no STT).
    
    Request body (JSON):
        {
            "prompt": str,
            "model_name": str (optional),
            "stream": bool (optional, default: false)
        }
    """
    data = request.get_json() or {}
    prompt = data.get("prompt")
    model_name = data.get("model_name")
    stream = data.get("stream", False)
    
    if not prompt:
        return jsonify({"error": "Missing 'prompt' field"}), 400
    
    try:
        # Resolve model identifier
        model_identifier = catalog_service.resolve_lm_model(model_name)
        
        if stream:
            # Stream response using SSE
            def generate_stream():
                try:
                    response = lm_service.generate_content(
                        prompt=prompt,
                        model_identifier=model_identifier,
                        stream=True
                    )
                    for chunk in response:
                        if chunk.text:
                            yield f"data: {chunk.text}\n\n"
                    yield "data: [DONE]\n\n"
                except Exception as e:
                    yield f"data: [ERROR: {str(e)}]\n\n"
            
            return Response(
                stream_with_context(generate_stream()),
                mimetype="text/event-stream"
            )
        else:
            # Return complete response
            response = lm_service.generate_content(
                prompt=prompt,
                model_identifier=model_identifier,
                stream=False
            )
            
            return jsonify({
                "status": "success",
                "text": response.text
            }), 200
    
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@bp.post("/echo")
def echo():
    """Echo endpoint for testing."""
    data = request.get_json() or {}
    return jsonify({
        "status": "success",
        "echo": data
    }), 200


@bp.post("/stt/transcribe")
def transcribe():
    """Transcribe audio only (no LM generation).
    
    Form data (multipart/form-data):
        audio: file (required)
        stt_model_name: str (optional, default: 'base')
        language: str (optional, e.g., 'en')
    
    Headers:
        X-Device-MAC: str (optional, for device tracking)
    
    Returns:
        JSON with transcription text
    """
    audio_file = request.files.get('audio')
    if not audio_file:
        return jsonify({"error": "Missing 'audio' file"}), 400
    
    stt_model_name = request.form.get('stt_model_name', 'base')
    language = request.form.get('language')
    source_mac = request.headers.get('X-Device-MAC')
    
    # Track device activity
    if source_mac:
        registry_module.device_registry.update_last_seen(source_mac)
        print(f"[TRANSCRIBE] Updated activity for device: {source_mac}")
    
    try:
        print(f"[TRANSCRIBE] Audio upload received")
        print(f"[TRANSCRIBE] Model: {stt_model_name}")
        
        # Save audio to temporary file
        with tempfile.NamedTemporaryFile(delete=False, suffix='.wav') as tmp_file:
            audio_file.save(tmp_file.name)
            tmp_path = tmp_file.name
        
        print(f"[TRANSCRIBE] Audio saved to: {tmp_path}")
        
        # Transcribe audio
        print(f"[TRANSCRIBE] Starting transcription...")
        transcription = stt_service.transcribe_audio(
            audio_file_path=tmp_path,
            model_name=stt_model_name,
            language=language
        )
        
        print(f"[TRANSCRIBE] Transcription: '{transcription[:100]}...'")
        
        # Clean up temp file
        import os
        os.remove(tmp_path)
        
        if not transcription.strip():
            return jsonify({"error": "Empty transcription"}), 400
        
        return jsonify({
            "status": "success",
            "transcription": transcription
        }), 200
    
    except Exception as e:
        print(f"[TRANSCRIBE] Error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@bp.post("/ai/process")
def process():
    """Unified endpoint: Transcribe audio (if provided) + Generate text with LM.
    
    Supports both:
    - Audio file upload (multipart/form-data)
    - Direct text prompt (application/json)
    
    Form data (multipart/form-data):
        audio: file (required for audio mode)
        prompt: str (optional, added after transcription)
        stt_model_name: str (optional)
        lm_model_name: str (optional)
        language: str (optional, e.g., 'en')
        stream: bool (optional, default: false)
    
    JSON data (application/json):
        prompt: str (required)
        lm_model_name: str (optional)
        stream: bool (optional, default: false)
    """
    content_type = request.content_type
    
    # Audio processing mode
    if content_type and 'multipart/form-data' in content_type:
        audio_file = request.files.get('audio')
        if not audio_file:
            return jsonify({"error": "Missing 'audio' file"}), 400
        
        prompt_suffix = request.form.get('prompt', '')
        stt_model_name = request.form.get('stt_model_name', 'base')
        lm_model_name = request.form.get('lm_model_name')
        language = request.form.get('language')
        stream = request.form.get('stream', 'false').lower() == 'true'
        
        try:
            print(f"[PROCESS] Audio upload received")
            print(f"[PROCESS] Form data: stt_model_name={stt_model_name}, lm_model_name={lm_model_name}, stream={stream}")
            
            # Save audio to temporary file
            with tempfile.NamedTemporaryFile(delete=False, suffix='.wav') as tmp_file:
                audio_file.save(tmp_file.name)
                tmp_path = tmp_file.name
            
            print(f"[PROCESS] Audio saved to: {tmp_path}")
            
            # Transcribe audio
            print(f"[PROCESS] Starting transcription with model: {stt_model_name}")
            transcription = stt_service.transcribe_audio(
                audio_file_path=tmp_path,
                model_name=stt_model_name,
                language=language
            )
            
            print(f"[PROCESS] Transcription complete: '{transcription[:100]}...'")
            
            # Clean up temp file
            import os
            os.remove(tmp_path)
            
            # Build final prompt
            if prompt_suffix:
                final_prompt = f"{transcription}\n\n{prompt_suffix}"
            else:
                final_prompt = transcription
            
            if not final_prompt.strip():
                print(f"[PROCESS] Empty transcription!")
                return jsonify({"error": "Empty transcription"}), 400
            
            print(f"[PROCESS] Final prompt for LM: '{final_prompt[:100]}...'")
            
            # Generate response with LM
            model_identifier = catalog_service.resolve_lm_model(lm_model_name)
            print(f"[PROCESS] Resolved LM model: {model_identifier}")
            
            if stream:
                print(f"[PROCESS] Starting SSE stream...")
                
                # Stream response with proper SSE event format
                def generate_stream():
                    import json
                    try:
                        print(f"[PROCESS] → Sending status: transcribing")
                        # Send status event
                        yield f"event: status\ndata: {json.dumps({'status': 'transcribing'})}\n\n"
                        
                        print(f"[PROCESS] → Sending transcription: {transcription[:50]}...")
                        # Send transcription event
                        yield f"event: status\ndata: {json.dumps({'status': 'generating', 'transcription': transcription})}\n\n"
                        
                        print(f"[PROCESS] → Starting LM generation...")
                        # Stream LM response chunks
                        response = lm_service.generate_content(
                            prompt=final_prompt,
                            model_identifier=model_identifier,
                            stream=True
                        )
                        
                        chunk_count = 0
                        for chunk in response:
                            if chunk.text:
                                chunk_count += 1
                                if chunk_count <= 3:  # Log first 3 chunks
                                    print(f"[PROCESS] → Chunk {chunk_count}: '{chunk.text[:50]}...'")
                                yield f"event: data\ndata: {json.dumps({'chunk': chunk.text})}\n\n"
                        
                        print(f"[PROCESS] → Sent {chunk_count} chunks total")
                        print(f"[PROCESS] → Sending done event")
                        # Send done event
                        yield f"event: done\ndata: {json.dumps({'status': 'complete'})}\n\n"
                        print(f"[PROCESS] Stream complete!")
                    except Exception as e:
                        print(f"[PROCESS] Stream error: {e}")
                        import traceback
                        traceback.print_exc()
                        yield f"event: error\ndata: {json.dumps({'error': str(e)})}\n\n"
                
                return Response(
                    stream_with_context(generate_stream()),
                    mimetype="text/event-stream"
                )
            else:
                # Return complete response
                response = lm_service.generate_content(
                    prompt=final_prompt,
                    model_identifier=model_identifier,
                    stream=False
                )
                
                return jsonify({
                    "status": "success",
                    "transcription": transcription,
                    "text": response.text
                }), 200
        
        except Exception as e:
            return jsonify({"error": str(e)}), 500
    
    # Text-only mode
    else:
        data = request.get_json() or {}
        prompt = data.get("prompt")
        lm_model_name = data.get("lm_model_name")
        stream = data.get("stream", False)
        
        if not prompt:
            return jsonify({"error": "Missing 'prompt' field"}), 400
        
        try:
            model_identifier = catalog_service.resolve_lm_model(lm_model_name)
            
            if stream:
                # Stream response
                def generate_stream():
                    try:
                        response = lm_service.generate_content(
                            prompt=prompt,
                            model_identifier=model_identifier,
                            stream=True
                        )
                        for chunk in response:
                            if chunk.text:
                                yield f"data: {chunk.text}\n\n"
                        yield "data: [DONE]\n\n"
                    except Exception as e:
                        yield f"data: [ERROR: {str(e)}]\n\n"
                
                return Response(
                    stream_with_context(generate_stream()),
                    mimetype="text/event-stream"
                )
            else:
                # Return complete response
                response = lm_service.generate_content(
                    prompt=prompt,
                    model_identifier=model_identifier,
                    stream=False
                )
                
                return jsonify({
                    "status": "success",
                    "text": response.text
                }), 200
        
        except Exception as e:
            return jsonify({"error": str(e)}), 500
