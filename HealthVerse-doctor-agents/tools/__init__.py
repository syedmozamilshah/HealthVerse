"""
tools/__init__.py
"""
from .specialist_tools import detect_red_flags, classify_message_intent

ALL_TOOLS = [detect_red_flags, classify_message_intent]
