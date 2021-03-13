# Set global args to pass between stages
ARG DOCKER_IMAGE_TAG
ARG HADOOP_AWS_VERSION
ARG AWS_SDK_VERSION

FROM alpine:3.13.2 as base
WORKDIR /tmp
# Redeclare so can be used in this stage
ARG HADOOP_AWS_VERSION
ARG AWS_SDK_VERSION

RUN apk add --no-cache curl bash \
    && wget https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_AWS_VERSION}/hadoop-aws-${HADOOP_AWS_VERSION}.jar \
    && wget https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_SDK_VERSION}/aws-java-sdk-bundle-${AWS_SDK_VERSION}.jar \
    # Remove bad guava version, see https://issues.apache.org/jira/browse/HIVE-22915
    && wget https://repo1.maven.org/maven2/com/google/guava/guava/27.0-jre/guava-27.0-jre.jar


FROM spark:${DOCKER_IMAGE_TAG} as prod
# Switch to root to delete files
USER 0
RUN rm -rfv /opt/spark/jars/guava-14.0.1.jar
# Switch back to spark user
USER 185
COPY --from=base /tmp/* ../jars/

