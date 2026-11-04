"""Where every sound is listed: its id, group, what it's for, its variants and its demo.

A sound function takes the variant index and returns an array, or a dict of named parts (a
compound sound like the 3-2-1 beep and its GO). Victories list their cues on a timeline.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Callable


@dataclass
class Sound:
    id: str
    group: str
    name: str
    desc: str
    variants: list[tuple[str, str]]  # (letter, what it is)
    fn: Callable
    level: float = -1.0  # peak level in dB the file is written at
    loop: bool = False
    sr: int | None = None
    demo: dict | None = None  # how the audition page plays it (a sequence of parts)
    where: str = ""  # who hears it in the game


@dataclass
class Victory:
    id: str
    name: str
    rarity: str
    length: float
    cues: list[tuple[str, float, float]] = field(default_factory=list)  # (sound id, at, gain)


SOUNDS: list[Sound] = []
VICTORIES: list[Victory] = []


def sound(id: str, group: str, name: str, desc: str, variants=None, **kw):
    variants = variants or [("A", ""), ("B", ""), ("C", "")]

    def deco(fn):
        SOUNDS.append(Sound(id, group, name, desc, list(variants), fn, **kw))
        return fn

    return deco
