provider "aws" {
  region = "us-east-2"
}

terraform {
  backend "s3" {
    # Replace this with your bucket name!
    bucket         = "convex-data-state"
    key            = "stage/data-stores/mysql/terraform.tfstate"
    region         = "us-east-2"

    # Replace this with your DynamoDB table name!
    dynamodb_table = "convex-data-state-locks"
    encrypt        = true
  }
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "_%!"
}

resource "aws_secretsmanager_secret" "mysql_creds" {
    name = "mysql_creds"
}

resource "aws_secretsmanager_secret_version" "mysql_creds_version" {
  secret_id     = aws_secretsmanager_secret.mysql_creds.id
  secret_string = <<EOF
                  {
                    "username": "admin",
                    "password": "${random_password.password.result}"
                  }
                  EOF
}

data "aws_secretsmanager_secret" "mysql_creds" {
  arn = aws_secretsmanager_secret.mysql_creds.arn
}

data "aws_secretsmanager_secret_version" "creds" {
  secret_id = data.aws_secretsmanager_secret.mysql_creds.arn
}

locals {
  db_creds = jsondecode(
  data.aws_secretsmanager_secret_version.creds.secret_string
   )
}

resource "aws_db_instance" "mysql" {
  identifier_prefix   = "terraform-up-and-running"
  engine              = "mysql"
  allocated_storage   = 10
  instance_class      = "db.t2.micro"
  name                = "example_database"
  username            = local.db_creds.username

  # How should we set the password?
  password            = local.db_creds.password
}
