---
title: Upgrade - Self-hosting
description: Upgradation of self-hosted Ente
---

# Upgrade your server

Upgrading Ente depends on the method of installation you have chosen.

## Quickstart

Upgrade and restart Ente by pulling the latest images in the directory where the Compose file resides.

The directory name is generally `my-ente`.

Run this command inside `my-ente/`

``` shell
docker compose pull && docker compose up -d
```

## Docker Compose

You can pull in the latest source code from Git and build a new cluster
based on the updated source code.

1. Pull the latest changes from `main`.

    ``` shell
    # Assuming you have cloned repository to ente
    cd ente
    # Pull changes
    git pull
    ```

2. Recreate the cluster.
    ``` shell
    cd server/config
    # Stop and remove containers if they are running
    docker compose down
    # Build with latest code
    docker compose up --build
    ```

## Manual Setup

You can pull in the latest source code from Git and build a new cluster
based on the updated source code.

1. Pull the latest changes from `main`.

    ``` shell
    # Assuming you have cloned repository to ente
    cd ente
    # Pull changes
    git pull
    ```

2. Follow the steps described in [manual setup](/self-hosting/installation/manual) for Museum and web applications.

::: tip

If using Docker, you can free up some disk space by deleting older images 
that were used by obsolette containers

``` shell
docker image prune
```
:::