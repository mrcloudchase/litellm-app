"""
Microsoft Presidio PII Detection
Comprehensive ML-based PII detection using Microsoft's Presidio library
"""

from typing import List, Dict, Any
from presidio_analyzer import AnalyzerEngine
from presidio_analyzer.nlp_engine import NlpEngineProvider


class PIIPresidioDetection:
    """Shared Presidio PII detection logic for all guardrails"""
    
    def __init__(self, language: str = "en", entities_to_detect: List[str] = None):
        """
        Initialize Presidio analyzer and anonymizer engines
        
        Args:
            language: Language code for analysis (default: "en")
            entities_to_detect: List of PII entities to detect. If None, uses comprehensive set.
        """
        self.language = language
        
        # Default comprehensive PII entity list
        if entities_to_detect is None:
            self.entities_to_detect = [
                "PERSON",           # Names, titles
                "EMAIL_ADDRESS",    # Email addresses
                "PHONE_NUMBER",     # Phone numbers
                "US_SSN",          # Social Security Numbers
                "CREDIT_CARD",     # Credit card numbers
                "LOCATION",        # Geographic locations
                "ORGANIZATION",    # Company/organization names
                "DATE_TIME",       # Dates and times
                "IP_ADDRESS",      # IP addresses
                "URL",             # URLs
                "US_DRIVER_LICENSE", # Driver's license numbers
                "US_PASSPORT",     # Passport numbers
                "IBAN_CODE",       # International bank account numbers
                "US_BANK_NUMBER",  # US bank routing numbers
                "CRYPTO",          # Cryptocurrency addresses
                "MEDICAL_LICENSE", # Medical license numbers
                "NRP",             # National registration numbers
            ]
        else:
            self.entities_to_detect = entities_to_detect
        
        # Initialize NLP engine provider (using spaCy)
        nlp_configuration = {
            "nlp_engine_name": "spacy",
            "models": [{"lang_code": self.language, "model_name": "en_core_web_sm"}],
        }
        
        try:
            # Create NLP engine
            nlp_engine_provider = NlpEngineProvider(nlp_configuration=nlp_configuration)
            nlp_engine = nlp_engine_provider.create_engine()
            
            # Initialize Presidio analyzer
            self.analyzer = AnalyzerEngine(nlp_engine=nlp_engine)
            
        except Exception as e:
            # Fallback to default configuration if spaCy model not available
            print(f"Warning: Could not load spaCy model, using default: {e}")
            self.analyzer = AnalyzerEngine()
    
    def has_pii(self, text: str, threshold: float = 0.7) -> bool:
        """
        Check if text contains any PII entities above the confidence threshold
        
        Args:
            text: Text to analyze
            threshold: Confidence threshold (0.0-1.0)
            
        Returns:
            True if PII detected above threshold, False otherwise
        """
        if not text or not text.strip():
            return False
            
        try:
            # Analyze text for PII
            results = self.analyzer.analyze(
                text=text,
                entities=self.entities_to_detect,
                language=self.language
            )
            
            # Check if any results meet the threshold
            return any(result.score >= threshold for result in results)
            
        except Exception as e:
            print(f"Error during Presidio analysis: {e}")
            return False
    
    def get_detected_entities(self, text: str, threshold: float = 0.7) -> list:
        """
        Get detailed information about detected PII entities
        
        Args:
            text: Text to analyze
            threshold: Confidence threshold (0.0-1.0)
            
        Returns:
            List of detected entities with details
        """
        if not text or not text.strip():
            return []
            
        try:
            results = self.analyzer.analyze(
                text=text,
                entities=self.entities_to_detect,
                language=self.language
            )
            
            # Filter by threshold and format results
            detected = []
            for result in results:
                if result.score >= threshold:
                    detected.append({
                        "entity_type": result.entity_type,
                        "start": result.start,
                        "end": result.end,
                        "score": result.score,
                        "text": text[result.start:result.end]
                    })
            
            return detected
            
        except Exception as e:
            print(f"Error during Presidio analysis: {e}")
            return []
    
    def get_detected_types(self, text: str, threshold: float = 0.7) -> List[str]:
        """
        Get list of detected PII entity types
        
        Args:
            text: Text to analyze
            threshold: Confidence threshold (0.0-1.0)
            
        Returns:
            List of unique entity types detected
        """
        entities = self.get_detected_entities(text, threshold)
        return list(set(entity["entity_type"].lower() for entity in entities))
    
    def get_analysis_summary(self, text: str, threshold: float = 0.7) -> dict:
        """
        Get comprehensive analysis summary
        
        Args:
            text: Text to analyze
            threshold: Confidence threshold (0.0-1.0)
            
        Returns:
            Dictionary with analysis summary
        """
        entities = self.get_detected_entities(text, threshold)
        
        return {
            "has_pii": len(entities) > 0,
            "entity_count": len(entities),
            "entity_types": list(set(entity["entity_type"] for entity in entities)),
            "entities": entities
        }
