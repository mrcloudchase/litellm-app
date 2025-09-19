"""
Presidio Post-call PII Guardrail

Comprehensive ML-based PII detection in model responses before they reach the user.
Uses Microsoft Presidio for detecting 50+ PII entity types with context-aware analysis.
"""

import litellm
from typing import Dict, Any
from litellm._logging import verbose_proxy_logger
from litellm.integrations.custom_guardrail import CustomGuardrail
from litellm.proxy._types import UserAPIKeyAuth

from pii_presidio_detection import PIIPresidioDetection


class PIIPresidioPostCallGuardrail(CustomGuardrail):
    """Post-call ML-based PII detection guardrail using Microsoft Presidio"""
    
    def __init__(self, **kwargs):
        """
        Initialize the Presidio post-call guardrail
        
        Optional kwargs:
            language: Language code for analysis (default: "en")
            threshold: Confidence threshold for PII detection (default: 0.7)
            entities: List of specific entities to detect (default: comprehensive list)
            block_on_detection: Whether to block or anonymize (default: True)
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
                f"Presidio Post-call Guardrail initialized: language={self.language}, "
                f"threshold={self.threshold}, entities={len(self.detector.entities_to_detect)}"
            )
        except Exception as e:
            verbose_proxy_logger.error(f"Failed to initialize Presidio detector: {e}")
            raise
        
        super().__init__(**kwargs)

    async def async_post_call_success_hook(
        self,
        data: dict,
        user_api_key_dict: UserAPIKeyAuth,
        response,
    ):
        """
        Runs on response from LLM API call
        Analyzes model output for comprehensive PII detection using Presidio
        """
        verbose_proxy_logger.debug("Presidio post-call guardrail: Starting PII analysis on response")
        
        if not isinstance(response, litellm.ModelResponse):
            verbose_proxy_logger.debug("Response is not a ModelResponse, skipping PII check")
            return None
        
        # Analyze each choice in the response
        for choice_idx, choice in enumerate(response.choices):
            if not isinstance(choice, litellm.Choices):
                continue
                
            if not choice.message.content or not isinstance(choice.message.content, str):
                continue
                
            content = choice.message.content
            verbose_proxy_logger.debug(f"Analyzing choice {choice_idx}: {content[:100]}...")
            
            # Check for PII using Presidio
            if self.detector.has_pii(content, threshold=self.threshold):
                # Get detailed analysis
                analysis = self.detector.get_analysis_summary(content, threshold=self.threshold)
                
                verbose_proxy_logger.warning(
                    f"Presidio post-call: PII detected in choice {choice_idx}. "
                    f"Entities: {analysis['entity_types']}, Count: {analysis['entity_count']}"
                )
                
                if self.block_on_detection:
                    # Block the entire response
                    detected_types = ", ".join(analysis['entity_types'])
                    raise ValueError(
                        f"Post-call Presidio guardrail blocked PII detected: {detected_types} "
                        f"(confidence >= {self.threshold})"
                    )
                else:
                    # Log but allow
                    verbose_proxy_logger.warning(
                        f"PII detected but not blocking: {analysis['entity_types']}"
                    )

        verbose_proxy_logger.debug("Presidio post-call guardrail: PII analysis completed")
        return None
    
    def get_guardrail_info(self) -> dict:
        """Return information about this guardrail configuration"""
        return {
            "guardrail_type": "presidio_postcall",
            "language": self.language,
            "threshold": self.threshold,
            "entities_monitored": len(self.detector.entities_to_detect),
            "entity_types": self.detector.entities_to_detect,
            "block_on_detection": self.block_on_detection
        }
