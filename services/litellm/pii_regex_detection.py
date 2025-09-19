import re
from typing import List

class PIIRegexDetection:
    """Shared PII detection logic for all guardrails"""
    
    def __init__(self):
        # PII Detection Patterns
        
        # Email: user@domain.com, user+tag@domain.org, user.name@sub.domain.co.uk
        self.email_pattern = re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b")
        
        # SSN: 123-45-6789, 123 45 6789, 123456789, SSN: 123-45-6789
        self.ssn_pattern = re.compile(r"\b(?:\d{3}[-\s]?\d{2}[-\s]?\d{4}|\d{9})\b")
        
        # Phone: (555) 123-4567, 555-123-4567, 555.123.4567, +1 555 123 4567, 5551234567
        self.phone_pattern = re.compile(r"\b(?:\+?1[-.\s]?)?\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}\b")
        
        # Credit Card: 4532114387653210, 4532 1143 8765 3210, 4532-1143-8765-3210 (Visa/MC/Amex/Discover)
        self.credit_card_pattern = re.compile(r"\b(?:4[0-9]{3}[\s-]?[0-9]{4}[\s-]?[0-9]{4}[\s-]?[0-9]{4}(?:[0-9]{3})?|5[1-5][0-9]{2}[\s-]?[0-9]{4}[\s-]?[0-9]{4}[\s-]?[0-9]{4}|3[47][0-9]{2}[\s-]?[0-9]{6}[\s-]?[0-9]{5}|6(?:011|5[0-9]{2})[\s-]?[0-9]{4}[\s-]?[0-9]{4}[\s-]?[0-9]{4})\b")
    
    def has_pii(self, text: str) -> bool:
        """Check if text contains any PII patterns"""
        if not text:
            return False
        return bool(self.email_pattern.search(text) or 
                   self.ssn_pattern.search(text) or 
                   self.phone_pattern.search(text) or 
                   self.credit_card_pattern.search(text))
    
    def get_detected_types(self, text: str) -> List[str]:
        """Return list of detected PII types"""
        detected = []
        if not text:
            return detected
            
        if self.email_pattern.search(text):
            detected.append("email")
        if self.ssn_pattern.search(text):
            detected.append("ssn")
        if self.phone_pattern.search(text):
            detected.append("phone")
        if self.credit_card_pattern.search(text):
            detected.append("credit_card")
            
        return detected
