
pipeline {
    agent { label 'QA' }

    options {
        skipDefaultCheckout(true)
    }

    environment {
        IMAGE = 'localhost:5000/frais-demo'
        CONTAINER = 'frais-demo-app'
        APP_PORT = '8091'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scmGit(
                    branches: [[name: '*/main']],
                    userRemoteConfigs: [[
                        url: 'https://github.com/Aditya123-kumar/jenkins-auto.git'
                    ]],
                    gitTool: 'Linux-Git'
                )
            }
        }

        stage('Build') {
            steps {
                sh '''
                    docker build -t ${IMAGE}:build-${BUILD_NUMBER} \
                        -f app/Dockerfile app
                '''
            }
        }

        stage('Backup Previous Image') {
            steps {
                sh '''
                    if docker image inspect ${IMAGE}:latest >/dev/null 2>&1; then
                        docker tag ${IMAGE}:latest ${IMAGE}:rollback
                        echo "Previous image backed up"
                    else
                        echo "No previous latest image; first deployment"
                    fi
                '''
            }
        }

        stage('Push Image') {
            steps {
                sh '''
                    docker tag ${IMAGE}:build-${BUILD_NUMBER} ${IMAGE}:latest
                    docker push ${IMAGE}:latest
                '''
            }
        }

        stage('Deploy') {
            steps {
                sh '''
                    docker rm -f ${CONTAINER} 2>/dev/null || true

                    docker run -d \
                        --name ${CONTAINER} \
                        --restart unless-stopped \
                        -p ${APP_PORT}:80 \
                        ${IMAGE}:latest

                    sleep 5
                    docker inspect -f '{{.State.Running}}' ${CONTAINER} | grep true
                    curl -fsS http://localhost:${APP_PORT}/
                '''
            }
        }
    }

    post {
        failure {
            echo 'Deployment failed. Checking previous image.'

            sh '''
                if docker image inspect ${IMAGE}:rollback >/dev/null 2>&1; then
                    docker rm -f ${CONTAINER} 2>/dev/null || true

                    docker run -d \
                        --name ${CONTAINER} \
                        --restart unless-stopped \
                        -p ${APP_PORT}:80 \
                        ${IMAGE}:rollback

                    echo "Previous image restored"
                else
                    echo "No previous image available for rollback"
                fi
            '''
        }

        success {
            echo 'Deployment completed successfully!'
        }
    }
}
