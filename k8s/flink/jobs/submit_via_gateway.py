#!/usr/bin/env python3
"""
Submit kafka-to-iceberg.sql to the Flink SQL Gateway one statement at a time.
Runs INSIDE the JobManager pod where the gateway is on localhost:8083.
"""

import json
import sys
import time
import urllib.error
import urllib.request

GATEWAY = "http://localhost:8083"
SQL_FILE = sys.argv[1] if len(sys.argv) > 1 else "/tmp/kafka-to-iceberg.sql"

# ── HTTP helpers ─────────────────────────────────────────────────────────────

def http(method, path, body=None):
    data = json.dumps(body).encode("utf-8") if body is not None else None
    headers = {"Content-Type": "application/json"} if data else {}
    req = urllib.request.Request(
        f"{GATEWAY}{path}", data=data, headers=headers, method=method
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        print(f"HTTP {e.code} {method} {path}: {body}", file=sys.stderr)
        raise


# ── SQL file splitter ────────────────────────────────────────────────────────

def split_statements(sql):
    """Split on ';' respecting -- comments, /* */ blocks, strings, backticks."""
    stmts, buf = [], []
    i, n = 0, len(sql)
    while i < n:
        c = sql[i]
        if c == "-" and sql[i : i + 2] == "--":          # single-line comment
            end = sql.find("\n", i)
            end = end if end != -1 else n
            buf.append(sql[i:end])
            i = end
        elif c == "/" and sql[i : i + 2] == "/*":         # block comment
            end = sql.find("*/", i + 2)
            end = (end + 2) if end != -1 else n
            buf.append(sql[i:end])
            i = end
        elif c == "'":                                      # string literal
            j = i + 1
            while j < n:
                if sql[j] == "'" and (j + 1 >= n or sql[j + 1] != "'"):
                    break
                j += 1
            buf.append(sql[i : j + 1])
            i = j + 1
        elif c == "`":                                      # backtick identifier
            j = sql.find("`", i + 1)
            j = j if j != -1 else n - 1
            buf.append(sql[i : j + 1])
            i = j + 1
        elif c == ";":                                      # statement boundary
            stmt = "".join(buf).strip()
            if stmt:
                stmts.append(stmt)
            buf = []
            i += 1
        else:
            buf.append(c)
            i += 1
    stmt = "".join(buf).strip()
    if stmt:
        stmts.append(stmt)
    return stmts


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    # 1. Open a session
    print("Opening gateway session …")
    session = http("POST", "/v1/sessions")["sessionHandle"]
    print(f"  session: {session}\n")

    # 2. Read and split SQL
    with open(SQL_FILE) as f:
        sql = f.read()
    statements = [s for s in split_statements(sql) if s]

    print(f"Found {len(statements)} statements to execute.\n")

    # 3. Submit each statement
    for idx, stmt in enumerate(statements, 1):
        preview = stmt.replace("\n", " ")[:72]
        print(f"[{idx}/{len(statements)}] {preview}")

        op = http(
            "POST",
            f"/v1/sessions/{session}/statements",
            {"statement": stmt},
        )["operationHandle"]

        is_insert = stmt.lstrip().upper().startswith("INSERT")

        if is_insert:
            # Streaming jobs never reach FINISHED — submit and move on
            print(f"  → streaming job submitted (op: {op})\n")
            continue

        # Poll DDL/SET statements until done
        status = "RUNNING"
        while status in ("RUNNING", "INITIALIZED"):
            time.sleep(1)
            status = http(
                "GET",
                f"/v1/sessions/{session}/operations/{op}/status",
            )["status"]

        if status != "FINISHED":
            print(f"  ERROR: operation ended with status '{status}'", file=sys.stderr)
            try:
                detail = http(
                    "GET",
                    f"/v1/sessions/{session}/operations/{op}/result/0",
                )
                print(f"  detail: {json.dumps(detail, indent=2)}", file=sys.stderr)
            except Exception:
                pass
            sys.exit(1)

        print(f"  → {status}\n")

    print("All statements submitted successfully.")
    print("The 4 INSERT streaming jobs are now running on the cluster.")
    # Do NOT close the session — closing it cancels the running INSERT jobs


if __name__ == "__main__":
    main()
