"""
music_streaming_dbt.py
WAP pipeline with gold readiness signal for Looker.

Flow:
    1. dbt run silver  --target staging   → silver_staging       (Write)
    2. dbt test silver --target staging   → validate             (Audit)
    3. promote silver_staging → silver                           (Publish)
    4. dbt run gold    --target dev       → gold tables
    5. dbt test gold   --target dev       → validate gold
    6. dbt run gold_pipeline_status       → writes readiness signal to BigQuery
       ↑
       Looker datagroup polls gold.pipeline_status.refreshed_at
       and only serves dashboards / rebuilds PDTs when is_ready = TRUE.

If any step fails, pipeline_status is NOT updated → Looker keeps serving
the last known-good snapshot.
"""

from datetime import datetime, timedelta, timezone

from airflow import DAG
from airflow.datasets import Dataset
from airflow.operators.bash import BashOperator

PROJECT  = "dtc-capstone-491118"
LOCATION = "us-west1"
DBT_DIR  = "/home/airflow/gcs/dags/dbt"

SILVER_TABLES = [
    "silver_listen_events",
    "silver_auth_events",
    "silver_page_view_events",
    "silver_status_change_events",
]

GOLD_TABLES = [
    "gold_daily_listening_stats",
    "gold_top_artists_daily",
    "gold_top_songs_daily",
    "gold_hourly_listening_heatmap",
    "gold_user_activity_daily",
    "gold_qoq_listener_growth",
]

# Airflow Dataset — downstream DAGs (e.g. a Looker API refresh DAG) can
# declare `schedule=[GOLD_READY]` to trigger automatically when this is emitted.
GOLD_READY = Dataset(f"bigquery://{PROJECT}/gold/pipeline_status")


def _promote_silver_cmds():
    cmds = [
        f"bq --location={LOCATION} cp -f "
        f"{PROJECT}:silver_staging.{table} "
        f"{PROJECT}:silver.{table}"
        for table in SILVER_TABLES
    ]
    return " && ".join(cmds)


default_args = {
    "owner": "airflow",
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
    "email_on_failure": False,
}

with DAG(
    dag_id="music_streaming_dbt_wap",
    description="WAP: bronze → silver_staging → silver → gold → pipeline_status (Looker signal)",
    schedule_interval="0 */6 * * *",
    start_date=datetime(2026, 4, 10, tzinfo=timezone.utc),
    catchup=False,
    default_args=default_args,
    tags=["dbt", "music-streaming", "wap"],
) as dag:

    # ── WRITE ─────────────────────────────────────────────────────────────────
    dbt_run_silver_staging = BashOperator(
        task_id="dbt_run_silver_staging",
        bash_command=(
            f"dbt run "
            f"--project-dir {DBT_DIR} "
            f"--profiles-dir {DBT_DIR} "
            f"--target staging "
            f"--select silver"
        ),
    )

    # ── AUDIT ─────────────────────────────────────────────────────────────────
    dbt_test_silver_staging = BashOperator(
        task_id="dbt_test_silver_staging",
        bash_command=(
            f"dbt test "
            f"--project-dir {DBT_DIR} "
            f"--profiles-dir {DBT_DIR} "
            f"--target staging "
            f"--select silver"
        ),
    )

    # ── PUBLISH ───────────────────────────────────────────────────────────────
    promote_silver = BashOperator(
        task_id="promote_silver_to_prod",
        bash_command=_promote_silver_cmds(),
    )

    # ── GOLD ──────────────────────────────────────────────────────────────────
    dbt_run_gold = BashOperator(
        task_id="dbt_run_gold",
        bash_command=(
            f"dbt run "
            f"--project-dir {DBT_DIR} "
            f"--profiles-dir {DBT_DIR} "
            f"--target dev "
            f"--select gold"
        ),
    )

    dbt_test_gold = BashOperator(
        task_id="dbt_test_gold",
        bash_command=(
            f"dbt test "
            f"--project-dir {DBT_DIR} "
            f"--profiles-dir {DBT_DIR} "
            f"--target dev "
            f"--select gold"
        ),
    )

    # ── SIGNAL: write readiness to BigQuery, emit Airflow Dataset event ───────
    # Only runs if dbt_test_gold passes — Looker polls this table via datagroup.
    write_gold_status = BashOperator(
        task_id="write_gold_status",
        bash_command=(
            f"dbt run "
            f"--project-dir {DBT_DIR} "
            f"--profiles-dir {DBT_DIR} "
            f"--target dev "
            f"--select gold_pipeline_status"
        ),
        outlets=[GOLD_READY],   # emits Dataset event for downstream DAGs
    )

    # ── DAG dependencies ──────────────────────────────────────────────────────
    (
        dbt_run_silver_staging
        >> dbt_test_silver_staging
        >> promote_silver
        >> dbt_run_gold
        >> dbt_test_gold
        >> write_gold_status
    )
