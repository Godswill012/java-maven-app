# Complete CI/CD Pipeline with Jenkins and Terraform

This project demonstrates a complete Jenkins CI/CD pipeline that integrates
application build, containerization, Docker image publishing, Infrastructure as
Code, and application deployment to AWS.

The completed Terraform-integrated CI/CD implementation is maintained in the
**`jenkinsfile-sshagent` branch** of this repository.

The project integrates:

- Jenkins
- Jenkins Shared Libraries
- Maven
- Docker
- Docker Hub
- Terraform
- AWS
- Amazon EC2
- Amazon S3
- SSH
- Docker Compose

The main goal of the project was to automate both the application delivery
process and the lifecycle of the AWS infrastructure required to host the
application.

---

## Project Architecture

```text
GitHub Repository
       |
       v
Jenkins Pipeline
       |
       v
Load Jenkins Shared Library
       |
       v
Build Java Application with Maven
       |
       v
Build Docker Image
       |
       v
godswill012/demo-app:java-maven-2.0
       |
       v
Authenticate to Docker Hub
       |
       v
Push Image to Docker Hub
       |
       v
Terraform Init / Apply
       |
       v
Provision AWS Infrastructure
       |
       +-- VPC
       +-- Subnet
       +-- Internet Gateway
       +-- Route Table
       +-- Security Group
       +-- EC2
              |
              v
       Terraform EC2 Output
              |
              v
        EC2 Public IP
              |
              v
         Jenkins SSH
              |
              v
     Copy Deployment Files
              |
              v
     Execute server-cmds.sh
              |
              v
        Docker Compose
              |
              v
      Deploy Application
```

---

## Repository Structure

```text
.
├── .gitignore
├── Dockerfile
├── Jenkinsfile
├── docker-compose.yaml
├── pom.xml
├── server-cmds.sh
└── terraform/
    ├── .terraform.lock.hcl
    ├── entry-script.sh
    ├── main.tf
    └── variables.tf
```

---

## CI/CD Pipeline

The Jenkins pipeline coordinates the application build, Docker image
publishing, infrastructure provisioning, deployment, and infrastructure
cleanup.

The pipeline is parameterized with:

```groovy
choice(
  name: 'TF_ACTION',
  choices: ['apply', 'destroy'],
  description: 'Choose whether to provision or destroy the Terraform-managed infrastructure.'
)
```

This allows the same pipeline to manage both infrastructure creation and
destruction.

When:

```text
TF_ACTION=apply
```

is selected, Jenkins builds the application, creates and publishes the Docker
image, provisions the AWS infrastructure, and deploys the application.

When:

```text
TF_ACTION=destroy
```

is selected, Jenkins skips the application build, Docker image, and deployment
stages and destroys the Terraform-managed infrastructure.

---

## Pipeline Steps

### 1. Load the Jenkins Shared Library

The Jenkinsfile loads the shared library:

```groovy
library identifier: 'jenkins-shared-library0@master', retriever: modernSCM(
  [$class: 'GitSCMSource',
  remote: 'https://github.com/Godswill012/jenkins-shared-library0.git',
  credentialsId: 'github-credentials'
  ]
)
```

The shared library provides reusable functions used by the pipeline:

```groovy
buildJar()
buildImage(env.IMAGE_NAME)
dockerLogin()
dockerPush(env.IMAGE_NAME)
```

This keeps reusable build and Docker logic outside the main Jenkinsfile.

### 2. Build the Java Application

When `TF_ACTION=apply`, Jenkins builds the Java application using Maven.

The pipeline calls:

```groovy
buildJar()
```

from the Jenkins Shared Library.

The Maven build produces the application JAR that is packaged into the Docker
image.

### 3. Build the Docker Image

The Docker image is defined in the Jenkinsfile as:

```groovy
IMAGE_NAME = 'godswill012/demo-app:java-maven-2.0'
```

Jenkins calls:

```groovy
buildImage(env.IMAGE_NAME)
```

to build and tag the application image as:

```text
godswill012/demo-app:java-maven-2.0
```

The application itself is containerized using the project `Dockerfile`:

```dockerfile
FROM amazoncorretto:17-alpine-jdk

EXPOSE 8080

COPY ./target/java-maven-app-*.jar /usr/app/
WORKDIR /usr/app

ENTRYPOINT ["java", "-jar", "java-maven-app-1.0-SNAPSHOT.jar"]
```

The image uses Amazon Corretto Java 17 and packages the Maven-generated
application JAR.

### 4. Authenticate to Docker Hub

After building the image, Jenkins authenticates to Docker Hub using credentials
managed through Jenkins rather than placing the credentials directly in the
Jenkinsfile.

The shared-library function:

```groovy
dockerLogin()
```

handles this authentication.

### 5. Push the Docker Image to Docker Hub

Jenkins then publishes the image to my Docker Hub repository using:

```groovy
dockerPush(env.IMAGE_NAME)
```

The published application image is:

```text
godswill012/demo-app:java-maven-2.0
```

The image delivery process is therefore:

```text
Maven Build
     |
     v
Application JAR
     |
     v
Docker Build
     |
     v
godswill012/demo-app:java-maven-2.0
     |
     v
Docker Hub Login
     |
     v
Push to Docker Hub
```

The published image is then available for deployment on the EC2 instance
provisioned later in the pipeline.

### 6. Initialize Terraform

The pipeline changes into the Terraform directory:

```groovy
dir('terraform')
```

and runs:

```bash
terraform init
```

This initializes the Terraform working directory and configured backend.

### 7. Provision AWS Infrastructure

For an `apply` operation, Jenkins executes:

```bash
terraform apply --auto-approve
```

AWS credentials are injected into the Terraform stage using Jenkins
Credentials:

```groovy
AWS_ACCESS_KEY_ID = credentials('jenkins_aws_access_key_id')
AWS_SECRET_ACCESS_KEY = credentials('jenkins_aws_secret_access_key')
```

The pipeline also supplies:

```groovy
TF_VAR_env_prefix = 'test'
```

to Terraform.

Terraform then provisions the AWS infrastructure required for the deployment.

### 8. Retrieve the EC2 Public IP

Terraform exposes the public IP of the provisioned EC2 instance:

```hcl
output "ec2-public_ip" {
  value = aws_instance.myapp-server.public_ip
}
```

Jenkins retrieves the value directly after `terraform apply`:

```groovy
EC2_PUBLIC_IP = sh(
  script: "terraform output ec2-public_ip",
  returnStdout: true
).trim()
```

This removes the need to manually enter or hard-code the address of the newly
created EC2 instance.

The output of the infrastructure stage therefore becomes an input to the
deployment stage:

```text
Terraform Apply
      |
      v
Create EC2 Instance
      |
      v
Terraform Output
      |
      v
EC2 Public IP
      |
      v
Jenkins Deployment Stage
```

### 9. Wait for EC2 Initialization

Before deployment, Jenkins waits for the EC2 server to initialize:

```groovy
sleep(time: 90, unit: "SECONDS")
```

This gives the EC2 bootstrap process time to prepare the server.

### 10. Connect to EC2 with SSH

The EC2 destination is dynamically constructed from the Terraform output:

```groovy
def ec2Instance = "ec2-user@${EC2_PUBLIC_IP}"
```

Jenkins uses the SSH credential:

```groovy
sshagent(['docker-server'])
```

to authenticate to the provisioned server.

### 11. Copy Deployment Files to EC2

Jenkins uses `scp` to copy:

```text
server-cmds.sh
docker-compose.yaml
```

to:

```text
/home/ec2-user
```

on the EC2 instance.

### 12. Deploy the Published Docker Image

Jenkins remotely executes `server-cmds.sh` and passes the Docker image and
Docker Hub credentials:

```groovy
def shellCmd = "bash ./server-cmds.sh ${IMAGE_NAME} ${DOCKER_CREDS_USR} ${DOCKER_CREDS_PSW}"
```

The deployment script receives the image:

```bash
export IMAGE=$1
```

authenticates to Docker Hub:

```bash
echo $DOCKER_PWD | docker login -u $DOCKER_USER --password-stdin
```

and starts the deployment using:

```bash
docker-compose -f docker-compose.yaml up --detach
```

The application service in `docker-compose.yaml` references:

```yaml
image: ${IMAGE}
```

so the image built and published earlier in the pipeline is passed into the
remote deployment rather than hard-coded again in the Compose application
service.

The application image therefore moves through the pipeline as:

```text
Jenkins IMAGE_NAME
       |
       v
Docker Build
       |
       v
Docker Hub
       |
       v
server-cmds.sh
       |
       v
export IMAGE
       |
       v
docker-compose.yaml
       |
       v
${IMAGE}
       |
       v
Application Deployment
```

---

## Terraform Infrastructure

Terraform manages the AWS infrastructure required for the application
deployment.

The configuration provisions:

- VPC
- Subnet
- Internet Gateway
- Route Table
- Route Table Association
- Security Group
- EC2 Instance

The AWS provider uses:

```hcl
provider "aws" {
  region = var.region
}
```

with a default region of:

```text
us-east-2
```

### VPC and Networking

The dedicated VPC uses:

```text
10.0.0.0/16
```

and the subnet uses:

```text
10.0.10.0/24
```

in:

```text
us-east-2a
```

An Internet Gateway is attached to the VPC.

A route table containing a route through the Internet Gateway is associated
with the application subnet.

### Security Group

Terraform creates the EC2 security group with ingress rules for:

- SSH on port `22`
- application traffic on port `8080`
- HTTPS on port `443`

SSH access is restricted using the configured source addresses for my local
workstation and the Jenkins server.

The application port is also controlled using the configured source address.

### EC2 Provisioning

Terraform dynamically looks up the latest matching Amazon Linux 2 AMI:

```hcl
data "aws_ami" "latest-amazon-linux-image"
```

The default instance type is:

```text
t2.micro
```

The EC2 instance receives a public IP address and uses:

```text
docker-server
```

as its EC2 key pair.

### EC2 Bootstrap with Terraform user_data

The EC2 instance uses:

```hcl
user_data = file("entry-script.sh")
```

to execute `terraform/entry-script.sh` during initialization.

The bootstrap script:

- updates the server,
- installs Docker,
- starts the Docker service,
- adds `ec2-user` to the Docker group,
- installs Docker Compose.

This prepares the newly provisioned server for the Jenkins deployment stage.

### Terraform Remote State

Terraform state is stored remotely using an Amazon S3 backend:

```hcl
terraform {
  backend "s3" {
    bucket = "josep-myapp-tf-state-2026"
    key    = "myapp/state.tfstate"
    region = "us-east-2"
  }
}
```

This keeps the Terraform state outside the Jenkins workspace and allows the
state of the managed infrastructure to persist between pipeline executions.

---

## Infrastructure Destruction

The same Jenkins pipeline can remove the Terraform-managed AWS infrastructure.

When:

```text
TF_ACTION=destroy
```

is selected, the Terraform stage executes:

```bash
terraform destroy --auto-approve
```

The application build, Docker image, and deployment stages are protected by:

```groovy
when {
  expression { params.TF_ACTION == 'apply' }
}
```

Therefore, a destroy execution follows this behavior:

```text
Build Application    -> SKIPPED
Build Docker Image   -> SKIPPED
Push Docker Image    -> SKIPPED
Terraform            -> DESTROY
Deployment           -> SKIPPED
```

This allows both infrastructure provisioning and cleanup to be controlled
through the same Jenkins pipeline.

---

## Jenkins Credential Management

Sensitive authentication information used by the pipeline is managed through
Jenkins Credentials.

The Jenkinsfile references:

```text
github-credentials
jenkins_aws_access_key_id
jenkins_aws_secret_access_key
docker-hub-repo
docker-server
```

These credentials are used for:

- Jenkins Shared Library repository access
- AWS authentication
- Docker Hub authentication
- EC2 SSH authentication

This keeps the actual secret values outside the Jenkinsfile.

---

## What I Learned

One of my biggest learnings from this project was understanding how
Infrastructure as Code can become part of the same CI/CD workflow as
application delivery.

Rather than treating application delivery and infrastructure provisioning as
separate manual processes, I was able to connect them through Jenkins.

Each technology performs a specific responsibility:

```text
Maven
→ builds the Java application

Docker
→ packages the application into a deployable image

Docker Hub
→ stores and distributes the published application image

Terraform
→ provisions and manages the AWS infrastructure lifecycle

AWS
→ provides the cloud infrastructure

EC2 user_data
→ prepares the newly provisioned server

Terraform Output
→ passes the dynamically created EC2 public IP to Jenkins

SSH
→ enables automated remote deployment

Docker Compose
→ deploys the application on the EC2 instance

Jenkins Shared Library
→ provides reusable pipeline functions

Jenkins
→ orchestrates the complete workflow
```

I also gained practical experience with:

- Jenkins parameters
- conditional pipeline stages
- Jenkins Credentials
- Jenkins Shared Libraries
- Maven application builds
- Docker image creation and tagging
- Docker Hub authentication
- publishing Docker images to my Docker Hub repository
- Infrastructure as Code
- Terraform initialization
- Terraform remote state with Amazon S3
- Terraform variables
- Terraform outputs
- AWS authentication from Jenkins
- AWS VPC networking
- subnets
- Internet Gateways
- route tables
- security groups
- EC2 provisioning
- EC2 bootstrap using Terraform `user_data`
- dynamically passing infrastructure information between pipeline stages
- SSH authentication and remote execution
- Docker Compose deployment
- infrastructure provisioning and destruction

The most important lesson from this project was understanding the complete
relationship between CI/CD, containerization, Infrastructure as Code, cloud
infrastructure, and application deployment.

The application is built with Maven and packaged into a Docker image. Jenkins
publishes that image to my Docker Hub repository. Terraform provisions the AWS
infrastructure and returns the newly created EC2 public IP to Jenkins. Jenkins
then connects to that server through SSH and deploys the published application
image using Docker Compose.

This project gave me hands-on experience connecting these technologies as one
end-to-end automated DevOps workflow.
