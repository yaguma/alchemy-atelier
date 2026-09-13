#!/usr/bin/env python3
"""Generate image(s) via Google AI Studio (Gemini API) and save them as PNG files.

Reads the API key from the GEMINI_API_KEY (preferred) or GOOGLE_API_KEY environment
variable -- never pass the key on the command line.

Examples:
    python3 generate_image.py \\
        --prompt "Soft watercolor fantasy illustration style, ... a healing herb icon" \\
        --output atelier/assets/icons/materials/herb_common.png

    python3 generate_image.py \\
        --prompt "..." --model imagen-4.0-generate-001 --count 3 \\
        --output atelier/assets/backgrounds/garden_bg.png
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import urllib.error
import urllib.request

API_BASE = "https://generativelanguage.googleapis.com/v1beta"
DEFAULT_MODEL = "gemini-2.5-flash-image"
REQUEST_TIMEOUT_SECONDS = 120


def get_api_key() -> str:
    key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    if not key:
        print(
            "error: GEMINI_API_KEY (or GOOGLE_API_KEY) environment variable is not set.\n"
            "Get a key at https://aistudio.google.com/app/apikey and export it before "
            "running this script.",
            file=sys.stderr,
        )
        sys.exit(1)
    return key


def call_api(url: str, api_key: str, payload: dict) -> dict:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        method="POST",
        headers={"Content-Type": "application/json", "x-goog-api-key": api_key},
    )
    try:
        with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT_SECONDS) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        print(f"error: API request failed ({e.code}): {body}", file=sys.stderr)
        sys.exit(1)
    except urllib.error.URLError as e:
        print(f"error: could not reach the Gemini API: {e.reason}", file=sys.stderr)
        sys.exit(1)


def generate_with_gemini(
    prompt: str, model: str, api_key: str, reference_images: list[str]
) -> list[bytes]:
    parts: list[dict] = [{"text": prompt}]
    for ref_path in reference_images:
        with open(ref_path, "rb") as f:
            encoded = base64.b64encode(f.read()).decode("ascii")
        mime = "image/png" if ref_path.lower().endswith(".png") else "image/jpeg"
        parts.append({"inline_data": {"mime_type": mime, "data": encoded}})

    payload = {
        "contents": [{"parts": parts}],
        "generationConfig": {"responseModalities": ["IMAGE"]},
    }
    result = call_api(f"{API_BASE}/models/{model}:generateContent", api_key, payload)

    images: list[bytes] = []
    for candidate in result.get("candidates", []):
        for part in candidate.get("content", {}).get("parts", []):
            inline = part.get("inlineData") or part.get("inline_data")
            if inline and inline.get("data"):
                images.append(base64.b64decode(inline["data"]))

    if not images:
        print(
            "error: no image was returned by the API. Raw response:\n"
            + json.dumps(result, indent=2, ensure_ascii=False),
            file=sys.stderr,
        )
        sys.exit(1)
    return images


def generate_with_imagen(
    prompt: str, model: str, api_key: str, count: int, aspect_ratio: str
) -> list[bytes]:
    payload = {
        "instances": [{"prompt": prompt}],
        "parameters": {"sampleCount": count, "aspectRatio": aspect_ratio},
    }
    result = call_api(f"{API_BASE}/models/{model}:predict", api_key, payload)

    images: list[bytes] = []
    for prediction in result.get("predictions", []):
        encoded = prediction.get("bytesBase64Encoded")
        if encoded:
            images.append(base64.b64decode(encoded))

    if not images:
        print(
            "error: no image was returned by the API. Raw response:\n"
            + json.dumps(result, indent=2, ensure_ascii=False),
            file=sys.stderr,
        )
        sys.exit(1)
    return images


def save_images(images: list[bytes], output: str) -> list[str]:
    base, ext = os.path.splitext(output)
    ext = ext or ".png"
    out_dir = os.path.dirname(os.path.abspath(output))
    os.makedirs(out_dir, exist_ok=True)

    paths: list[str] = []
    if len(images) == 1:
        with open(output, "wb") as f:
            f.write(images[0])
        paths.append(output)
    else:
        for i, image_bytes in enumerate(images, start=1):
            path = f"{base}_{i}{ext}"
            with open(path, "wb") as f:
                f.write(image_bytes)
            paths.append(path)
    return paths


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate image(s) via Google AI Studio (Gemini API)."
    )
    parser.add_argument("--prompt", required=True, help="Text prompt describing the image")
    parser.add_argument(
        "--output",
        required=True,
        help="Output file path. When multiple images are produced, files are "
        "suffixed _1, _2, ... before the extension.",
    )
    parser.add_argument(
        "--model",
        default=DEFAULT_MODEL,
        help=f"Model ID to use (default: {DEFAULT_MODEL}). Imagen models "
        "(imagen-...) use the predict endpoint; anything else uses generateContent.",
    )
    parser.add_argument(
        "--count",
        type=int,
        default=1,
        help="Number of images to generate. Only honored for Imagen models.",
    )
    parser.add_argument(
        "--aspect-ratio",
        default="1:1",
        help="Aspect ratio, e.g. 1:1, 16:9, 9:16. Only honored for Imagen models.",
    )
    parser.add_argument(
        "--reference-image",
        action="append",
        default=[],
        dest="reference_images",
        help="Path to a reference image for style transfer / editing. Repeatable. "
        "Only honored for Gemini (non-Imagen) models.",
    )
    args = parser.parse_args()

    api_key = get_api_key()

    if args.model.startswith("imagen-"):
        images = generate_with_imagen(
            args.prompt, args.model, api_key, args.count, args.aspect_ratio
        )
    else:
        if args.count > 1:
            print(
                "warning: --count is only honored for Imagen models; "
                "generating a single image with the Gemini model.",
                file=sys.stderr,
            )
        images = generate_with_gemini(
            args.prompt, args.model, api_key, args.reference_images
        )

    for path in save_images(images, args.output):
        print(path)


if __name__ == "__main__":
    main()
