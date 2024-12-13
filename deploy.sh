#!/bin/bash

# Check if the user is logged into Azure CLI
if ! az account show > /dev/null 2>&1; then
    echo "Please login to Azure CLI using 'az login' before running this script."
    exit 1
fi

# Create a Terraform plan
terraform plan -out main.tfplan

# Apply the Terraform plan
terraform apply main.tfplan

# Retrieve the Terraform outputs and store in variables
resource_group_name=$(terraform output -raw resource_group_name)
system_node_pool_name=$(terraform output -raw system_node_pool_name)
aks_cluster_name=$(terraform output -raw kubernetes_cluster_name)

# Get AKS credentials for the cluster
az aks get-credentials \
    --resource-group $resource_group_name \
    --name $aks_cluster_name

# Create the kuberay namespace
kuberay_namespace="kuberay"
kubectl create namespace $kuberay_namespace

# Output the current Kubernetes context
current_context=$(kubectl config current-context)
echo "Current Kubernetes Context: $current_context"

# Output the nodes in the cluster
kubectl get nodes

# Install KubeRay Helm chart
helm version
helm repo add kuberay https://ray-project.github.io/kuberay-helm/
helm repo update

helm upgrade \
--install \
--cleanup-on-fail \
--wait \
--timeout 10m0s \
--namespace "$kuberay_namespace" \
--create-namespace kuberay-operator kuberay/kuberay-operator \
--version 1.1.1

kubectl get pods -n $kuberay_namespace

# Train a PyTorch Model on Fashion MNIST

curl -LO https://raw.githubusercontent.com/ray-project/kuberay/master/ray-operator/config/samples/pytorch-mnist/ray-job.pytorch-mnist.yaml

kubectl apply -n kuberay -f ray-job.pytorch-mnist.yaml

kubectl get pods -n kuberay

