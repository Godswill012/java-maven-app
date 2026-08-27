#!/usr/bin/env groovy

pipeline {
    agent any

    tools {
        maven 'maven-3.9'
    }

    environment {
        DOCKER_REPO_SERVER = '555175526044.dkr.ecr.us-east-2.amazonaws.com'
        DOCKER_REPO = "${DOCKER_REPO_SERVER}/java-maven-app"
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

                    env.IMAGE_NAME = "$version-$BUILD_NUMBER"
                }
            }
        }

        stage('build app') {
            steps {
                script {
                    echo 'building the application...'
                    sh 'mvn clean package'
                }
            }
        }

        stage('build image') {
            environment {
                AWS_ACCESS_KEY_ID = credentials('jenkins_aws_access_key_id')
                AWS_SECRET_ACCESS_KEY = credentials('jenkins_aws_secret_access_key')
                AWS_DEFAULT_REGION = 'us-east-2'
            }

            steps {
                script {
                    echo 'building the docker image...'

                    sh '''
                        aws ecr get-login-password --region "$AWS_DEFAULT_REGION" |
                        docker login \
                            --username AWS \
                            --password-stdin "$DOCKER_REPO_SERVER"
                    '''

                    sh 'docker build -t "$DOCKER_REPO:$IMAGE_NAME" .'
                    sh 'docker push "$DOCKER_REPO:$IMAGE_NAME"'
               }
            }
        }

        stage('deploy') {
            environment {
                AWS_ACCESS_KEY_ID = credentials('jenkins_aws_access_key_id')
                AWS_SECRET_ACCESS_KEY = credentials('jenkins_aws_secret_access_key')
                AWS_DEFAULT_REGION = 'us-east-2'
                APP_NAME = 'java-maven-app'
            }

            steps {
                script {
                    echo 'deploying docker image...'

                    sh 'aws eks update-kubeconfig --region "$AWS_DEFAULT_REGION" --name myapp-eks-cluster'

                    sh 'envsubst < kubernetes/deployment.yaml | kubectl apply -f -'
                    sh 'envsubst < kubernetes/service.yaml | kubectl apply -f -'
                }
            }
        }

        stage('commit version update') {
            steps {
                script {
                    withCredentials([
                        usernamePassword(
                            credentialsId: 'github-credentials',
                            passwordVariable: 'PASS',
                            usernameVariable: 'USER'
                        )
                    ]) {
                        sh 'git remote set-url origin https://${USER}:${PASS}@github.com/Godswill012/java-maven-app.git'
                        sh 'git config user.name "Jenkins CI"'
                        sh 'git config user.email "jenkins@example.com"'
                        sh 'git add pom.xml'
                        sh 'git commit -m "ci: version bump"'
                        sh 'git push origin HEAD:jenkins-jobs'
                    }
                }
            }
        }
    }
}



/*
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
                    env.IMAGE_NAME = "godswill012/my-app:${version}-${BUILD_NUMBER}"
                    echo "Docker image: ${env.IMAGE_NAME}"
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
                   def shellCmd = "bash ./server-cmds.sh ${IMAGE_NAME}"
                   def ec2Instance = "ec2-user@18.118.185.115"

                   sshagent(['ec2-server-key']) {
                       sh "scp docker-compose.yaml ${ec2Instance}:/home/ec2-user"
                       sh "scp server-cmds.sh ${ec2Instance}:/home/ec2-user"

                       sh "ssh -o StrictHostKeyChecking=no ${ec2Instance} ${shellCmd}"
                          
                    }
                }
            }
        }

        stage('commit version update'){
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'github-credentials', passwordVariable: 'PASS', usernameVariable: 'USER')]){
                        sh 'git remote set-url origin https://$USER:$PASS@github.com/Godswill012/java-maven-app.git'
                        sh 'git add .'
                        sh 'git commit -m "ci: version bump"'
                        sh 'git push origin HEAD:jenkins-jobs'
                    }
                }
            }
        }
    }
}
*/
