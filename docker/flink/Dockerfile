FROM flink:1.18.1-scala_2.12-java11

ARG MAVEN=https://repo1.maven.org/maven2

# Kafka connector + clients
RUN curl -fsSL -o /opt/flink/lib/flink-connector-kafka.jar \
      ${MAVEN}/org/apache/flink/flink-connector-kafka/3.1.0-1.18/flink-connector-kafka-3.1.0-1.18.jar && \
    curl -fsSL -o /opt/flink/lib/kafka-clients.jar \
      ${MAVEN}/org/apache/kafka/kafka-clients/3.4.0/kafka-clients-3.4.0.jar

# Iceberg Flink runtime (includes Iceberg core + bundled deps)
RUN curl -fsSL -o /opt/flink/lib/iceberg-flink-runtime.jar \
      ${MAVEN}/org/apache/iceberg/iceberg-flink-runtime-1.18/1.5.2/iceberg-flink-runtime-1.18-1.5.2.jar

# DELETE the mkdir and the plugin path.
# MOVE it to /opt/flink/lib/
RUN curl -fsSL -o /opt/flink/lib/flink-gs-fs-hadoop.jar \
      https://repo1.maven.org/maven2/org/apache/flink/flink-gs-fs-hadoop/1.18.1/flink-gs-fs-hadoop-1.18.1.jar

# Hadoop client jars — needed by Iceberg FlinkCatalogFactory in the main classloader.
# hadoop-client-api: thin interfaces-only jar (no dep conflicts)
# hadoop-client-runtime: uber jar that bundles hadoop-common, hadoop-hdfs-client,
#   and ALL transitive deps (protobuf, guava, etc.) shaded/relocated to avoid
#   conflicts with Flink's own shaded libraries. This stops the cascade of
#   missing class errors (Configuration → HdfsConfiguration → ...).
RUN curl -fsSL -o /opt/flink/lib/hadoop-client-api.jar \
      ${MAVEN}/org/apache/hadoop/hadoop-client-api/3.3.4/hadoop-client-api-3.3.4.jar && \
    curl -fsSL -o /opt/flink/lib/hadoop-client-runtime.jar \
      ${MAVEN}/org/apache/hadoop/hadoop-client-runtime/3.3.4/hadoop-client-runtime-3.3.4.jar && \
    curl -fsSL -o /opt/flink/lib/commons-logging.jar \
      ${MAVEN}/commons-logging/commons-logging/1.2/commons-logging-1.2.jar
