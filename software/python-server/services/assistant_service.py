"""Assistant service - handles two-pass LLM pipeline for categorization and task generation."""

import json
import re
from pathlib import Path
from typing import Dict, Optional, Tuple

from core.gemini_loader import GeminiLoader
from config import BASE_DIR


class AssistantService:
    """Handles two-pass assistant pipeline: categorization -> task generation."""
    
    def __init__(self, device_registry):
        """Initialize assistant service with templates and dependencies.
        
        Args:
            device_registry: DeviceRegistry instance
        """
        self.gemini_loader = GeminiLoader()
        self.device_registry = device_registry
        
        # Load prompt templates
        self.templates_dir = BASE_DIR / "prompt_templates"
        self.task_schemas = self._load_json(self.templates_dir / "task_schemas.json")
        self.pass1_template = self._load_text(self.templates_dir / "pass1_categorization.txt")
        self.pass2_templates = self._load_json(self.templates_dir / "pass2_task_prompts.json")
        
        print("[ASSISTANT_SERVICE] Initialized with two-pass pipeline")
    
    def _load_json(self, path: Path) -> dict:
        """Load JSON file."""
        try:
            with path.open('r', encoding='utf-8') as f:
                return json.load(f)
        except Exception as e:
            print(f"[ASSISTANT_SERVICE] Error loading {path}: {e}")
            return {}
    
    def _load_text(self, path: Path) -> str:
        """Load text file."""
        try:
            with path.open('r', encoding='utf-8') as f:
                return f.read()
        except Exception as e:
            print(f"[ASSISTANT_SERVICE] Error loading {path}: {e}")
            return ""
    
    def handle_request(self, user_query: str, source_device_mac: str, lm_model: str = None) -> dict:
        """Main entry point - orchestrates two-pass flow.
        
        Args:
            user_query: User's natural language input
            source_device_mac: MAC address of requesting device
            lm_model: Optional LM model identifier
        
        Returns:
            Dictionary with result or streaming flag
        """
        try:
            print(f"\n[ASSISTANT_SERVICE] ===== NEW REQUEST =====")
            print(f"[ASSISTANT_SERVICE] User query: {user_query}")
            print(f"[ASSISTANT_SERVICE] Source MAC: {source_device_mac}")
            
            # Pass 1: Categorization
            pass1_result = self.pass1_categorize(user_query, lm_model)
            category = pass1_result['category']
            
            print(f"[ASSISTANT_SERVICE] Pass 1 result: category={category}, confidence={pass1_result['confidence']}")
            
            # Route based on category
            if category == 'text-generation':
                return self.handle_text_generation(pass1_result, lm_model)
            elif category == 'bt-control':
                return self.handle_bt_control(pass1_result, source_device_mac, lm_model)
            else:
                return {
                    "status": "error",
                    "error": {
                        "code": "UNKNOWN_CATEGORY",
                        "message": f"Unknown category: {category}"
                    }
                }
        
        except Exception as e:
            print(f"[ASSISTANT_SERVICE] Error in handle_request: {e}")
            import traceback
            traceback.print_exc()
            return {
                "status": "error",
                "error": {
                    "code": "PROCESSING_ERROR",
                    "message": str(e)
                }
            }
    
    def pass1_categorize(self, user_query: str, lm_model: str = None) -> dict:
        """Execute Pass 1: Categorization.
        
        Args:
            user_query: User's input
            lm_model: Optional LM model identifier
        
        Returns:
            Dictionary with category, confidence, reasoning, user-data
        """
        print("[ASSISTANT_SERVICE] Executing Pass 1: Categorization")
        
        # Construct prompt
        prompt = self.pass1_template.replace("{user_query}", user_query)
        
        # Call Gemini
        model = self.gemini_loader.get_model(lm_model or "gemini-2.5-flash-lite")
        response = model.generate_content(prompt)
        raw_output = response.text.strip()
        
        print(f"[ASSISTANT_SERVICE] Pass 1 raw output: {raw_output}")
        
        # Parse JSON (remove markdown if present)
        json_text = self._extract_json(raw_output)
        result = json.loads(json_text)
        
        # Validate required fields
        required_fields = ['category', 'confidence', 'reasoning', 'user-data']
        for field in required_fields:
            if field not in result:
                raise ValueError(f"Pass 1 output missing required field: {field}")
        
        return result
    
    def handle_text_generation(self, pass1_result: dict, lm_model: str = None) -> dict:
        """Handle text-generation category - return flag to use streaming.
        
        Args:
            pass1_result: Output from Pass 1
            lm_model: Optional LM model identifier
        
        Returns:
            Dictionary with streaming flag
        """
        print("[ASSISTANT_SERVICE] Handling text-generation (streaming mode)")
        return {
            "use_streaming": True,
            "user_query": pass1_result['user-data'],
            "lm_model": lm_model
        }
    
    def handle_bt_control(self, pass1_result: dict, source_device_mac: str, lm_model: str = None) -> dict:
        """Handle bt-control category - execute Pass 2 and construct JSON.
        
        Args:
            pass1_result: Output from Pass 1
            source_device_mac: MAC address of requesting device
            lm_model: Optional LM model identifier
        
        Returns:
            Complete bt-control JSON response
        """
        print("[ASSISTANT_SERVICE] Handling bt-control")
        
        user_data = pass1_result['user-data']
        
        # Get device list from registry
        device_list_str = self._format_device_list()
        
        # Get output format from task_schemas
        output_format = self.task_schemas['pass2_output_formats']['bt-control'].get('output-format', [])
        output_format_str = json.dumps(output_format) if output_format else "null"
        
        print(f"[ASSISTANT_SERVICE] Device list:\n{device_list_str}")
        print(f"[ASSISTANT_SERVICE] Output format: {output_format_str}")
        
        # Execute Pass 2 with output format from schemas
        command, target_device_name = self.pass2_bt_control(
            user_data,
            device_list_str,
            output_format_str,
            lm_model
        )
        
        # Look up target device once
        target_device = self._find_device_by_name(target_device_name)
        
        # Construct final JSON
        final_json = self._construct_bt_control_json(
            user_data,
            source_device_mac,
            target_device_name,
            target_device,
            command
        )
        
        return {
            "status": "success",
            "result": final_json
        }
    
    def pass2_bt_control(
        self,
        user_data: str,
        device_list: str,
        output_format_str: str,
        lm_model: str = None
    ) -> Tuple[str, str]:
        """Execute Pass 2 for bt-control.
        
        Args:
            user_data: User's original query
            device_list: Formatted device list string
            output_format_str: JSON string of output formats from schemas
            lm_model: Optional LM model identifier
        
        Returns:
            Tuple of (command, target_device_name)
        """
        print("[ASSISTANT_SERVICE] Executing Pass 2: BT Control")
        
        # Load prompt template
        template_config = self.pass2_templates['bt-control']
        prompt_template = template_config['user_prompt_template']
        
        # Construct prompt with actual output format
        prompt = prompt_template.format(
            user_data=user_data,
            device_list=device_list,
            output_format=output_format_str
        )
        
        # Generate command
        model = self.gemini_loader.get_model(lm_model or "gemini-2.5-flash-lite")
        response = model.generate_content(prompt)
        raw_output = response.text.strip()
        
        print(f"[ASSISTANT_SERVICE] Pass 2 output:\n{raw_output}")
        
        # Parse output
        command, target_device = self._parse_bt_command_output(raw_output)
        
        print(f"[ASSISTANT_SERVICE] Final command: {command}")
        print(f"[ASSISTANT_SERVICE] Target device: {target_device}")
        
        return command, target_device
    
    def _parse_bt_command_output(self, raw_output: str) -> Tuple[str, str]:
        """Parse command and target device from Pass 2 output.
        
        Args:
            raw_output: Raw output from Gemini
        
        Returns:
            Tuple of (command, target_device_name)
        """
        lines = raw_output.strip().split('\n')
        command = ""
        target_device = ""
        
        for line in lines:
            line = line.strip()
            if line.startswith('TARGET_DEVICE:'):
                target_device = line.split('TARGET_DEVICE:')[1].strip()
            elif line and not line.startswith('TARGET_DEVICE:'):
                if not command:  # First non-empty line is the command
                    command = line
        
        # Fallback: if no TARGET_DEVICE found, use entire output as command
        if not command:
            command = raw_output.strip()
        
        return command, target_device
    
    def _format_device_list(self) -> str:
        """Format device list for LLM prompt.
        
        Returns:
            Formatted string of devices
        """
        devices = self.device_registry.get_all_devices()
        lines = []
        
        for device in devices:
            mac = device.get('mac_address', '')
            name = device.get('custom_name') or device.get('device_name', 'Unknown')
            device_type = device.get('device_type', 'unknown')
            status = device.get('status', 'unknown')
            
            if device_type == 'bluetooth':
                lines.append(f"- {name}: {mac} [Bluetooth, status: {status}]")
            else:
                lines.append(f"- {name}: {mac} [status: {status}]")
        
        return '\n'.join(lines) if lines else "No devices available"
    
    def _construct_bt_control_json(
        self,
        user_data: str,
        source_mac: str,
        target_device_name: str,
        target_device: Optional[dict],
        command: str
    ) -> dict:
        """Construct final bt-control JSON response.
        
        Args:
            user_data: User's original query
            source_mac: Source device MAC
            target_device_name: Target device name from Gemini
            target_device: Target device object (already looked up, or None)
            command: Generated command
        
        Returns:
            Complete bt-control JSON
        """
        # Get source device info
        source_device = self.device_registry.get_device(source_mac)
        source_device_str = self._format_device_string(source_device, source_mac)
        
        # Use pre-looked-up device
        if not target_device:
            # Device not found - return error
            return {
                "task": "bt-control",
                "user-data": user_data,
                "processing-device": "server",
                "source-device": source_device_str,
                "target-device": f"{target_device_name} (NOT FOUND)",
                "parent-device": source_device_str,
                "output": {
                    "generated_output": f"ERROR:DEVICE_NOT_FOUND:{target_device_name}"
                },
                "error": {
                    "code": "DEVICE_NOT_FOUND",
                    "message": f"Device '{target_device_name}' not found in registry"
                }
            }
        
        target_mac = target_device.get('mac_address', '')
        target_device_str = self._format_device_string(target_device, target_mac)
        
        # Update target device's last_seen timestamp (mark as active)
        # This keeps Bluetooth devices showing as "online" when commands are sent
        if target_mac:
            self.device_registry.update_last_seen(target_mac)
            print(f"[ASSISTANT_SERVICE] Updated activity for target device: {target_mac}")
        
        # Get parent device (for Bluetooth devices)
        parent_mac = target_device.get('parent_device')
        if parent_mac:
            parent_device = self.device_registry.get_device(parent_mac)
            parent_device_str = self._format_device_string(parent_device, parent_mac)
        else:
            parent_device_str = target_device_str
        
        return {
            "task": "bt-control",
            "user-data": user_data,
            "processing-device": "server",
            "source-device": source_device_str,
            "target-device": target_device_str,
            "parent-device": parent_device_str,
            "output": {
                "generated_output": command
            }
        }
    
    def _find_device_by_name(self, device_name: str) -> Optional[dict]:
        """Find device in registry by name (case-insensitive).
        
        Args:
            device_name: Device name to search for
        
        Returns:
            Device dict or None
        """
        if not device_name:
            return None
        
        devices = self.device_registry.get_all_devices()
        device_name_lower = device_name.lower().strip()
        
        for device in devices:
            # Check custom_name first, then device_name
            custom_name = (device.get('custom_name') or '').lower().strip()
            auto_name = (device.get('device_name') or '').lower().strip()
            
            if device_name_lower == custom_name or device_name_lower == auto_name:
                return device
            
            # Also check if device_name is contained in the names
            if device_name_lower in custom_name or device_name_lower in auto_name:
                return device
        
        return None
    
    def _format_device_string(self, device: Optional[dict], mac: str) -> str:
        """Format device info as string for JSON response.
        
        Args:
            device: Device dict from registry
            mac: MAC address
        
        Returns:
            Formatted string: "device_name (MAC: XX:XX:XX:XX:XX:XX)"
        """
        if device:
            name = device.get('custom_name') or device.get('device_name', 'Unknown')
            return f"{name} (MAC: {mac})"
        else:
            return f"Unknown (MAC: {mac})"
    
    def _extract_json(self, text: str) -> str:
        """Extract JSON from text that may contain markdown code blocks.
        
        Args:
            text: Raw text that may contain JSON
        
        Returns:
            Clean JSON string
        """
        # Remove markdown code blocks
        text = re.sub(r'```json\s*', '', text)
        text = re.sub(r'```\s*', '', text)
        
        # Find JSON object
        json_match = re.search(r'\{.*\}', text, re.DOTALL)
        if json_match:
            json_str = json_match.group(0)
            
            # Fix double curly braces (Gemini sometimes returns {{ }} instead of { })
            # Replace {{ with { and }} with } but only at the start/end
            json_str = re.sub(r'^\{\{', '{', json_str)
            json_str = re.sub(r'\}\}$', '}', json_str)
            
            return json_str
        
        return text.strip()
