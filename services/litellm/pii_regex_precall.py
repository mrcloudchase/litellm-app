"""
Pre-call PII Guardrail

Blocks PII in user input before requests reach the LLM model.
"""

from typing import Optional, Union, Literal

from litellm._logging import verbose_proxy_logger
from litellm.caching.caching import DualCache
from litellm.integrations.custom_guardrail import CustomGuardrail
from litellm.proxy._types import UserAPIKeyAuth

from pii_regex_detection import PIIRegexDetection

class PIIRegexPreCallGuardrail(CustomGuardrail):
    """Pre-call only PII detection guardrail - blocks PII in user input"""
    
    def __init__(self, **kwargs):
        self.optional_params = kwargs
        self.detector = PIIRegexDetection()
        super().__init__(**kwargs)

    async def async_pre_call_hook(
        self,
        user_api_key_dict: UserAPIKeyAuth,
        cache: DualCache,
        data: dict,
        call_type: Literal[
            "completion", "text_completion", "embeddings", "image_generation",
            "moderation", "audio_transcription", "pass_through_endpoint", "rerank"
        ],
    ) -> Optional[Union[Exception, str, dict]]:
        """
        Runs before the LLM API call
        Blocks requests containing PII in user input
        """
        _messages = data.get("messages")
        if _messages:
            for message in _messages:
                _content = message.get("content")
                if isinstance(_content, str) and self.detector.has_pii(_content):
                    detected_types = self.detector.get_detected_types(_content)
                    raise ValueError(f"Pre-call guardrail blocked PII detected: {', '.join(detected_types)}")

        verbose_proxy_logger.debug("Pre-call PII check passed for messages %s", _messages)
        return data
