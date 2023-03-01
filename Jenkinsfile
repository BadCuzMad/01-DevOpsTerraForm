pipeline {
    agent any

    stages {

        stage("build") {

            steps {
                echo 'build'
            }
        }

        stage("test") {

            steps {
                echo 'test'
                sh '''
                curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                ls
                cd aws
                ls
                ./aws/install
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

