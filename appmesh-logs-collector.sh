#!/usr/bin/env bash

export LANG="C"
export LC_ALL="C"

readonly PROGRAM_VERSION="0.0.1"
readonly PROGRAM_SOURCE="https://github.com/leandrocostam/appmesh-logs-collector"
readonly PROGRAM_NAME="appmesh-logs-collector"
readonly PROGRAM_DIR="/opt/appmesh-logs-collector"
readonly COLLECT_DIR="/tmp/${PROGRAM_NAME}"

REQUIRED_UTILS=(
    tar
    date
    mkdir
    jq
)

APPMESH_COMMON_RESOURCES=(
    virtual_services
    virtual_nodes
    virtual_routers
)

function help {
    echo "usage: $0 [options]"
    echo ""
    echo "-h,--help print this help"
    echo "--resource (appmesh|k8s|ec2)"
    echo "--resource \"appmesh\" --mesh-name <name-mesh> --region <aws-region>"
    echo "--resource \"k8s\" --namespace <namespace>"
    echo "--resource \"ec2\""
    echo ""
    echo "Default values:"
    echo "--region: us-east-1"
    echo "--namespace: default"
}

POSITIONAL=()

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -h|--help)
            help
            exit 1
            ;;
        --resource)
            RESOURCE="$2"
            shift
            shift
            ;;
        --mesh-name)
            MESH_NAME=$2
            shift
            shift
            ;;
        --region)
            AWS_REGION=$2
            shift
            shift
            ;;
        --namespace)
            K8S_NAMESPACE=$2
            shift
            shift
            ;;
        *)
            POSITIONAL+=("$1")
            shift 
            ;;
    esac
done

set +u
set -- "${POSITIONAL[@]}"
set -u

RESOURCE="${RESOURCE:-}"
MESH_NAME="${MESH_NAME:-}"
AWS_REGION="${AWS_REGION:-us-east-1}"
K8S_NAMESPACE="${K8S_NAMESPACE:-default}"

## Check--resource parameter
if [ -z "${RESOURCE}" ]; then
    echo -e "Error: The parameter --resource is not defined. Check --help for help."
    exit  1
fi

function check_appmesh() {
    echo -e "Checking App Mesh..."

    ## Check if mesh exists 
    EXEC=$(aws appmesh list-meshes --output text --query "meshes[?meshName == '${MESH_NAME}'].meshName" --region=${AWS_REGION})
    if ! [ $? -eq 0 ]; then
        echo -e "Error: Check mesh name failed!"
        exit 1
    fi
    ## Check if the mesh name is valid!
    if [ "${EXEC}" != "${MESH_NAME}" ]; then
        echo "${EXEC}"
        echo -e "Error: Check mesh name failed! The mesh name \"${MESH_NAME}\" not found in ${AWS_REGION} region."
        exit 1
    else
        echo -e "Mesh name \"${MESH_NAME}\" found in ${AWS_REGION} region." 
    fi
}

function collect_appmesh_mesh() {
    echo -e "Collecting App Mesh settings..."
    EXEC=$(aws appmesh describe-mesh --mesh-name ${MESH_NAME} --region=${AWS_REGION})
    if ! [ $? -eq 0 ]; then
        echo -e "Error: Collect mesh settings has failed!"
        exit 1
    else 
        if [ -n "${EXEC}" ]; then
            echo ${EXEC} | jq . > "${COLLECT_DIR}/${MESH_NAME}/${MESH_NAME}.json"
        fi
    fi

}

function collect_appmesh_virtual_services() {
    echo "Collecting App Mesh Virtual Services..."
    VS=$(aws appmesh list-virtual-services --mesh-name ${MESH_NAME} --output text --query "virtualServices[*].virtualServiceName" --region=${AWS_REGION})
    if ! [ $? -eq 0 ]; then
        echo -e "Error: Check virtual services has failed!"
        cleanup
        exit 1
    fi
    if [ -n "${VS}" ]; then
        for vs_item in ${VS}; do
            VSOUTPUT=$(aws appmesh describe-virtual-service --mesh-name ${MESH_NAME} --virtual-service-name ${vs_item} --region=${AWS_REGION})
            if [ -n "${VSOUTPUT}" ]; then
                echo ${VSOUTPUT} | jq . > "${COLLECT_DIR}/${MESH_NAME}/virtual_services/${vs_item}.json"
            fi
        done
    fi
}

function collect_appmesh_virtual_nodes() {
    echo -e "Collecting App Mesh Virtual Nodes..."
    VN=$(aws appmesh list-virtual-nodes --mesh-name ${MESH_NAME} --output text --query "virtualNodes[*].virtualNodeName" --region=${AWS_REGION})
    if ! [ $? -eq 0 ]; then
        echo -e "Error: Check virtual nodes has failed!"
        cleanup
        exit 1
    fi
    if [ -n "${VN}" ]; then
        for vn_item in ${VN}; do
            VNOUTPUT=$(aws appmesh describe-virtual-node --mesh-name ${MESH_NAME} --virtual-node-name ${vn_item} --region=${AWS_REGION})
            if [ -n "${VNOUTPUT}" ]; then
                echo ${VNOUTPUT} | jq . > "${COLLECT_DIR}/${MESH_NAME}/virtual_nodes/${vn_item}.json"
            fi
        done
    fi
}

function collect_appmesh_virtual_routers() {
    echo -e "Collecting App Mesh Virtual Routers..."
    VR=$(aws appmesh list-virtual-routers --mesh-name ${MESH_NAME} --output text --query "virtualRouters[*].virtualRouterName" --region=${AWS_REGION})
    if ! [ $? -eq 0 ]; then
        echo -e "Error: Check virtual routers has failed!"
        cleanup
        exit 1
    fi
    if [ -n "${VR}" ]; then
        for vr_item in ${VR}; do
            VROUTPUT=$(aws appmesh describe-virtual-router --mesh-name ${MESH_NAME} --virtual-router-name ${vr_item} --region=${AWS_REGION})
            if [ -n "${VROUTPUT}" ]; then
                echo ${VROUTPUT} | jq . > "${COLLECT_DIR}/${MESH_NAME}/virtual_routers/${vr_item}.json"
                ## Call function appmesh_vr_list_routes in order to retrieve the list of associated routes with the virtual router
                appmesh_vr_list_routes
            fi
        done
    fi
}

function appmesh_vr_list_routes() {
    LR=$(aws appmesh list-routes --mesh-name ${MESH_NAME} --virtual-router-name ${vr_item} --output text --query "routes[*].routeName" --region=${AWS_REGION})
    if ! [ $? -eq 0 ]; then
        echo -e "Error: List routers has failed!"
        cleanup
        exit 1
    fi
    if [ -n "${LR}" ]; then
        for lr_item in ${LR}; do
            ROUTPUT=$(aws appmesh describe-route --mesh-name ${MESH_NAME} --route-name ${lr_item} --virtual-router-name ${vr_item} --region=${AWS_REGION})
            if [ -n "${ROUTPUT}" ]; then
                echo ${ROUTPUT} | jq . >> "${COLLECT_DIR}/${MESH_NAME}/virtual_routers/${vr_item}_routes.json"
            fi
        done
    fi
}

function check_k8s_cluster() {
    echo -e "Checking Cluster configuration..."
    KCTL_CONTEXT=$(kubectl config current-context)
    echo -e ${KCTL_CONTEXT} > "${COLLECT_DIR}"/k8s_"${K8S_NAMESPACE}"/kubectl_context.txt
    echo -e "Current kubectl context: \"${KCTL_CONTEXT}\""
    echo -e "Kubernetes Namespace: ${K8S_NAMESPACE}"
    KCTL_STATUS=$(kubectl get componentstatuses)
    if ! [ $? -eq 0 ]; then
        echo -e "Error: kubectl test connection failed!"
        cleanup
        exit 1
    fi
}

function collect_k8s() {
    echo -e "Collecting related resources in Amazon EKS / Kubernetes..."
    ## List all pods with container name = envoy
    LIST_PODS=$(kubectl get pods -n ${K8S_NAMESPACE} --output json)
    PODS_WITH_ENVOY=$(echo ${LIST_PODS} | jq '.items[] | select(.spec.containers[].name=="envoy")')
    if [ -n "${PODS_WITH_ENVOY}" ]; then
        echo ${PODS_WITH_ENVOY} | jq . > "${COLLECT_DIR}"/k8s_"${K8S_NAMESPACE}"/pods_with_envoy.json
        ## Get pods name to retrieve the log from envoy containers
        PODS_NAME=$(echo ${PODS_WITH_ENVOY} | jq -s | jq -r '.[].metadata.name')
        for pod_name in ${PODS_NAME}; do
            echo -e "Collecting logs and settings from envoy container of the pod \"${pod_name}\"..."
            kubectl logs $pod_name -c envoy -n ${K8S_NAMESPACE} > "${COLLECT_DIR}/k8s_"${K8S_NAMESPACE}"/logs/${pod_name}_envoy.log" 2>&1
            kubectl exec $pod_name -c envoy -n ${K8S_NAMESPACE} -- /usr/bin/curl -s http://localhost:9901/config_dump > "${COLLECT_DIR}/k8s_"${K8S_NAMESPACE}"/logs/${pod_name}_envoy_dump.json" 2>&1
        done
    else 
        echo -e "Warning: Envoy container not found in ${K8S_NAMESPACE} namespace."
        cleanup
        exit 1
    fi
}

function collect_ec2() {
    echo -e "Collecting related resources in Amazon EC2"
}

function check_required_utils() {
  for util in ${REQUIRED_UTILS[*]}; do
    if ! command -v "${util}" >/dev/null 2>&1; then
      die "Error: App \"${util}\" not found, please install \"${util}\"."
    fi
  done
}

function check_aws_cli() {
    if ! [ -x "$(command -v aws)" ]; then
        echo -e 'Error: AWS CLI is not installed. Please install AWS CLI.' >&2
        exit 1
    fi
}

function check_kubectl() {
    if ! [ -x "$(command -v kubectl)" ]; then
        echo -e 'Error: kubectl is not installed. Please install kubectl' >&2
        exit 1
    fi
}

function create_appmesh_directories() {
  mkdir -p "${PROGRAM_DIR}"
  
  for directory in ${APPMESH_COMMON_RESOURCES[*]}; do
    mkdir -p "${COLLECT_DIR}"/"${MESH_NAME}"/"${directory}"
  done
}

function create_k8s_directories() {
  mkdir -p "${PROGRAM_DIR}" 2>&1
  
  mkdir -p "${COLLECT_DIR}"/k8s_"${K8S_NAMESPACE}"/logs 2>&1
}

function create_tar() {
  echo -e "Generating compressed file..."
  NOW=$( date '+%Y-%m-%d_%H%M-%Z' )
  FILE_NAME="${RESOURCE}_${NOW}_${PROGRAM_VERSION}.tar.gz"
  tar --create --verbose --gzip --file "${PROGRAM_DIR}"/"${FILE_NAME}" --directory="${COLLECT_DIR}" . > /dev/null 2>&1
}

function cleanup() {
  echo -e "Cleaning up temporary files..."
  rm -rf "${COLLECT_DIR}" >/dev/null 2>&1
}

function complete_collect() {
      create_tar
      cleanup
      echo -e "\nCompression completed! The file with the bundle logs is located in ${PROGRAM_DIR}/${FILE_NAME} \n"
}

function init() {

    ## Check Required Utils 
    check_required_utils

    case ${RESOURCE} in
                appmesh)
                    if [[ -n "${MESH_NAME}" ]] && [[ -n "${AWS_REGION}" ]]; then
                        echo -e "App Mesh resource selected."
                        check_aws_cli
                        create_appmesh_directories
                        check_appmesh
                        collect_appmesh_mesh
                        collect_appmesh_virtual_services
                        collect_appmesh_virtual_nodes
                        collect_appmesh_virtual_routers
                        complete_collect
                    else
                        echo -e "Error: Invalid options for --resource appmesh. Check --help for help"
                        exit 1
                    fi
                    ;;
                k8s)
                    ## Check if the resource type is k8s
                    if [[ "${RESOURCE}" = "k8s" ]] && [[ -n "${K8S_NAMESPACE}" ]]; then
                        echo -e "Kubernetes resource selected."
                        check_kubectl
                        create_k8s_directories
                        check_k8s_cluster
                        collect_k8s
                        complete_collect
                    else
                        echo -e "Error: Invalid options for --resource k8s. Check --help for help"
                        exit 1
                    fi
                    ;;
                ec2)
                    if [ "${RESOURCE}" = "ec2" ]; then
                        echo -e "EC2 resource selected."
                    fi
                    ;;
                *)
                    echo -e "Error: The --resource \"${RESOURCE}\" is not valid. Check --help for help"
                    exit 1
    esac
}

## Call init function
init
