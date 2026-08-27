#!/usr/bin/env groovy

library identifier: 'jenkins-shared-library0@master', retriever: modernSCM(
  [$class: 'GitSCMSource',
  remote: 'https://github.com/Godswill012/jenkins-shared-library0.git',
  credentialsId: 'github-credentials'
  ]
)

pipeline {
  agent any

  parameters {
    choice(
      name: 'TF_ACTION',
      choices: ['apply', 'destroy'],
      description: 'Choose whether to provision or destroy the Terraform-managed infrastructure.'
    )
  }

  tools {
    maven 'maven-3.9'
  }

  environment {
    IMAGE_NAME = 'godswill012/demo-app:java-maven-2.0'
  }

  stages {

    stage("build app") {
      when {
        expression { params.TF_ACTION == 'apply' }
      }

      steps {
        script {
          echo 'building application jar...'
          buildJar()
        }
      }
    }

    stage("build image") {
      when {
        expression { params.TF_ACTION == 'apply' }
      }

      steps {
        script {
          echo 'building docker image...'
          buildImage(env.IMAGE_NAME)
          dockerLogin()
          dockerPush(env.IMAGE_NAME)
        }
      }
    }

    stage("provision server") {
      environment {
        AWS_ACCESS_KEY_ID     = credentials('jenkins_aws_access_key_id')
        AWS_SECRET_ACCESS_KEY = credentials('jenkins_aws_secret_access_key')
        AWS_DEFAULT_REGION    = 'us-east-2'
        TF_VAR_env_prefix     = 'test'
        TF_STATE_BUCKET       = 'josep-myapp-tf-state-2026'
      }

      steps {
        script {
          dir('terraform') {

            if (params.TF_ACTION == 'destroy') {
              sh 'terraform init'
              sh 'terraform destroy --auto-approve'
              sh './delete-backend.sh'
            } else {
              sh './create-backend.sh'
              sh 'terraform init'
              sh 'terraform apply --auto-approve'

              env.EC2_PUBLIC_IP = sh(
                script: 'terraform output -raw ec2-public_ip',
                returnStdout: true
              ).trim()
            }
          }
        }
      }
    }

    stage("deploy") {
      when {
        expression { params.TF_ACTION == 'apply' }
      }

      environment {
        DOCKER_CREDS = credentials('docker-hub-repo')
      }

      steps {
        script {
          echo "waiting for EC2 server to initialize"
          sleep(time: 90, unit: "SECONDS")

          echo 'deploying docker image to EC2...'
          echo "${env.EC2_PUBLIC_IP}"

          def ec2Instance = "ec2-user@${env.EC2_PUBLIC_IP}"

          sshagent(['docker-server']) {
            sh "scp -o StrictHostKeyChecking=no server-cmds.sh ${ec2Instance}:/home/ec2-user"
            sh "scp -o StrictHostKeyChecking=no docker-compose.yaml ${ec2Instance}:/home/ec2-user"

            withEnv(["EC2_INSTANCE=${ec2Instance}"]) {
              sh '''
                ssh -o StrictHostKeyChecking=no "$EC2_INSTANCE" \
                  "bash ./server-cmds.sh ${IMAGE_NAME} ${DOCKER_CREDS_USR} ${DOCKER_CREDS_PSW}"
              '''
            }
          }
        }
      }
    }

  }
}