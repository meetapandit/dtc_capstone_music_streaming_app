#!/usr/bin/env python3
"""
stream_to_kafka.py
Reads eventsim JSON output files and streams events to Kafka topics
in chronological order, simulating real-time ingestion.

Usage:
    python stream_to_kafka.py \
        --output-dir ../output \
        --broker localhost:9092 \
        --speed-multiplier 100   # 100x faster than real time (0 = as fast as possible)
"""

import argparse
import json
import time
from datetime import datetime
from pathlib import Path

from confluent_kafka import Producer

# Eventsim filenames (underscores) → Kafka topic names (hyphens)
TOPIC_MAP = {
    "listen_events":       "listen-events",
    "page_view_events":    "page-view-events",
    "auth_events":         "auth-events",
    "status_change_events": "status-change-events",
}
KNOWN_TOPICS = set(TOPIC_MAP.keys())


def delivery_report(err, msg):
    if err:
        print(f"[ERROR] Delivery failed: {err}")


def load_and_sort_events(output_dir: str) -> list[dict]:
    """
    Load eventsim output files. Eventsim creates a directory per run
    containing topic-named files (no extension): listen_events, auth_events, etc.
    Each file is newline-delimited JSON.
    """
    events = []

    # Find all files (no extension) whose name matches a known topic
    all_files = [p for p in Path(output_dir).rglob("*")
                 if p.is_file() and p.name in KNOWN_TOPICS]

    if not all_files:
        raise FileNotFoundError(
            f"No eventsim topic files found in {output_dir}. "
            f"Expected files named: {KNOWN_TOPICS}"
        )

    print(f"Loading {len(all_files)} file(s)...")
    for fpath in sorted(all_files):
        topic = fpath.name          # filename IS the topic name
        count_before = len(events)
        with open(fpath) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    event = json.loads(line)
                    event["_topic"] = TOPIC_MAP[topic]  # map filename → kafka topic name
                    events.append(event)
                except json.JSONDecodeError:
                    continue
        print(f"  Loaded {len(events) - count_before:,} events from {fpath}")

    events.sort(key=lambda e: e.get("ts", 0))
    print(f"Total events loaded: {len(events):,}")
    return events


def stream_events(events: list[dict], producer: Producer, speed_multiplier: float):
    """Stream events to Kafka, respecting relative timestamps."""
    if not events:
        print("No events to stream.")
        return

    first_event_ts = events[0].get("ts", 0) / 1000  # ms → seconds
    stream_start = time.time()
    sent = 0

    print(f"Streaming {len(events):,} events to Kafka...")
    print(f"Speed multiplier: {speed_multiplier}x real time" if speed_multiplier > 0 else "Speed: unlimited")

    for event in events:
        event_ts = event.get("ts", 0) / 1000
        elapsed_event_time = event_ts - first_event_ts

        if speed_multiplier > 0:
            target_wall_time = stream_start + (elapsed_event_time / speed_multiplier)
            sleep_for = target_wall_time - time.time()
            if sleep_for > 0:
                time.sleep(sleep_for)

        topic = event.pop("_topic", "listen_events")
        key = str(event.get("userId", "")).encode()
        value = json.dumps(event).encode()

        # Retry loop — if queue is full, poll to drain it then retry
        while True:
            try:
                producer.produce(topic, key=key, value=value, callback=delivery_report)
                break
            except BufferError:
                producer.poll(1)  # wait 1s for queue to drain

        sent += 1
        if sent % 5_000 == 0:
            producer.poll(0)  # drain callbacks more frequently
            ts_str = datetime.fromtimestamp(event_ts).strftime("%Y-%m-%d %H:%M:%S")
            print(f"  Sent {sent:,} events | Current event time: {ts_str}")

    producer.flush()
    elapsed = time.time() - stream_start
    print(f"Done. Streamed {sent:,} events in {elapsed:.1f}s ({sent/elapsed:,.0f} eps)")


def main():
    parser = argparse.ArgumentParser(description="Stream eventsim output to Kafka")
    parser.add_argument("--output-dir", default="../output", help="Directory with eventsim JSON files")
    parser.add_argument("--broker", default="localhost:9092", help="Kafka broker address")
    parser.add_argument("--speed-multiplier", type=float, default=100,
                        help="Playback speed vs real time (0 = unlimited)")
    args = parser.parse_args()

    producer = Producer({
        "bootstrap.servers": args.broker,
        "queue.buffering.max.messages": 1_000_000,
        "queue.buffering.max.kbytes": 512_000,
        "batch.num.messages": 10_000,
        "linger.ms": 50,
        "compression.type": "snappy",
    })

    events = load_and_sort_events(args.output_dir)
    stream_events(events, producer, args.speed_multiplier)


if __name__ == "__main__":
    main()
