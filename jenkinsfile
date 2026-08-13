// ==========================================
// Declarative Jenkinsfile - Complete DevSecOps & GitOps Pipeline
// ==========================================
// Instructor: SRINIVAS
// Platform: SRINUTECHGURU
// ==========================================

pipeline {
    // Executes the pipeline on any available Jenkins agent
    agent any
    
    // Tools configured in Jenkins Global Tool Configuration
    tools {
        jdk 'jdk17'
        nodejs 'node18' 
    }
    
    environment {
        // SonarQube scanner environment variable
        SCANNER_HOME = tool 'sonar-scanner'
        
        // DockerHub configuration
        DOCKERHUB_CREDS = credentials('dockerhub-credentials-id') 

        // Docker registry targeting
        IMAGE_NAME = "srinutechguru/zomato"
        
        // Dynamically tags the image with the Jenkins Build Number
        IMAGE_TAG = "${env.BUILD_NUMBER}"

        // GitHub GitOps Repository configuration
        GITHUB_CREDS = credentials('github-token-id')
        GITOPS_REPO = "https://github.com/srinutechguru/srinutechguru-zomato-microservice.git"
        
        // GitOps Repository for ArgoCD to monitor
        GITOPS_REPO = "https://github.com/srinutechguru/react-zomato-k8s-deployment.git"
    }
    
    stages {
        stage('Clean Workspace') {
            steps {
                // Ensures a fresh environment for every build
                cleanWs()
            }
        }
        
        stage('Checkout from Git') {
            steps {
                // Pulls the source code from the application repository
                git branch: 'main', url: 'https://github.com/srinutechguru/srinutechguru-zomato-microservice.git'
            }
        }
        
        stage("SonarQube Analysis") {
            steps {
                script {
                    def scannerHome = tool 'Sonar-Scanner'
                    withSonarQubeEnv('sonarqube-server') {
                        sh "${scannerHome}/bin/sonar-scanner \
                            -Dsonar.projectName=zomato \
                            -Dsonar.projectKey=zomato \
                            -Dsonar.sources=src/"
                    }
                }
            }
        }
        
        stage("Quality Gate") {
            steps {
                script {
                    // Pauses the pipeline until SonarQube confirms the code meets quality standards
                    waitForQualityGate abortPipeline: true, credentialsId: 'sonarqube-token-id' 
                }
            } 
        }
        
        stage('Install NPM Dependencies') {
            steps {
                // Installs packages required for the OWASP dependency check
                sh "npm install"
            }
        }
        
        stage('OWASP Dependency Scan') {
            steps {
                // Scans node_modules for known CVEs
                dependencyCheck additionalArguments: '--scan ./ --disableYarnAudit --disableNodeAudit', odcInstallation: 'owasp-dependency-check'
                dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
            }
        }
        
        stage('Trivy FS Scan') {
            steps {
                // Scans the local filesystem and Dockerfile for misconfigurations
                sh "trivy fs . > trivyfs.txt"
            }
        }
        
        stage("Docker Build & Push") {
            steps {
                script {
                   // Uses the Jenkins credential ID 'dockerhub-credentials-id' to authenticate
                   withDockerRegistry(credentialsId: 'dockerhub-credentials-id', toolName: 'docker'){   
                       // Builds the multi-stage Nginx image
                       sh "docker build -t ${IMAGE_NAME}:latest ."
                       
                       // Tags the image with the unique build number
                       sh "docker tag ${IMAGE_NAME}:latest ${IMAGE_NAME}:${IMAGE_TAG}"
                       
                       // Pushes both tags to the registry
                       sh "docker push ${IMAGE_NAME}:latest"
                       sh "docker push ${IMAGE_NAME}:${IMAGE_TAG}"
                    }
                }
            }
        }
        
        stage("Trivy Image Scan") {
            steps {
                // Scans the newly compiled Docker image before deployment
                sh "trivy image ${IMAGE_NAME}:latest > trivy_image_scan.txt" 
            }
        }
        
        stage('Deploy to Local Docker (Test)') {
            steps {
                // Gracefully removes any old containers running locally on the Jenkins server
                sh 'docker stop zomato || true'
                sh 'docker rm zomato || true'
                
                // Runs the Nginx container, mapping host Port 3000 to container Port 80
                sh "docker run -d --name zomato -p 3000:80 ${IMAGE_NAME}:latest"
            }
        }
        
        stage('Update Manifests in GitOps Repo') {
            steps {
                // Uses a GitHub Personal Access Token to commit back to the K8s repository
                withCredentials([gitUsernamePassword(credentialsId: 'github-token-id', gitToolName: 'Default')]) {
                    sh """
                        # Clone the infrastructure repository
                        git clone ${GITOPS_REPO}
                        cd react-zomato-k8s-deployment/k8s
                        
                        # Use sed to dynamically update the deployment.yaml with the new image tag
                        sed -i "s|image: ${IMAGE_NAME}:.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|g" deployment.yaml
                        
                        # Configure Git identity for the automated commit
                        git config user.name "Jenkins Automation"
                        git config user.email "srinutechguru@gmail.com"
                        
                        # Commit and push the changes to trigger ArgoCD
                        git add deployment.yaml
                        git commit -m "chore: update zomato image tag to ${IMAGE_TAG} [skip ci]"
                        git push origin main
                    """
                }
            }
        }
    }
    
    // Post-execution actions based on the pipeline's outcome
    post {
        always {
            echo 'Pipeline execution completed. Cleaning up workspace...'
            cleanWs()
        }
        success {
            echo '=========================================='
            echo '✅ DEPLOYMENT SUCCESSFUL!'
            echo "Image Tag Built: ${IMAGE_TAG}"
            echo 'GitOps repository updated. ArgoCD is now syncing the AWS EKS cluster.'
            echo '=========================================='
        }
        failure {
            echo '=========================================='
            echo '❌ PIPELINE FAILED!'
            echo 'Check the Jenkins console output for error details.'
            echo '=========================================='
        }
    }
}
