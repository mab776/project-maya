#!/bin/sh
# mab776 trial launcher (v1.0.16 worktree; venv + vision borrowed from ../project-maya): Project Maya (GLM-5.3-Flash, Maya-S) on GPUs 0+1 = the best config (split 40, see README; MAYA_GPUS=0 for one GPU), http://192.168.0.70:8325
# ⚠️ ONLY with strata-coder STOPPED: the engine pins all free RAM but ~6 GB for its expert tier.
# Stop: docker stop maya-glm (the container is --rm).  Log: maya-trial.log
cd "$(dirname "$0")" || exit 1
if docker ps --format '{{.Names}}' | grep -qx strata-coder; then echo "strata-coder is running - stop it first"; exit 1; fi
exec docker run -d --rm --name maya-glm --runtime nvidia -e NVIDIA_VISIBLE_DEVICES=${MAYA_GPUS:-0,1} -e NVIDIA_DRIVER_CAPABILITIES=compute,utility \
  --ulimit memlock=-1 --shm-size 1g -p 8325:8325 -u 1000:1000 -e HOME=/tmp \
  -v "$PWD":/maya -v "$PWD/../project-maya/.venv-docker":/maya/.venv-docker:ro -v "$PWD/../project-maya/build-vision":/maya/build-vision:ro -v "/media/mab776/nvme 2To/models/maya":/models:ro -v "/media/mab776/nvme 2To/models/maya/slots":/slots -w /maya \
  maya-runtime:cu128 \
  /maya/.venv-docker/bin/python /maya/serve/server.py --engine strata --config /maya/maya-trial.json --port 8325 --host 0.0.0.0
