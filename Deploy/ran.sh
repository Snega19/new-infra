#!/bin/bash
sudo helm repo add openverso https://gradiant.github.io/openverso-charts/
sudo helm install ueransim-gnb openverso/ueransim-gnb --version 0.2.2 --values https://gradiant.github.io/openverso-charts/docs/open5gs-ueransim-gnb/gnb-ues-values.yaml