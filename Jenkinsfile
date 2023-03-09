pipeline {
    agent any

    stages {

        stage("build") {

            steps {
                echo 'build'
                sh '''
                
                '''
            }
        }

        stage("test") {

            steps {
                echo 'test'
                sh '''
                java -version
                apt install sudo
                curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                sudo ./aws/install
                aws --version
                '''
            }
        }

        stage("deploy") {

            steps {
                echo 'deploy'
            }
        }
    }
}

