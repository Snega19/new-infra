#!/bin/bash
sudo apt update
sudo helm repo add openverso https://gradiant.github.io/openverso-charts/
sudo helm install open5gs openverso/open5gs --version 2.0.8 --values https://gradiant.github.io/openverso-charts/docs/open5gs-ueransim-gnb/5gSA-values.yaml 