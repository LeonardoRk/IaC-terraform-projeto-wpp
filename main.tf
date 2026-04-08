provider "aws" {
  region                      = "us-east-1"
  
  dynamic "endpoints" {
    for_each = var.use_localstack ? [1] : []
    content {
      ec2 = "http://localhost:4566"
      s3  = "http://localhost:4566"
    }
  }

  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  skip_requesting_account_id  = var.use_localstack
  s3_use_path_style           = var.use_localstack

}

# Criar uma instância EC2 (S2 não existe, você provavelmente quis dizer EC2)
resource "aws_instance" "minha_instancia" {
  ami           = "ami-0ec10929233384c7f" # LocalStack aceita qualquer ID de AMI
  instance_type = "m7i-flex.large"

  tags = {
    Name = "MeuEc2TfPythonWpp"
  }
}


terraform {
  backend "s3" {
    bucket = "projeto-wpp-python"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}
