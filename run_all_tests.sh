#!/bin/bash
set -e

testvms="ratishddslowdown"

if [[ $1 == "build" ]]; then
  # build everything
  echo "============================================"
  echo "Building the ratistest VM:"
  echo "============================================"
  vagrant up ratistest
  vagrant package ratistest --output $(dirname ${BASH_SOURCE[0]})/ratistest.box
  vagrant suspend ratistest

  echo "============================================"
  echo "Building the test-suite VMs:"
  echo "============================================"
  for vm in $testvms; do
    echo "============================================"
    echo "Building test-suite VM: $vm"
    echo "============================================"
    vagrant up $vm
    vagrant suspend $vm 
  done
  echo "============================================"
  echo "Build complete"
  echo "============================================"
elif [[ $1 == "clean" ]]; then
  echo "============================================"
  echo "Cleaning-up all test artifacts"
  echo "============================================"
  vagrant destroy ratistest || true
  for vm in $testvms; do
    vagrant destroy $vm || true
  done
  vagrant box remove ratistest
  rm -f $(dirname ${BASH_SOURCE[0]})/ratistest.box
  echo "============================================"
  echo "Clean-up complete"
  echo "============================================"
else
  echo "$(basename $0): Usage: $(basename $0) build"
  echo "                       $(basename $0) clean"
fi
