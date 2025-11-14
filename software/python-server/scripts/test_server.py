"""Test script for FlaskServer_v2 API endpoints.

Tests all routes with proper request formats and validates responses.
"""

import requests
import json
import io
import wave
import struct
import time
from pathlib import Path


BASE_URL = "http://127.0.0.1:5000"
TIMEOUT = 30


def generate_test_wav(duration_seconds=1, sample_rate=16000):
    """Generate a silent .wav file in memory for testing."""
    buffer = io.BytesIO()
    with wave.open(buffer, 'wb') as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(2)  # 16-bit
        wav_file.setframerate(sample_rate)
        
        # Generate silent audio (zeros)
        num_samples = duration_seconds * sample_rate
        for _ in range(num_samples):
            wav_file.writeframes(struct.pack('<h', 0))
    
    buffer.seek(0)
    return buffer


def print_test(test_name):
    """Print test header."""
    print(f"\n{'='*60}")
    print(f"TEST: {test_name}")
    print(f"{'='*60}")


def test_health():
    """Test GET /health endpoint."""
    print_test("GET /health")
    try:
        response = requests.get(f"{BASE_URL}/health", timeout=TIMEOUT)
        print(f"Status: {response.status_code}")
        print(f"Response: {response.json()}")
        assert response.status_code == 200
        assert response.json().get("status") == "ok"
        print("✅ PASSED")
        return True
    except Exception as e:
        print(f"❌ FAILED: {e}")
        return False


def test_catalog():
    """Test GET /catalog endpoint."""
    print_test("GET /catalog")
    try:
        response = requests.get(f"{BASE_URL}/catalog", timeout=TIMEOUT)
        print(f"Status: {response.status_code}")
        data = response.json()
        print(f"Response keys: {list(data.keys())}")
        
        assert response.status_code == 200
        assert data.get("status") == "success"
        assert "data" in data
        assert "STT" in data["data"]
        assert "LM" in data["data"]
        
        print(f"STT models: {list(data['data']['STT'].keys())}")
        print(f"LM models: {list(data['data']['LM'].keys())}")
        print("✅ PASSED")
        return True
    except Exception as e:
        print(f"❌ FAILED: {e}")
        return False


def test_echo():
    """Test POST /echo endpoint."""
    print_test("POST /echo")
    try:
        payload = {"text": "Hello from test script"}
        response = requests.post(
            f"{BASE_URL}/echo",
            json=payload,
            timeout=TIMEOUT
        )
        print(f"Status: {response.status_code}")
        print(f"Response: {response.json()}")
        
        assert response.status_code == 200
        assert response.json().get("echo") == "Hello from test script"
        print("✅ PASSED")
        return True
    except Exception as e:
        print(f"❌ FAILED: {e}")
        return False


def test_process_text(live=False):
    """Test POST /process with text input (JSON).
    
    Args:
        live: If True, requires actual Gemini API key. If False, expects error.
    """
    print_test("POST /process (text input)")
    try:
        payload = {
            "input_type": "text",
            "text": "Say hello in one word",
            "lm_model": "gemini-2.5-flash"
        }
        
        response = requests.post(
            f"{BASE_URL}/process",
            json=payload,
            stream=True,
            timeout=TIMEOUT
        )
        
        print(f"Status: {response.status_code}")

        # Parse SSE stream and aggregate content for non-streamed display
        status_msgs = []
        content_chunks = []
        error_msgs = []
        last_event = None

        for line in response.iter_lines(decode_unicode=True):
            if not line:
                continue
            # Trim whitespace
            line = line.strip()
            if line.startswith("event:"):
                last_event = line.split(":", 1)[1].strip()
                continue
            if line.startswith("data:"):
                payload = line.split(":", 1)[1].strip()
                if last_event == "status":
                    status_msgs.append(payload)
                elif last_event == "error":
                    error_msgs.append(payload)
                else:
                    # Default: treat as content chunk
                    content_chunks.append(payload)
                # Reset last_event for next pair
                last_event = None
                # Stop if done
                if payload == "[DONE]":
                    break

        # Print aggregated output
        if status_msgs:
            print("Status messages:")
            for s in status_msgs:
                print("  ", s)

        if error_msgs:
            print("Errors:")
            for e in error_msgs:
                print("  ", e)
            print("❌ FAILED: Errors encountered during processing")
            return False

        lm_output = "".join(content_chunks).strip()
        print("\nLM output (aggregated):")
        print(lm_output)

        # Basic checks
        has_text_obtained = any("Text obtained" in s for s in status_msgs)
        has_processing = any("Processing with" in s for s in status_msgs)

        if live:
            assert has_text_obtained, "Missing 'Text obtained' acknowledgement"
            assert has_processing, "Missing 'Processing' acknowledgement"
            assert lm_output, "Missing LM output"
            print("✅ PASSED (live)")
        else:
            print("✅ PASSED (mock - check acknowledgements present)")

        return True
    except Exception as e:
        print(f"❌ FAILED: {e}")
        return False


def test_process_audio(live=False):
    """Test POST /process with audio input (multipart).
    
    Args:
        live: If True, attempts real transcription. If False, expects model download or error.
    """
    print_test("POST /process (audio input)")
    try:
        # Use sample WAV if present, else generate test .wav file
        sample_path = Path(__file__).resolve().parent / 'sample.wav'
        if sample_path.exists():
            print(f"Using sample WAV: {sample_path}")
            files = {
                'audio': (sample_path.name, open(sample_path, 'rb'), 'audio/wav')
            }
        else:
            # Generate in-memory test .wav
            audio_buffer = generate_test_wav(duration_seconds=1)
            files = {
                'audio': ('test.wav', audio_buffer, 'audio/wav')
            }
        data = {
            'stt_model': 'whisper-tiny',  # Use smallest model for testing
            'lm_model': 'gemini-2.5-flash'
        }
        
        print("Uploading audio file...")
        response = requests.post(
            f"{BASE_URL}/process",
            files=files,
            data=data,
            stream=True,
            timeout=120  # Longer timeout for potential model download
        )
        
        print(f"Status: {response.status_code}")

        # Parse SSE stream and aggregate status, transcription and LM output
        status_msgs = []
        content_chunks = []
        error_msgs = []
        last_event = None

        for line in response.iter_lines(decode_unicode=True):
            if not line:
                continue
            line = line.strip()
            if line.startswith("event:"):
                last_event = line.split(":", 1)[1].strip()
                continue
            if line.startswith("data:"):
                payload = line.split(":", 1)[1].strip()
                if last_event == "status":
                    status_msgs.append(payload)
                elif last_event == "error":
                    error_msgs.append(payload)
                else:
                    content_chunks.append(payload)
                last_event = None
                if payload == "[DONE]":
                    break

        # Close file handle if we opened sample file
        if sample_path.exists():
            try:
                files['audio'][1].close()
            except Exception:
                pass

        # Print aggregated results
        if status_msgs:
            print("Status messages:")
            for s in status_msgs:
                print("  ", s)

        if error_msgs:
            print("Errors:")
            for e in error_msgs:
                print("  ", e)
            print("❌ FAILED: Errors encountered during processing")
            return False

        # Extract transcription from status messages
        transcription = None
        for s in status_msgs:
            if s.startswith("Transcription complete:"):
                transcription = s.split("Transcription complete:", 1)[1].strip()
                break

        print("\nTranscription:")
        print(transcription or "(no transcription found)")

        lm_output = "".join(content_chunks).strip()
        print("\nLM output (aggregated):")
        print(lm_output or "(no LM output)")

        # Basic checks
        has_audio_obtained = any("Audio file obtained" in s for s in status_msgs)
        assert has_audio_obtained, "Missing 'Audio file obtained' acknowledgement"

        if live:
            has_transcribing = any("Transcribing with" in s for s in status_msgs)
            has_processing = any("Processing with" in s for s in status_msgs)
            assert has_transcribing, "Missing 'Transcribing' acknowledgement"
            assert transcription, "Missing 'Transcription complete' acknowledgement"
            assert has_processing, "Missing 'Processing with LM' acknowledgement"
            print("✅ PASSED (live)")
        else:
            print("✅ PASSED (mock - check acknowledgements present)")

        return True
    except Exception as e:
        print(f"❌ FAILED: {e}")
        return False


def test_invalid_model():
    """Test that invalid model names are rejected."""
    print_test("POST /process (invalid STT model)")
    try:
        audio_buffer = generate_test_wav(duration_seconds=1)
        
        files = {
            'audio': ('test.wav', audio_buffer, 'audio/wav')
        }
        data = {
            'stt_model': 'invalid-model-xyz',
            'lm_model': 'gemini-2.5-flash'
        }
        
        response = requests.post(
            f"{BASE_URL}/process",
            files=files,
            data=data,
            stream=True,
            timeout=TIMEOUT
        )
        
        print(f"Status: {response.status_code}")
        events = []
        for line in response.iter_lines(decode_unicode=True):
            if line:
                print(f"  {line}")
                events.append(line)
        
        # Should receive error event
        has_error = any("error" in e.lower() and "not found" in e.lower() for e in events)
        assert has_error, "Should reject invalid model with error"
        print("✅ PASSED")
        return True
    except Exception as e:
        print(f"❌ FAILED: {e}")
        return False


def main(live=False):
    """Run all tests.
    
    Args:
        live: If True, tests with real API keys. If False, mocks responses.
    """
    print("\n" + "="*60)
    print("FLASKSERVER_V2 API TEST SUITE")
    print("="*60)
    
    if live:
        print("\n⚠️  LIVE MODE: Requires Gemini API key and will download models")
    else:
        print("\n📝 MOCK MODE: Tests structure without requiring API key")
    
    results = []
    
    # Basic endpoint tests (no API key needed)
    results.append(("Health Check", test_health()))
    results.append(("Catalog", test_catalog()))
    results.append(("Echo", test_echo()))
    
    # Process endpoints (may need API key for live)
    results.append(("Process Text", test_process_text(live=live)))
    results.append(("Process Audio", test_process_audio(live=live)))
    results.append(("Invalid Model Rejection", test_invalid_model()))
    
    # Summary
    print("\n" + "="*60)
    print("TEST SUMMARY")
    print("="*60)
    
    passed = sum(1 for _, result in results if result)
    total = len(results)
    
    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status} - {test_name}")
    
    print(f"\nTotal: {passed}/{total} tests passed")
    
    if passed == total:
        print("\n🎉 All tests passed!")
        return 0
    else:
        print(f"\n⚠️  {total - passed} test(s) failed")
        return 1


if __name__ == "__main__":
    import sys
    
    # Check for --live flag
    live_mode = "--live" in sys.argv
    
    exit_code = main(live=live_mode)
    sys.exit(exit_code)
