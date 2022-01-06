#!/bin/bash
#set -x

# Use this script as a starting point to create your own deployment.yml

# Make sure the cluster is running and get the ip_address
ip_addr=$(ibmcloud ks workers --cluster $PIPELINE_KUBERNETES_CLUSTER_NAME | grep normal | awk '{ print $2 }')
if [ -z $ip_addr ]; then
  echo "$PIPELINE_KUBERNETES_CLUSTER_NAME not created or workers not ready"
  exit 1
fi

# Initialize script variables
NAME="$IDS_PROJECT_NAME"
IMAGE="$PIPELINE_IMAGE_URL"
if [ -z IMAGE ]; then
  echo "$IMAGE not set. If using $PIPELINE_IMAGE_URL this variable is only configured when a "Container Registry" build job is used as the stage input."
  exit 1
fi

PORT=3838

echo ""
echo "Deploy environment variables:"
echo "NAME=$NAME"
echo "IMAGE=$IMAGE"
echo "PORT=$PORT"
echo ""

DEPLOYMENT_FILE="deployment.yml"
echo "Creating deployment file $DEPLOYMENT_FILE"

# Build the deployment file
DEPLOYMENT=$(cat <<EOF''
kind: Deployment
apiVersion: apps/v1
metadata:
  name: cd19-dashboard
  namespace: c19-dashboard
  labels:
    k8s-app: cd19-dashboard
  annotations:
    deployment.kubernetes.io/revision: '1'
spec:
  replicas: 9
  selector:
    matchLabels:
      k8s-app: cd19-dashboard
  template:
    metadata:
      name: cd19-dashboard
      labels:
        k8s-app: cd19-dashboard
    spec:
      containers:
        - name: cd19-dashboard
          image: $IMAGE
          resources: {}
          imagePullPolicy: IfNotPresent
          securityContext:
            privileged: false
          readinessProbe:
            tcpSocket:
              port: 3838
            initialDelaySeconds: 5
            periodSeconds: 10
      restartPolicy: Always
      terminationGracePeriodSeconds: 30
      dnsPolicy: ClusterFirst
      securityContext: {}
      schedulerName: default-scheduler
  imagePullSecret:
    - name: all-icr-io
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 25%
      maxSurge: 25%
  revisionHistoryLimit: 10
  progressDeadlineSeconds: 600
---
apiVersion: v1
kind: Service
metadata:
  name: $NAME
  labels:
    app: $NAME
spec:
  type: NodePort
  ports:
    - port: 3838
  selector:
    app: $NAME
EOF
)

# Substitute the variables
echo "$DEPLOYMENT" > $DEPLOYMENT_FILE
sed -i 's/$NAME/'"$NAME"'/g' $DEPLOYMENT_FILE
sed -i 's=$IMAGE='"$IMAGE"'=g' $DEPLOYMENT_FILE
sed -i 's/$PORT/'"$PORT"'/g' $DEPLOYMENT_FILE

# Show the file that is about to be executed
echo ""
echo "DEPLOYING USING MANIFEST:"
echo "cat $DEPLOYMENT_FILE"
cat $DEPLOYMENT_FILE
echo ""

# Execute the file
echo "KUBERNETES COMMAND:"
echo "kubectl apply -f $DEPLOYMENT_FILE"
kubectl apply -f $DEPLOYMENT_FILE
echo ""

echo ""
echo "DEPLOYED SERVICE:"
kubectl describe services $NAME
echo ""
echo "DEPLOYED PODS:"
kubectl describe pods --selector app=$NAME
echo ""

# # Show the IP address and the PORT of the running app
# port=$(kubectl get services | grep "$NAME " | sed 's/.*:\([0-9]*\).*/\1/g')
# echo "RUNNING APPLICATION:"
# echo "URL=http://$ip_addr"
# echo "PORT=$port"
# echo ""
# echo "$NAME running at: http://$ip_addr:$port"

