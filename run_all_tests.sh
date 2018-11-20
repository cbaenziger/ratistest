#!/bin/bash
set -e

testvms="ratisservers ratishddslowdown"

box_path=$(dirname ${BASH_SOURCE[0]})/ratistest.box

if [[ $1 == "build" ]]; then
  # build everything
  echo "============================================"
  echo "Building the ratisbuild VM:"
  echo "============================================"
  vagrant up ratisbuild --provision
  vagrant suspend ratisbuild
  [ '!' -e $box_path ] && vagrant package ratisbuild --output $box_path

  echo "============================================"
  echo "Building the test-suite VMs:"
  echo "============================================"
  for vm in $testvms; do
    echo "============================================"
    echo "Building test-suite VM: $vm"
    echo "============================================"
    vagrant up $vm --provision
    vagrant suspend $vm 
  done
  echo "============================================"
  echo "Build complete"
  echo "Run vagrant resume <vm name> to start a particular environment"
  echo "Run vagrant ssh <vm name> to enter a particular environment"
  echo "============================================"
  vagrant status
elif [[ $1 == "clean" ]]; then
  echo "============================================"
  echo "Cleaning-up all test artifacts"
  echo "============================================"
  vagrant destroy -f ratisbuild || true
  for vm in $testvms; do
    vagrant destroy -f $vm || true
  done
  vagrant box remove ratistest || true
  rm -f $box_path
  echo "============================================"
  echo "Clean-up complete"
  echo "============================================"
else
  echo "$(basename $0): Usage: $(basename $0) build"
  echo "                       $(basename $0) clean"
fi
