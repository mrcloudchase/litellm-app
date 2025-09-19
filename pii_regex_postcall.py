"""
Post-call PII Guardrail

Blocks PII in model responses before they reach the user.
"""

import litellm
from litellm._logging import verbose_proxy_logger
from litellm.integrations.custom_guardrail import CustomGuardrail
from litellm.proxy._types import UserAPIKeyAuth

from pii_regex_detection import PIIRegexDetection

class PIIRegexPostCallGuardrail(CustomGuardrail):
    """Post-call only PII detection guardrail - blocks PII in model output"""
    
    def __init__(self, **kwargs):
        self.optional_params = kwargs
        self.detector = PIIRegexDetection()
        super().__init__(**kwargs)

    async def async_post_call_success_hook(
        self,
        data: dict,
        user_api_key_dict: UserAPIKeyAuth,
        response,
    ):
        """
        Runs on response from LLM API call
        Blocks responses containing PII in model output
        """
        verbose_proxy_logger.debug("Post-call PII check response: %s", response)
        
        if isinstance(response, litellm.ModelResponse):
            for choice in response.choices:
                if isinstance(choice, litellm.Choices):
                    verbose_proxy_logger.debug("Post-call PII check choice: %s", choice)
                    if (
                        choice.message.content
                        and isinstance(choice.message.content, str)
                        and self.detector.has_pii(choice.message.content)
                    ):
                        detected_types = self.detector.get_detected_types(choice.message.content)
                        raise ValueError(f"Post-call guardrail blocked PII detected: {', '.join(detected_types)}")
        return None
