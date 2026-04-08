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

# Definir a Role para a EC2 poder ler o segredo
resource "aws_iam_role" "ec2_git_role" {
  name = "EC2GitAccessRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }]
  })
}

# Política de permissão apenas para o segredo específico
resource "aws_iam_role_policy" "secrets_policy" {
  role = aws_iam_role.ec2_git_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = "secretsmanager:GetSecretValue"
      Effect   = "Allow"
      Resource = "arn:aws:secretsmanager:us-east-1:412628362918:secret:git-wpp-python-deploy-key-*"
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_git_profile"
  role = aws_iam_role.ec2_git_role.name
}

# Criar uma instância EC2
resource "aws_instance" "minha_instancia" {
  ami           = "ami-0ec10929233384c7f" # LocalStack aceita qualquer ID de AMI
  instance_type = "m7i-flex.large"
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
    #!/bin/bash
    # Instalar dependências
    apt-get update
    apt-get install -y git python3 curl unzip

    cd /home && echo $(date) > abcdef.txt

    # Instalar AWS CLI se não houver
    curl "https://amazonaws.com" -o "awscliv2.zip"
    unzip awscliv2.zip && ./aws/install

    # Baixar a chave privada do Secrets Manager de forma segura
    mkdir -p /home/ubuntu/.ssh
    aws secretsmanager get-secret-value --secret-id git-wpp-python-deploy-key  --query SecretString --output text > /home/ubuntu/.ssh/id_rsa
    
    # Ajustar permissões da chave
    chmod 600 /home/ubuntu/.ssh/id_rsa
    chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa

    # Adicionar GitHub aos hosts conhecidos para evitar o prompt de confirmação
    ssh-keyscan github.com >> /home/ubuntu/.ssh/known_hosts

    # Clonar o repositório como usuário ubuntu
    sudo -u ubuntu git clone git@github.com:LeonardoRk/msg-wpp-real-estate.git  /home/ubuntu/projeto
  EOF

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
