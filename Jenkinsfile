
pipeline {
    agent any

    environment {
        IMAGE_NAME = "jenkins-rollback-app"
        CONTAINER_NAME = "jenkins-rollback-app"
    }

    stages {

        stage('Get Previous Version') {
            steps {
                script {
                    if (fileExists('.last_successful_tag')) {
                        env.PREVIOUS_TAG =
                            readFile('.last_successful_tag').trim()
                    } else {
                        env.PREVIOUS_TAG = ""
                    }

                    env.NEW_TAG = "v${BUILD_NUMBER}"

                    echo "Previous Version: ${env.PREVIOUS_TAG}"
                    echo "New Version: ${env.NEW_TAG}"
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    export IMAGE_TAG=${NEW_TAG}
                    docker compose build
                '''
            }
        }

        stage('Deploy Application') {
            steps {
                script {
                    try {
                        sh '''
                            export IMAGE_TAG=${NEW_TAG}
                            docker compose up -d --no-build
                        '''

                        sh '''
                            sleep 5
                            curl -f http://localhost:8085/
                        '''

                        writeFile(
                            file: '.last_successful_tag',
                            text: env.NEW_TAG
                        )

                        echo "Deployment Successful!"

                    } catch (Exception e) {

                        echo "Deployment Failed! Starting Rollback..."

                        if (env.PREVIOUS_TAG != "") {

                            sh """
                                export IMAGE_TAG=${env.PREVIOUS_TAG}
                                docker compose up -d --no-build --force-recreate
                            """

                            echo "Rollback Successful: ${env.PREVIOUS_TAG}"

                        } else {
                            echo "No Previous Version Available!"
                        }

                        error("Deployment Failed - Rollback Executed")
                    }
                }
            }
        }
    }
}
