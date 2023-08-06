pipeline {
    agent {
        label "local"
    }

    parameters {
        choice(name: 'TERRAFORM_COMMAND', choices: ['plan', 'apply', 'destroy'], description: 'Select Terraform command to run')
    }

    stages {
        stage('Clone Repository') {
            steps {
                echo "Cloning the remote Git repository..."
                git branch: 'kubernetes', url: 'https://github.com/melovagabond/azure_foundation.git'
            }
        }
        stage('SonarQube Analysis') {
            environment {
                PATH = "${PATH}:/opt/sonar-scanner/bin"
            }
            steps {
                echo "Running SonarQube analysis..."

                // Run SonarScanner
                sh 'sonar-scanner \
                -Dsonar.projectKey=Azure_Kubectl \
                -Dsonar.sources=. \
                -Dsonar.host.url=http://10.0.0.250:9000 \
                -Dsonar.token=\$SONAR_AZURE'
            }
        }
        stage('Terraform') {
            steps {
                script {
                    if (params.TERRAFORM_COMMAND == 'plan') {
                        echo "Running terraform init and plan commands..."
                        sh 'terraform init && terraform plan'
                    } else if (params.TERRAFORM_COMMAND == 'apply') {
                        echo "Running terraform apply commands..."
                        sh 'terraform init && terraform apply -auto-approve'
                    } else if (params.TERRAFORM_COMMAND == 'destroy') {
                        echo "Running terraform destroy commands..."
                        sh 'terraform init && terraform destroy -auto-approve'
                    } else {
                        echo "Invalid option selected!"
                        error('Invalid option selected!')
                    }
                }
            }
        }
        stage('Clean Workspace') {
            when {
                expression {params.TERRAFORM_COMMAND == 'destroy'}
            }
            steps {
                cleanWs()
            }
        }
    }
}