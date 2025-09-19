"""
Presidio Pre-call PII Guardrail

Comprehensive ML-based PII detection in user input before requests reach the LLM model.
Uses Microsoft Presidio for detecting 50+ PII entity types with context-aware analysis.
"""

from typing import Optional, Union, Literal, Dict, Any

from litellm._logging import verbose_proxy_logger
from litellm.caching.caching import DualCache
from litellm.integrations.custom_guardrail import CustomGuardrail
from litellm.proxy._types import UserAPIKeyAuth

from pii_presidio_detection import PIIPresidioDetection


class PIIPresidioPreCallGuardrail(CustomGuardrail):
    """Pre-call ML-based PII detection guardrail using Microsoft Presidio"""
    
    def __init__(self, **kwargs):
        """
        Initialize the Presidio pre-call guardrail
        
        Optional kwargs:
            language: Language code for analysis (default: "en")
            threshold: Confidence threshold for PII detection (default: 0.7)
            entities: List of specific entities to detect (default: comprehensive list)
            block_on_detection: Whether to block or just log (default: True)
        """
        self.optional_params = kwargs
        
        # Configuration from optional params
        self.language = kwargs.get("language", "en")
        self.threshold = kwargs.get("threshold", 0.7)
        self.entities = kwargs.get("entities", None)  # None = use default comprehensive list
        self.block_on_detection = kwargs.get("block_on_detection", True)
        
        # Initialize Presidio detector
        try:
            self.detector = PIIPresidioDetection(
                language=self.language,
                entities_to_detect=self.entities
            )
            verbose_proxy_logger.info(
                f"Presidio Pre-call Guardrail initialized: language={self.language}, "
                f"threshold={self.threshold}, entities={len(self.detector.entities_to_detect)}"
            )
        except Exception as e:
            verbose_proxy_logger.error(f"Failed to initialize Presidio detector: {e}")
            raise
        
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
        Analyzes user input for comprehensive PII detection using Presidio
        """
        verbose_proxy_logger.debug("Presidio pre-call guardrail: Starting PII analysis")
        
        _messages = data.get("messages")
        if not _messages:
            verbose_proxy_logger.debug("No messages found in request data")
            return data
        
        # Analyze each message for PII
        for i, message in enumerate(_messages):
            _content = message.get("content")
            
            if not isinstance(_content, str):
                continue
                
            verbose_proxy_logger.debug(f"Analyzing message {i}: {_content[:100]}...")
            
            # Check for PII using Presidio
            if self.detector.has_pii(_content, threshold=self.threshold):
                # Get detailed analysis
                analysis = self.detector.get_analysis_summary(_content, threshold=self.threshold)
                
                verbose_proxy_logger.warning(
                    f"Presidio pre-call: PII detected in message {i}. "
                    f"Entities: {analysis['entity_types']}, Count: {analysis['entity_count']}"
                )
                
                if self.block_on_detection:
                    # Block the request
                    detected_types = ", ".join(analysis['entity_types'])
                    raise ValueError(
                        f"Pre-call Presidio guardrail blocked PII detected: {detected_types} "
                        f"(confidence >= {self.threshold})"
                    )
                else:
                    # Log but allow (could also anonymize here)
                    verbose_proxy_logger.warning(
                        f"PII detected but not blocking: {analysis['entity_types']}"
                    )

        verbose_proxy_logger.debug("Presidio pre-call guardrail: PII analysis passed")
        return data
    
    def get_guardrail_info(self) -> dict:
        """Return information about this guardrail configuration"""
        return {
            "guardrail_type": "presidio_precall",
            "language": self.language,
            "threshold": self.threshold,
            "entities_monitored": len(self.detector.entities_to_detect),
            "entity_types": self.detector.entities_to_detect,
            "block_on_detection": self.block_on_detection
        }
