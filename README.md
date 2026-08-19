# CI/CD Pipeline for a Java Maven Application with Jenkins and Amazon EKS

## Project Overview

This project demonstrates an end-to-end CI/CD workflow for building and deploying a Java Maven application to Amazon EKS.

Jenkins automates the application delivery process by incrementing the application version, building and testing the application with Maven, creating a Docker image, pushing the image to a private Amazon ECR repository, and deploying the application to Amazon EKS.

The EKS infrastructure was provisioned separately with Terraform and reused for this deployment.

### CI/CD Workflow

```text
GitHub
   |
   v
Jenkins
   |
   +--> Increment Version
   |
   +--> Build & Test with Maven
   |
   +--> Build Docker Image
   |
   +--> Push Image to Amazon ECR
   |
   +--> Deploy to Amazon EKS
   |
   +--> Commit Version Update
   |
   v
Amazon EKS
   |
   v
Java Application
```

---

## Repository Structure

```text
java-maven-app/
├── Jenkinsfile
├── Dockerfile
├── pom.xml
├── kubernetes/
│   ├── deployment.yaml
│   └── service.yaml
├── src/
│   ├── main/
│   └── test/
├── docker-compose.yaml
├── server-cmds.sh
└── .gitignore
```

The `docker-compose.yaml` and `server-cmds.sh` files are from an earlier deployment approach where the application was deployed to an EC2 server. The current implementation deploys the application to Amazon EKS.

---

## Technologies Used

- Jenkins
- Java 17
- Maven
- Spring Boot
- Docker
- Amazon ECR
- Amazon EKS
- Kubernetes
- Terraform
- AWS CLI
- kubectl
- Git
- GitHub

---

## Jenkins CI/CD Pipeline

The `Jenkinsfile` defines the complete application delivery process.

### 1. Increment Application Version

The first stage increments the Maven application version and combines it with the Jenkins build number to create a unique Docker image tag.

```groovy
env.IMAGE_NAME = "$version-$BUILD_NUMBER"
```

For example:

```text
Application version: 1.1.4
Jenkins build number: 1
Docker image tag: 1.1.4-1
```

This makes each application image traceable to a specific Jenkins build.

### 2. Build and Test the Application

Jenkins builds the application using:

```bash
mvn clean package
```

This compiles the application, runs the unit tests, and creates the JAR required for the Docker image.

The verified build completed with:

```text
Tests run: 1, Failures: 0, Errors: 0, Skipped: 0

BUILD SUCCESS
```

### 3. Build and Push the Docker Image

After the Maven build succeeds, Jenkins authenticates to the private Amazon ECR registry using AWS credentials stored in Jenkins.

```bash
aws ecr get-login-password --region "$AWS_DEFAULT_REGION" |
docker login \
    --username AWS \
    --password-stdin "$DOCKER_REPO_SERVER"
```

The application image is then built and pushed:

```bash
docker build -t "$DOCKER_REPO:$IMAGE_NAME" .
docker push "$DOCKER_REPO:$IMAGE_NAME"
```

A successfully deployed image was:

```text
555175526044.dkr.ecr.us-east-2.amazonaws.com/java-maven-app:1.1.4-1
```

### 4. Deploy to Amazon EKS

Before deploying, Jenkins updates its kubeconfig for the target cluster:

```bash
aws eks update-kubeconfig \
    --region "$AWS_DEFAULT_REGION" \
    --name myapp-eks-cluster
```

Jenkins then substitutes the pipeline environment variables into the Kubernetes manifests and applies them:

```bash
envsubst < kubernetes/deployment.yaml | kubectl apply -f -
envsubst < kubernetes/service.yaml | kubectl apply -f -
```

Variables such as:

```text
$APP_NAME
$DOCKER_REPO
$IMAGE_NAME
```

are therefore populated dynamically during deployment.

### 5. Commit the Version Update

After the deployment, Jenkins commits the updated Maven version back to the `jenkins-jobs` branch.

```bash
git add pom.xml
git commit -m "ci: version bump"
git push origin HEAD:jenkins-jobs
```

Only `pom.xml` is staged so that generated build files or unrelated workspace changes are not included in the automated commit.

---

## Terraform EKS Infrastructure

The Amazon EKS cluster used by this pipeline was provisioned separately with Terraform.

The Terraform configuration provisions the supporting AWS infrastructure, including the VPC, subnets, EKS cluster, managed worker nodes, IAM roles, and networking configuration.

Reusing the existing Terraform configuration made it possible to recreate the Kubernetes environment without manually rebuilding the cluster.

The cluster used for the application deployment was:

```text
myapp-eks-cluster
```

The cluster contained three managed worker nodes, which were verified with:

```bash
kubectl get nodes
```

All three nodes reported a `Ready` status.

---

## Private ECR Authentication

This project uses a private Amazon ECR repository for application images.

There are two sides to the authentication:

```text
Jenkins ---- push ----> Amazon ECR
                         |
                         | pull
                         v
                     EKS Nodes
```

Jenkins authenticates to ECR at runtime with `aws ecr get-login-password` before pushing the image.

For the pull operation, the Terraform-provisioned EKS worker-node IAM role contains:

```text
AmazonEC2ContainerRegistryReadOnly
```

This allows the worker nodes to pull the private application image directly from ECR.

An earlier version of the Kubernetes Deployment used:

```yaml
imagePullSecrets:
  - name: aws-registry-key
```

This was no longer required for the Terraform-provisioned EKS environment because the managed worker nodes already had the required ECR permissions through IAM.

---

## Kubernetes Deployment

The Kubernetes configuration is stored in the `kubernetes/` directory.

### Deployment

The Deployment runs two replicas of the application:

```yaml
spec:
  replicas: 2
```

The container image is supplied dynamically by Jenkins:

```yaml
containers:
  - name: $APP_NAME
    image: $DOCKER_REPO:$IMAGE_NAME
    imagePullPolicy: Always
    ports:
      - containerPort: 8080
```

### Service

The application is exposed internally using a Kubernetes `ClusterIP` Service:

```yaml
ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
```

This routes traffic from Service port `80` to application port `8080`.

---

## Deployment Verification

After the pipeline deployment, the application resources were verified directly from the EKS cluster.

### Worker Nodes

```bash
kubectl get nodes
```

The cluster showed three worker nodes in `Ready` state.

### Application Pods

```bash
kubectl get pods
```

returned:

```text
java-maven-app-55f88b7b4-lxw5z   1/1   Running
java-maven-app-55f88b7b4-sk48k   1/1   Running
```

Both replicas were successfully running.

Using:

```bash
kubectl get pods -o wide
```

also showed that the two replicas were scheduled on different worker nodes.

### Private ECR Image Pull

A pod inspection showed:

```text
Image:
555175526044.dkr.ecr.us-east-2.amazonaws.com/java-maven-app:1.1.4-1

State: Running
Ready: True
Restart Count: 0
```

The pod events also reported:

```text
Successfully pulled image
Created container
Started container
```

This confirmed that the EKS worker node successfully pulled the private application image from Amazon ECR.

### Kubernetes Service

```bash
kubectl get svc
```

returned:

```text
NAME             TYPE        CLUSTER-IP       PORT(S)
java-maven-app   ClusterIP   172.20.254.56    80/TCP
```

---

## Application Connectivity Test

Because the Service is a `ClusterIP`, connectivity was first tested from inside the Kubernetes cluster.

A temporary curl pod was created:

```bash
kubectl run curl-java \
  --image=curlimages/curl \
  --restart=Never \
  --command -- \
  curl -v --max-time 10 http://java-maven-app
```

The response showed:

```text
Host java-maven-app:80 was resolved.
Trying 172.20.254.56:80...
Established connection to java-maven-app
```

This verified Kubernetes DNS resolution and Service-to-Pod connectivity.

The application returned HTTP `404` for `/`. This was expected because the current application does not define an HTTP endpoint for the root path.

Local connectivity was also tested using:

```bash
kubectl port-forward svc/java-maven-app 8080:80
```

followed by:

```bash
curl http://localhost:8080
```

The request successfully reached the application.

---

## Troubleshooting and Improvements

Several issues were identified and corrected while completing the pipeline.

### Expired ECR Authentication

The previous ECR authentication token had expired.

The pipeline was updated to generate a fresh ECR authorization token during every build using:

```bash
aws ecr get-login-password
```

### Stale EKS Kubeconfig

The Jenkins environment still referenced an older cluster named:

```text
demo-cluster
```

which no longer existed.

The deployment stage was updated to explicitly configure access to:

```text
myapp-eks-cluster
```

using `aws eks update-kubeconfig`.

### ECR Image Pull Authentication

The previous Kubernetes configuration relied on an `imagePullSecret`.

After checking the Terraform-provisioned node-group IAM role, the worker nodes were found to already have `AmazonEC2ContainerRegistryReadOnly`.

The old `imagePullSecrets` configuration was therefore no longer required.

### Maven Build Artifacts in Git

Files under `target/` had previously been committed to the repository even though `target` was listed in `.gitignore`.

They were removed from Git tracking with:

```bash
git rm -r --cached target
```

The Jenkins version commit was also changed from:

```bash
git add .
```

to:

```bash
git add pom.xml
```

to prevent generated build artifacts from being included in future automated commits.

---

## Infrastructure Cleanup

After verifying the application deployment, the application resources were removed:

```bash
kubectl delete deployment java-maven-app
kubectl delete service java-maven-app
kubectl delete pod curl-java --ignore-not-found
```

Because the EKS infrastructure was provisioned with Terraform, the infrastructure can also be removed using:

```bash
terraform plan -destroy
terraform destroy
```

This allows both infrastructure creation and cleanup to remain controlled through Infrastructure as Code.

---

## What I Learned

This project strengthened my understanding of how Jenkins, Maven, Docker, Amazon ECR, Terraform, and Kubernetes work together in a complete CI/CD workflow.

I also gained practical experience troubleshooting authentication between Jenkins and AWS, managing private ECR image access, dynamically deploying versioned application images to EKS, testing Kubernetes networking, and keeping generated build artifacts out of source control.

The final separation of responsibilities is:

```text
Terraform    -> Infrastructure Provisioning
Jenkins      -> CI/CD Automation
Maven        -> Build and Test
Docker       -> Application Packaging
Amazon ECR   -> Private Image Registry
Amazon EKS   -> Kubernetes Runtime
GitHub       -> Source Control
```