# App Mesh Logs Collector
The project was created in order to retrieve logs from your AWS App Mesh resources for troubleshooting purpose.

## Prerequisites
  
  - Make sure to have the latest version of `AWS CLI` [installed](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html) and [configured with credentials](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) that contain [IAM App Mesh permissions](https://docs.aws.amazon.com/app-mesh/latest/userguide/IAM_policies.html).
  - Make sure to have `jq` [installed](https://stedolan.github.io/jq/download/).
  - (Kubernetes only) Make sure to have `kubectl` [installed](https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html), at least version `1.11` or above. Set the correct [context for your Kubernetes cluster](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html).

## Setup
  
  Download the App Mesh Logs Collector script by running the following command:
  ```bash
  curl -O https://raw.githubusercontent.com/leandrocostam/appmesh-logs-collector/master/appmesh-logs-collector.sh
  ```
  
## Collect App Mesh Resources

  Collect information of your AWS App Mesh (mesh, virtual services, virtual nodes, etc) by running the following command:
  ```bash
  sudo bash appmesh-logs-collector.sh --resource appmesh --mesh-name <mesh-name> --region <aws-region>
  ```

## Collect Related Resources in Amazon EKS / Kubernetes

  Collect logs and settings from envoy containers running on Kubernetes cluster per namespace by running the following command:
  ```bash
  sudo bash appmesh-logs-collector.sh --resource k8s --namespace <namespace>
  ```

## Collect Related Resources in Amazon EC2 (not ready)
  
  Collect all information of your App Mesh resources running in your Amazon EC2 by running the following command from the EC2 instance:
  ```bash
  $ sudo bash appmesh-logs-collector.sh --resource ec2
  ```

## Script Options

  ```bash
  $ sudo bash appmesh-logs-collector.sh --help
  usage: appmesh-logs-collector.sh [options]

  -h,--help print this help
  --resource (appmesh|k8s|ec2)
  --resource "appmesh" --mesh-name <name-mesh> --region <aws-region>
  --resource "k8s" --namespace <namespace>
  --resource "ec2"

  Default values:
  region: us-east-1
  namespace: default
  ```

## Contribuite

Please, feel free to place a pull request whether something is not up-to-date, should be added, fixed, or contains wrong information/reference.
