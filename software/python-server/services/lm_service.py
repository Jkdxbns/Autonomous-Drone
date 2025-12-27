"""LM (Language Model) service - business logic for text generation."""

from core.gemini_loader import GeminiLoader


class LMService:
    """Handles text generation using Gemini language models."""
    
    def __init__(self):
        """Initialize LM service with Gemini loader."""
        self.gemini_loader = GeminiLoader()
        print("[LM_SERVICE] Initialized")
    
    def generate_content(
        self,
        prompt: str,
        model_identifier: str,
        stream: bool = False
    ):
        """Generate content using a Gemini model.
        
        Args:
            prompt: Input text prompt
            model_identifier: Full model identifier (e.g., 'models/gemini-2.5-flash')
            stream: Whether to stream the response
        
        Returns:
            Generated content (streaming or complete response).
        
        Raises:
            RuntimeError: If generation fails.
        """
        model = self.gemini_loader.get_model(model_identifier)
        
        if stream:
            # Return streaming response
            return model.generate_content(prompt, stream=True)
        else:
            # Return complete response
            response = model.generate_content(prompt)
            return response
    
    def generate_with_history(
        self,
        message: str,
        model_identifier: str,
        history: list = None
    ):
        """Generate content with conversation history.
        
        Args:
            message: User message
            model_identifier: Full model identifier
            history: Optional conversation history
        
        Returns:
            Generated response.
        
        Raises:
            RuntimeError: If generation fails.
        """
        model = self.gemini_loader.get_model(model_identifier)
        chat = model.start_chat(history=history or [])
        response = chat.send_message(message)
        return response
