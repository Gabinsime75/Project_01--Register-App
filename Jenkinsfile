pipeline{
    // define the agent for the pipeline
    agent {label 'Jenkins-Agent'}

    tools {
        jdk 'Java17'
        maven 'Maven3'
    }

    // Define environmental variables
    environment {
	    APP_NAME        = "register-app-pipeline2"
        RELEASE         = "1.0.0"
        DOCKER_USER     = "gabin75"
        DOCKER_PASS     = 'dockerhub'
        IMAGE_NAME      = "${DOCKER_USER}" + "/" + "${APP_NAME}"
        IMAGE_TAG       = "${RELEASE}-${BUILD_NUMBER}"
        NVD_API_KEY     = "nvd-api-key"
    }

    stages{
        stage('Cleanup Workspace'){
            // Cleans the workspace before starting the pipeline to ensure no residual files affect the build.
            steps{
                cleanWs()
            }
        }

        stage('Checkout from SCM'){
            // Checks out the code from the GitHub repository on the main branch using credentials identified as github.
            steps{
                git branch: 'main', credentialsId: 'github', url: 'https://github.com/Gabinsime75/Project_01--Register-App.git'
            }
        }

        stage('Build Application'){
            // Runs the Maven command mvn clean package to compile the Java application and package it as a .jar file
            steps{
                sh "mvn clean package"
            }
        }

        stage('Test Application'){
            // Executes mvn test to run unit tests on the application, ensuring it behaves as expected.
            steps{
                sh "mvn test"
            }
        }

        stage("SonarQube Analysis"){
           steps {
            // analyze the code for quality issues such as bugs, vulnerabilities, and code smells. 
	           script {
		        withSonarQubeEnv(credentialsId: 'Sonar-jenkins-token') { 
                        sh "mvn sonar:sonar"
		            }
	           }	
           }
       }

    //    stage("Quality Gate"){
    //        steps {
    //         script {
    //             waitForQualityGate abortPipeline: false, credentialsId: 'Sonar-jenkins-token'
    //             } 	
    //         }
    //     }

        stage ('OWASP Dependency Check') {
            // Scans the project for known vulnerabilities in dependencies, 
            steps {
                withCredentials([string(credentialsId: 'nvd-api-key', variable: 'NVD_API_KEY')]) {
                    dependencyCheck additionalArguments: '--scan ./ --format XML --nvdApiKey $NVD_API_KEY', odcInstallation: 'DP-Check'
                }
                // The results are published in a report (dependency-check-report.xml).
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
                sh "trivy image --download-db-only"
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

