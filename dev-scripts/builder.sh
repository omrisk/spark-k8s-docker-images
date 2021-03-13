#!/usr/bin/env bash

DIRECTORY="spark-workspace"
REPOSITORY_URL="https://github.com/apache/spark.git"
SPARK_VERSION="${SPARK_VERSION:=3.0.2}"
SPARK_VERSION_INFO=$(cat ./dev-scripts/spark-version-deps.json | jq --arg SPARK_VERSION "${SPARK_VERSION}" '.[$SPARK_VERSION]')
HADOOP_VERSION=$(echo $SPARK_VERSION_INFO | jq -r '.HADOOP_VERSION')
HADOOP_AWS_VERSION=$(echo $SPARK_VERSION_INFO | jq -r '.HADOOP_AWS_VERSION')
AWS_SDK_VERSION=$(echo $SPARK_VERSION_INFO | jq -r '.AWS_SDK_VERSION')
DOCKER_REPOSITORY=${DOCKER_REPOSITORY}

build_jars() {
    if [[ -d "${DIRECTORY}" ]] && [[ "$(ls -A ${DIRECTORY})" ]]; then
        SPARK_VERSION=$(git --git-dir=spark-workspace/.git branch | awk '{print $5}' | cut -c 2- | cut -c -5)
        echo "Spark version ${SPARK_VERSION} is checked out"

        SPARK_VERSION_INFO=$(cat ./dev-scripts/spark-version-deps.json | jq --arg SPARK_VERSION "${SPARK_VERSION}" '.[$SPARK_VERSION]')
        echo "Spark version info: ${SPARK_VERSION_INFO}"

        HADOOP_VERSION=$(echo $SPARK_VERSION_INFO | jq -r '.HADOOP_VERSION')
        echo "Building Spark version ${SPARK_VERSION} with hadoop version ${HADOOP_VERSION}"
        cd ${DIRECTORY}
        ./dev/make-distribution.sh --tgz -Phadoop-${HADOOP_VERSION} -Phive -Pkubernetes -Pscala-2.12
        cd -
    else
        echo "No Spark workspace availble, please re-run with the '-v' flag to create it first."
    fi
}

build_docker_image() {
    VERSION="${1:-$SPARK_VERSION}"
    SPARK_VERSION_INFO=$(cat ./dev-scripts/spark-version-deps.json | jq --arg VERSION "${VERSION}" '.[$VERSION]')
    HADOOP_VERSION=$(echo $SPARK_VERSION_INFO | jq -r '.HADOOP_VERSION')

    DOCKER_IMAGE_TAG="spark-${VERSION}-hadoop-${HADOOP_VERSION}"
    echo "Building docker image: ${DOCKER_IMAGE_TAG}-local"
    cd ${DIRECTORY}
    ./bin/docker-image-tool.sh -t "${DOCKER_IMAGE_TAG}-local" build
    cd -

    HADOOP_AWS_VERSION=$(echo $SPARK_VERSION_INFO | jq -r '.HADOOP_AWS_VERSION')
    AWS_SDK_VERSION=$(echo $SPARK_VERSION_INFO | jq -r '.AWS_SDK_VERSION')

    # Add needed AWS s3 layers to Docker image
    # TODO - add auto increment to tagged version
    docker build --build-arg DOCKER_IMAGE_TAG=${DOCKER_IMAGE_TAG}-local \
                 --build-arg HADOOP_AWS_VERSION=${HADOOP_AWS_VERSION} \
                 --build-arg AWS_SDK_VERSION=${AWS_SDK_VERSION} \
                 . \
                 --tag spark:${DOCKER_IMAGE_TAG}

    if [[ -z $DOCKER_REPOSITORY ]]; then
        echo "DOCKER_REPOSITORY enviroment variable is unset, to publish please set it in the .github/ci.yml or set it locally to push to a private repo."
    else
        FULL_DOCKER_NAME="${DOCKER_REPOSITORY}/${DOCKER_IMAGE_TAG}:latest"
        echo "Publishing docker image: to repository: ${DOCKER_REPOSITORY}"
        DOCKER_IMAGE_ID=$(docker images --format="{{.Repository}} {{.ID}}" | grep spark | head -1 | cut -d ' ' -f2)
        docker tag ${DOCKER_IMAGE_ID} ${FULL_DOCKER_NAME}
        docker push ${FULL_DOCKER_NAME}
    fi

}

publish_docker_image() {
    DOCKER_IMAGE_ID=$(docker images --format="{{.Repository}} {{.ID}}" | grep spark | head -1 | cut -d ' ' -f2)
    docker tag ${DOCKER_IMAGE_ID} 
    docker push ${1}
}

clone_and_checkout() {
    if [[ ! -d "${DIRECTORY}" ]] && git clone "${REPOSITORY_URL}" "${DIRECTORY}"; then
        echo "Cloned Spark source into DIRECTORY: ${DIRECTORY}"
    fi

    cd "${DIRECTORY}"
    git reset --hard

    git pull

    git checkout "v${1:-SPARK_VERSION}"

    cd -
}

help_blurb() {
    echo "Help blurb!"
    echo "-v - Spark version you wish to setups, see https://github.com/apache/spark for supported versions."
    echo "-b - Build jars for setup version"
    echo "-d - Build docker images for set version"
    echo "-a - Checkout Spark, build jars and docker image, set docker repository URL to DOCKER_REPOSITORY enviroment variable to publish docker images to, if left empty will build locally."
}

while getopts ":v:a:bhd" opt; do
    case $opt in
    v)
        echo "Cloning and checking out Spark-${OPTARG}"
        SPARK_VERSION=${OPTARG}
        clone_and_checkout "${OPTARG}"
        exit 0
        ;;
    b)
        echo "Building jars"
        build_jars
        exit 0
        ;;
    h)
        help_blurb
        exit 0
        ;;
    d)
        echo "Building docker images"
        build_docker_image
        exit 0
        ;;
    a)
        echo "Building jars and docker images"
        echo "Cloning and checking out Spark-${OPTARG}"
        clone_and_checkout ${OPTARG}
        build_jars
        build_docker_image
        exit 0
        ;;
    *)
        echo "Bad option!"
        exit 0
        ;;
    esac
    shift $((OPTIND - 1))
done

if [[ $# -eq 0 ]]; then
    help_blurb
    exit 0
fi
