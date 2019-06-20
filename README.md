### App Mesh Logs Collector
The project was created in order to retrieve logs from your AWS App Mesh resources for troubleshooting purpose.

### Collect Logs
  
  1. Download the script by running the following command:
  ```bash
  curl -O https://raw.githubusercontent.com/leandrocostam/appmesh-logs-collector/master/appmesh-logs-collector.sh
  ```
  2. Make sure the machine has the [latest version of AWS CLI installed](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html).
  3. (Kubernetes only) Make sure you are using the correct [context for your Kubernetes cluster](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html) because the script makes use of kubectl. 
  
##### App Mesh Resources

  Collect information of your App Mesh (mesh, virtual services, virtual nodes, etc) by running the following command from :
  ```bash
  appmesh-logs-collector.sh --resource=appmesh --mesh-name=<mesh-name> --region=<aws-region>
  ```
  *Run from: Any OS Linux with AWS-CLI configured with permission (at least) App Mesh read access*

##### Related Resources in Amazon EKS / Kubernetes

  Collect logs of Kubernetes resources per namespace (pods,deployments,services) integrated with AWS App Mesh by running following command:
  ```bash
  appmesh-logs-collector.sh --resource=k8s --namespace=<namespace>
  ```

##### Related Resources in Amazon EC2
  
  Collect all information of your mesh resources running in Amazon EC2 by running the following command:
  ```bash
  $ sudo bash appmesh-logs-collector.sh --resource=ec2
  ```

## Script Options

  ```bash
  $ sudo bash appmesh-logs-collector.sh --help
  ```

## Contribuite 
