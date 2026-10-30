pipeline {
    agent any

    environment {
        IMAGE = "localhost:5000/rollback-app"
        CONTAINER_NAME = "jenkins-rollback-app"
        APP_URL = "http://localhost:8085/"
    }

    stages {

        stage('Prepare Versions') {
            steps {
                script {
                    def exists = bat(
                        script: '@echo off\r\ndocker inspect jenkins-rollback-app >NUL 2>&1',
                        returnStatus: true
                    )

                    if (exists == 0) {
                        env.PREVIOUS_IMAGE = bat(
                            script: '@echo off\r\ndocker inspect --format "{{.Config.Image}}" jenkins-rollback-app',
                            returnStdout: true
                        ).trim()

                        env.PREVIOUS_TAG = env.PREVIOUS_IMAGE.substring(
                            env.PREVIOUS_IMAGE.lastIndexOf(':') + 1
                        )
                    } else {
                        env.PREVIOUS_TAG = "v1"
                    }

                    def previousNumber = env.PREVIOUS_TAG
                        .replaceFirst('^v', '')
                        .toInteger()

                    env.NEW_TAG = "v${previousNumber + 1}"

                    echo "Previous Version: ${env.PREVIOUS_TAG}"
                    echo "New Version: ${env.NEW_TAG}"
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                bat '''
                    @echo off
                    docker build -t %IMAGE%:%NEW_TAG% .
                    if errorlevel 1 exit /b 1
                '''
            }
        }

        stage('Push to Private Registry') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'registry-creds',
                        usernameVariable: 'REGISTRY_USER',
                        passwordVariable: 'REGISTRY_PASSWORD'
                    )
                ]) {
                    bat '''
                        @echo off

                        powershell -NoProfile -Command "$env:REGISTRY_PASSWORD | docker login localhost:5000 --username $env:REGISTRY_USER --password-stdin"
                        if errorlevel 1 exit /b 1

                        docker push %IMAGE%:%NEW_TAG%
                        if errorlevel 1 exit /b 1

                        docker logout localhost:5000
                    '''
                }
            }
        }

        stage('Deploy and Health Check') {
            steps {
                script {
                    withCredentials([
                        usernamePassword(
                            credentialsId: 'registry-creds',
                            usernameVariable: 'REGISTRY_USER',
                            passwordVariable: 'REGISTRY_PASSWORD'
                        )
                    ]) {

                        bat '''
                            @echo off
                            powershell -NoProfile -Command "$env:REGISTRY_PASSWORD | docker login localhost:5000 --username $env:REGISTRY_USER --password-stdin"
                            if errorlevel 1 exit /b 1
                        '''

                        try {

                            bat '''
                                @echo off

                                echo Deploying new version: %NEW_TAG%

                                docker pull %IMAGE%:%NEW_TAG%
                                if errorlevel 1 exit /b 1

                                set IMAGE_TAG=%NEW_TAG%

                                docker compose up -d --no-build --force-recreate
                                if errorlevel 1 exit /b 1

                                timeout /t 10 /nobreak >NUL

                                powershell -NoProfile -Command "try { $r = Invoke-WebRequest -UseBasicParsing http://localhost:8085/; if ($r.Content -notmatch 'Application Version %NEW_TAG%') { exit 1 } } catch { exit 1 }"

                                if errorlevel 1 exit /b 1
                            '''

                            echo "Deployment Successful: ${env.NEW_TAG}"

                        } catch (Exception e) {

                            echo "Deployment Failed!"
                            echo "Starting Automatic Rollback..."

                            bat '''
                                @echo off

                                echo Restoring previous version: %PREVIOUS_TAG%

                                docker pull %IMAGE%:%PREVIOUS_TAG%
                                if errorlevel 1 exit /b 1

                                set IMAGE_TAG=%PREVIOUS_TAG%

                                docker compose up -d --no-build --force-recreate
                                if errorlevel 1 exit /b 1

                                timeout /t 10 /nobreak >NUL

                                powershell -NoProfile -Command "try { $r = Invoke-WebRequest -UseBasicParsing http://localhost:8085/; if ($r.Content -notmatch 'Application Version %PREVIOUS_TAG%') { exit 1 } } catch { exit 1 }"

                                if errorlevel 1 exit /b 1
                            '''

                            echo "Rollback Successful: ${env.PREVIOUS_TAG}"

                            error("Deployment Failed - Previous Version Restored")

                        } finally {
                            bat 'docker logout localhost:5000'
                        }
                    }
                }
            }
        }
    }

    post {
        success {
            echo 'CI/CD Pipeline Completed Successfully!'
        }

        failure {
            echo 'CI/CD Pipeline Failed. Check Console Output.'
        }
    }
}