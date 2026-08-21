"""
API Key Manager for Gemini API with automatic rotation on quota errors.
Supports multiple API keys with fallback mechanism.
"""
import os
import time
import google.generativeai as genai
from typing import List, Optional, Callable, Any
from dotenv import load_dotenv

load_dotenv()


class GeminiAPIKeyManager:
    """
    Manages multiple Gemini API keys with automatic rotation.
    When one key hits quota limit, automatically switches to the next available key.
    """
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(GeminiAPIKeyManager, cls).__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        if self._initialized:
            return
            
        # Load API keys from environment
        self.api_keys: List[str] = []
        self._load_api_keys()
        
        self.current_key_index = 0
        self.key_cooldowns: dict = {}  # Track when each key can be used again
        self.cooldown_duration = 60  # Seconds to wait before retrying a failed key
        
        # Configure with the first available key
        if self.api_keys:
            self._configure_current_key()
            print(f"[APIKeyManager] Initialized with {len(self.api_keys)} API keys")
        else:
            print("[APIKeyManager] WARNING: No API keys found!")
        
        self._initialized = True
    
    def _load_api_keys(self):
        """Load API keys from environment variables."""
        # Primary key
        primary_key = os.getenv("GEMINI_API_KEY")
        if primary_key:
            self.api_keys.append(primary_key)
        
        # Additional keys (GEMINI_API_KEY_2, GEMINI_API_KEY_3, etc.)
        for i in range(2, 10):
            key = os.getenv(f"GEMINI_API_KEY_{i}")
            if key:
                self.api_keys.append(key)
        
        # Remove duplicates while preserving order
        seen = set()
        unique_keys = []
        for key in self.api_keys:
            if key not in seen:
                seen.add(key)
                unique_keys.append(key)
        self.api_keys = unique_keys
    
    def _configure_current_key(self):
        """Configure genai with the current API key."""
        if self.api_keys:
            current_key = self.api_keys[self.current_key_index]
            genai.configure(api_key=current_key)
            print(f"[APIKeyManager] Using API key {self.current_key_index + 1}/{len(self.api_keys)}")
    
    def _is_key_in_cooldown(self, key_index: int) -> bool:
        """Check if a key is still in cooldown period."""
        if key_index not in self.key_cooldowns:
            return False
        return time.time() < self.key_cooldowns[key_index]
    
    def _mark_key_failed(self, key_index: int):
        """Mark a key as failed and set cooldown."""
        self.key_cooldowns[key_index] = time.time() + self.cooldown_duration
        print(f"[APIKeyManager] Key {key_index + 1} marked as failed, cooldown for {self.cooldown_duration}s")
    
    def switch_to_next_key(self) -> bool:
        """
        Switch to the next available API key.
        Returns True if successfully switched, False if no keys available.
        """
        if len(self.api_keys) <= 1:
            print("[APIKeyManager] No alternative keys available")
            return False
        
        original_index = self.current_key_index
        attempts = 0
        
        while attempts < len(self.api_keys):
            self.current_key_index = (self.current_key_index + 1) % len(self.api_keys)
            
            if not self._is_key_in_cooldown(self.current_key_index):
                self._configure_current_key()
                print(f"[APIKeyManager] Switched to key {self.current_key_index + 1}")
                return True
            
            attempts += 1
        
        # All keys are in cooldown, use the one with shortest remaining cooldown
        min_cooldown_index = min(
            range(len(self.api_keys)),
            key=lambda i: self.key_cooldowns.get(i, 0)
        )
        self.current_key_index = min_cooldown_index
        self._configure_current_key()
        print(f"[APIKeyManager] All keys in cooldown, using key {self.current_key_index + 1}")
        return True
    
    def get_current_key(self) -> Optional[str]:
        """Get the current active API key."""
        if self.api_keys:
            return self.api_keys[self.current_key_index]
        return None
    
    def is_quota_error(self, error: Exception) -> bool:
        """Check if the error is a quota/rate limit error."""
        error_str = str(error).lower()
        quota_indicators = [
            "429", "quota", "rate", "exhausted", 
            "resource_exhausted", "too many requests",
            "limit exceeded"
        ]
        return any(indicator in error_str for indicator in quota_indicators)
    
    async def call_with_retry(
        self, 
        func: Callable, 
        *args, 
        max_retries: int = 3,
        **kwargs
    ) -> Any:
        """
        Call a function with automatic API key rotation on quota errors.
        
        Args:
            func: The function to call (should use genai internally)
            *args: Arguments to pass to the function
            max_retries: Maximum number of retries across all keys
            **kwargs: Keyword arguments to pass to the function
            
        Returns:
            The result of the function call
            
        Raises:
            Exception: If all retries are exhausted
        """
        last_error = None
        
        for attempt in range(max_retries):
            try:
                # Handle both sync and async functions
                import asyncio
                if asyncio.iscoroutinefunction(func):
                    return await func(*args, **kwargs)
                else:
                    return func(*args, **kwargs)
                    
            except Exception as e:
                last_error = e
                print(f"[APIKeyManager] Error on attempt {attempt + 1}: {str(e)[:100]}")
                
                if self.is_quota_error(e):
                    self._mark_key_failed(self.current_key_index)
                    
                    if self.switch_to_next_key():
                        print(f"[APIKeyManager] Retrying with new key...")
                        continue
                    else:
                        print("[APIKeyManager] No more keys to try")
                        raise e
                else:
                    # Non-quota error, don't retry with different key
                    raise e
        
        raise last_error if last_error else Exception("Max retries exceeded")
    
    def call_sync_with_retry(
        self, 
        func: Callable, 
        *args, 
        max_retries: int = 3,
        **kwargs
    ) -> Any:
        """
        Synchronous version of call_with_retry.
        """
        last_error = None
        
        for attempt in range(max_retries):
            try:
                return func(*args, **kwargs)
                    
            except Exception as e:
                last_error = e
                print(f"[APIKeyManager] Error on attempt {attempt + 1}: {str(e)[:100]}")
                
                if self.is_quota_error(e):
                    self._mark_key_failed(self.current_key_index)
                    
                    if self.switch_to_next_key():
                        print(f"[APIKeyManager] Retrying with new key...")
                        continue
                    else:
                        print("[APIKeyManager] No more keys to try")
                        raise e
                else:
                    raise e
        
        raise last_error if last_error else Exception("Max retries exceeded")


# Global instance
api_key_manager = GeminiAPIKeyManager()
