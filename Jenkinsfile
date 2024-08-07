pipeline{
    agent {label 'Jenkins-Agent'}
    tools {
        jdk 'jdk17'
        maven 'Maven3'
    }

    environment {
	    APP_NAME = "register-app-pipeline"
        RELEASE = "1.0.0"
        DOCKER_USER = "gabin75"
        DOCKER_PASS = 'dockerhub'
        IMAGE_NAME = "${DOCKER_USER}" + "/" + "${APP_NAME}"
        IMAGE_TAG = "${RELEASE}-${BUILD_NUMBER}"
    }

    stages{
        stage('Cleanup Workspace'){
            steps{
                cleanWs()
            }
        }

        stage('Checkout from SCM'){
            steps{
                git branch: 'main', credentialsId: 'github', url: 'https://github.com/Gabinsime75/Project_15--Register-App.git'
            }
        }

        stage('Build Application'){
            steps{
                sh "mvn clean package"
            }
        }

        stage('Test Application'){
            steps{
                sh "mvn test"
            }
        }

        stage("SonarQube Analysis"){
           steps {
	           script {
		        withSonarQubeEnv(credentialsId: 'Sonar-token') { 
                        sh "mvn sonar:sonar"
		            }
                // echo 'SonarQube analysis triggered, skipping status check.'
	           }	
           }
       }

       stage("Quality Gate"){
           steps {
               script {
                    waitForQualityGate abortPipeline: false, credentialsId: 'Sonar-token'
                }	
            }

        }

        stage ('OWASP Dependency Check') {
            steps {
                withCredentials([string(credentialsId: 'nvd-api-key', variable: 'NVD_API_KEY')]) {
                    dependencyCheck additionalArguments: '--scan ./ --format XML --nvdApiKey $NVD_API_KEY', odcInstallation: 'DP-Check'
                }
                // List files to check for the report
                sh "ls -l"
                // Verify the report's location
                sh "cat dependency-check-report.xml"
                dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
            }
        }

        stage('TRIVY FS SCAN') {
            steps {
                sh "trivy fs . > trivyfs.txt"
            }
        }

        stage("Build & Push Docker Image") {
            steps {
                script {
                    docker.withRegistry('',DOCKER_PASS) {
                        docker_image = docker.build "${IMAGE_NAME}"
                    }

                    docker.withRegistry('',DOCKER_PASS) {
                        docker_image.push("${IMAGE_TAG}")
                        docker_image.push('latest')
                    }
                }
            }
       }
        // This command updates Trivy's database, ensuring that your scans are using the most recent vulnerability data, which is particularly useful for Java applications.
        stage('Update Trivy DB') {
            steps {
                sh "trivy clean --java-db"
            }
        }

        stage("Trivy Scan") {
            steps {
                script {
                    def imageToScan = "${IMAGE_NAME}:${IMAGE_TAG}"
                    sh "docker run -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image ${imageToScan} --no-progress --scanners vuln --exit-code 0 --severity HIGH,CRITICAL --format table"
                }
            }
        }
        // This stage is responsible for cleaning up Docker images to free up disk space and remove unnecessary artifacts.
        stage ('Cleanup Artifacts') {
           steps {
               script {
                    sh "docker rmi ${IMAGE_NAME}:${IMAGE_TAG}"
                    sh "docker rmi ${IMAGE_NAME}:latest"
               }
          }
       }
    }
}      


