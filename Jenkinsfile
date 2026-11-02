pipeline {
    agent { label 'QA' }

    environment {
        IMAGE = 'frais-backend'   // <-- apni docker-compose.yml wale image ka naam yahan daalo
    }

    stages {
        stage("Build") {
            steps {
                sh "sudo cp /home/azureuser/configfiles/frais/backend/appsettings.json appsettings.json"
                sh "sudo cp /home/azureuser/configfiles/frais/backend/docker-compose.yml docker-compose.yml"

                // purani working image ka backup (pehli baar image na ho to ignore)
                sh "sudo docker tag ${IMAGE}:latest ${IMAGE}:rollback || true"

                sh "sudo docker compose down --remove-orphans"
                sh "sudo docker container prune --force"
                sh "sudo docker image prune --force"
            }
        }
        stage("Deploy") {
            steps {
                sh "sudo docker compose -f docker-compose.yml up --build --no-deps --renew-anon-volumes --detach --remove-orphans"
            }
        }
    }

    post {
        failure {
            echo "Deploy fail hua, purani image par rollback ho raha hai"
            sh "sudo docker tag ${IMAGE}:rollback ${IMAGE}:latest"
            sh "sudo docker compose -f docker-compose.yml up --no-build --detach --remove-orphans"
        }
    }
}
