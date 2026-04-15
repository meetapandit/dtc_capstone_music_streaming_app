from diagrams import Cluster, Diagram, Edge
from diagrams.gcp.analytics import BigQuery, Composer, Looker
from diagrams.gcp.storage import GCS
from diagrams.onprem.analytics import Flink, Dbt
from diagrams.onprem.iac import Terraform
from diagrams.onprem.queue import Kafka
from diagrams.programming.language import Python

graph_attr = {
    "rankdir": "LR",        # strict left-to-right
    "splines": "ortho",     # right-angle edges, cleaner layout
    "nodesep": "0.8",       # horizontal spacing between nodes
    "ranksep": "1.2",       # spacing between pipeline stages
    "pad": "0.5",
}

with Diagram(
    "BeatStream Analytics Architecture",
    show=False,
    graph_attr=graph_attr,
    filename="beatstream_architecture",
):
    producer = Python("Eventsim\nProducer")

    with Cluster("Terraform — Infrastructure as Code"):
        with Cluster("GKE"):
            kafka  = Kafka("Strimzi\nKafka")
            flink  = Flink("Flink\nStream Processing")

        with Cluster("Data Lakehouse"):
            iceberg = GCS("Iceberg\non GCS")

        with Cluster("BigQuery"):
            bronze   = BigQuery("Bronze\n(External Iceberg)")
            dbt_tool = Dbt("dbt\nSilver / Gold")

        with Cluster("Orchestration"):
            composer = Composer("Cloud Composer\n(Airflow WAP DAG)")

        tf = Terraform("Terraform")

    viz = Looker("Looker Studio\nDashboards")

    # Main pipeline — straight line left to right
    producer >> kafka >> flink >> iceberg >> bronze >> dbt_tool >> viz

    # Composer triggers dbt
    composer >> Edge(style="dashed") >> dbt_tool

    # Terraform provisions all infra (dashed)
    tf >> Edge(style="dashed", color="orange") >> kafka
    tf >> Edge(style="dashed", color="orange") >> iceberg
    tf >> Edge(style="dashed", color="orange") >> bronze
    tf >> Edge(style="dashed", color="orange") >> composer
