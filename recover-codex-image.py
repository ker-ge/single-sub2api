"""Recover one explicitly selected native image result from a local Codex session."""
import argparse
import base64
import hashlib
import io
import json
from pathlib import Path

from PIL import Image

FORMAT_SUFFIXES = {"PNG": {".png"}, "JPEG": {".jpg", ".jpeg"}, "WEBP": {".webp"}}


def recover(session, image_id, output):
    matches = []
    with Path(session).open(encoding="utf-8") as source:
        for line in source:
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue  # The active session can end with a partially written line.
            item = record.get("payload", {})
            if (record.get("type") == "response_item"
                    and item.get("type") == "image_generation_call"
                    and item.get("id") == image_id
                    and item.get("status") == "completed"
                    and isinstance(item.get("result"), str)
                    and item["result"]):
                matches.append(item["result"])
    if not matches:
        raise ValueError("No completed image with the specified ID in this session")
    if len(set(matches)) != 1:
        raise ValueError("Conflicting results for the specified image ID")
    data = base64.b64decode(matches[0], validate=True)
    with Image.open(io.BytesIO(data)) as image:
        image_format = image.format
        if image_format not in FORMAT_SUFFIXES:
            raise ValueError("Supported image formats are PNG, JPEG and WebP")
        size = image.size
        image.verify()
    with Image.open(io.BytesIO(data)) as image:
        image.load()
    target = Path(output)
    if target.suffix.lower() not in FORMAT_SUFFIXES[image_format]:
        suffixes = ", ".join(sorted(FORMAT_SUFFIXES[image_format]))
        raise ValueError(f"Decoded image is {image_format}; output extension must be {suffixes}")
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open("xb") as destination:
        destination.write(data)
    return {"path": str(target.resolve()), "size": size, "format": image_format,
            "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--session", required=True, type=Path)
    parser.add_argument("--image-id", required=True)
    parser.add_argument("--output", required=True, type=Path,
                        help="Destination matching the image format: .png, .jpg/.jpeg or .webp")
    args = parser.parse_args()
    print(json.dumps(recover(args.session, args.image_id, args.output)))
