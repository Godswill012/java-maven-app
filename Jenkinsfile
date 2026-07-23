#!/usr/bin/env groovy

library identifier: 'jenkins-shared-library0@master', retriever: modernSCM(
    [$class: 'GitSCMSource',
    remote: 'https://github.com/Godswill012/jenkins-shared-library0.git',
    credentialsId: 'github-credentials'
    ]
)

pipeline {
    agent any
    tools {
        maven 'maven-3.9'
    }
    stages {
        stage('increment version') {
            steps {
                script {
                    echo 'incrementing app version...'
                    sh 'mvn build-helper:parse-version versions:set \
                        -DnewVersion=\\\${parsedVersion.majorVersion}.\\\${parsedVersion.minorVersion}.\\\${parsedVersion.nextIncrementalVersion} \
                        versions:commit'
                    def matcher = readFile('pom.xml') =~ '<version>(.+)</version>'
                    def version = matcher[0][1]
                    env.IMAGE_NAME = "godswill012/java-maven-app:${version}-${BUILD_NUMBER}"
                }
            }
        }
        stage('build app') {
            steps {
                echo 'building application jar...'
                buildJar()
            }
        }
        stage('build image') {
            steps {
                script {
                    echo 'building the docker image...'
                    buildImage(env.IMAGE_NAME)
                    dockerLogin()
                    dockerPush(env.IMAGE_NAME)
                }
            }
        } 
       stage('deploy') {
           steps {
               script {
                   echo 'deploying docker image to EC2...'

                   sshagent(['ec2-server-key']) {
                       sh "scp docker-compose.yaml ec2-user@18.118.185.115:/home/ec2-user"

                       sh """
                           ssh -o StrictHostKeyChecking=no ec2-user@18.118.185.115 \
                           "docker-compose -f /home/ec2-user/docker-compose.yaml up -d"
                       """
                    }
                }
            }
        }
        stage('commit version update'){
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'github-credentials', passwordVariable: 'PASS', usernameVariable: 'USER')]){
                        sh 'git remote set-url origin https://github.com/Godswill012/java-maven-app.git'
                        sh 'git add .'
                        sh 'git commit -m "ci: version bump"'
                        sh 'git push origin HEAD:jenkins-jobs'
                    }
                }
            }
        }
    }
}
