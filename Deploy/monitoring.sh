#!/bin/bash
sudo helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
sudo helm repo add stable https://charts.helm.sh/stable
sudo helm repo update
sudo helm install prometheus prometheus-community/kube-prometheus-stack