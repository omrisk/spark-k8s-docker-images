# spark-docker-base-images

![docker](https://img.shields.io/badge/docker-%3E=_19.03.13-brightgreen.svg?style=flat&logo=docker)

## Prerequisites

* [Docker Engine](https://docs.docker.com/engine/install/) version 20.10.5
* [bash](https://www.gnu.org/software/bash/) - tested on version 5.1.4

## Background

This repository provides tools to build base Spark docker images
for local and k8s deployments.

Since running Spark on k8s requires building from source and resolving class path conflicts,
this repository will support various versions and modes in a reusable fashion
by creating base docker images that are ready to use once your application is supplied.

This repository provides a workflow to allow building new docker images for spark as they are released.

## Quick start

Build k8s ready spark image using the default spark version.
Supported versions are listed in `dev-scripts/spark-versions-deps.json`.

```shell
./dev-scripts/builder.sh -a
```

Start up a containerized mvn shell by running:

```shell
docker-compose run mvn
```

## Setup workspace and build

Building Spark docker images requires building from source, run the following locally or in containerized build:

```shell
docker-compose run mvn
./dev-script/builder.sh -a
```

## Updating dependencies

When new spark versions are released, the `.github/dependabot.yml` will create a pull request based off the `pom.xml`.

New spark versions need to be added to the `dev-scripts/spark-versions-deps.json` according to any needed dependencies.

### Print help

```shell
./dev-scripts/builder.sh -h
```

### Setup workspace by Spark version

```shell
./dev-scripts/builder.sh -v 3.0.2
```

### Build Spark Jars

```shell
./dev-scripts/builder.sh -b
```

### Build And publish docker images

This requires the *Build jars* step to have completed successfully.
Replace the `<Repository path>` with your docker repository URL, leaving this empty will build a local image.

```shell
./dev-scripts/builder.sh -d <Repository path>
```

## Run MarkDown lint

```shell
docker-compose run md_lint
```
