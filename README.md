# Infraestrutura como código utilizando Terraform + AWS + Ansible
## 1. Configurando o AWS CLI
``Primeiro, é necessário configurar o AWS CLI, para que sua máquina se conecte com a AWS. para isso, é preciso utilizar o comando aws configure (lembre-se de já ter o AWS CLI instalado, caso ainda não tenha, utilize o site oficial da AWS: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).``

**Após a instalação, utilize o comando:**
```
aws configure
```
**Ele vai pedir quatro informações sobre sua conta da AWS, sendo elas em sequência:**
```
AWS Access Key ID:
AWS Secret Access Key: 
Default region name:
Default output format:
```
**Preencha os três primeiros primeiros, na sequência, e no Default output format, apenas dê Enter, pois não é algo necessário.**
## 2. Key Pairs (Chave SSH):
``Após configurar o AWS CLI, estamos prontos para o próximo passo: Criação de uma chave SSH. Esse passo é importante, pois é com essa chave que poderemos nos conectar aos servidores criados, utilizando o ansible, para automatizar ainda mais os processos.
``

``Por padrão, a pasta .ssh no Linux fica no diretório home do usuário (~/.ssh/). Por boas práticas, mantenha nesse diretório.``
 
**Para criar uma Key Pair, utilize o comando;:**
```
ssh-keygen -b 2048 -t rsa -f ansible-ssh-key
```

`` "ssh-keygen": Vai gerar um par de chaves SSH.>> "-b 2048": Especifica o tamanho da chave, neste caso, 2048 bits.>> "-t rsa": Define o tipo de chave como RSA.>> "-f ansible-ssh-key": Define o nome da chave que vai ser criada. ``

``O código irá pedir confirmação nas etapas, pode confirmar tudo, e por fim, será criada a chave. São dois arquivos gerados, o ansible-ssh-key.pub e o ansible-ssh-key (chave pública e chave privada).
``

**Copie o conteúdo da chave pública, e deixe-a salva em algum bloco de notas.**
## 3. Criando a infraestrutura
**Após todo o processo de configuração da AWS e criação de Key Pairs, o próximo passo é criar um diretório e dois arquivos dentro, main.tf e variables.tf:**
```
mkdir terraform-iac && cd terraform-iac && touch main.tf variables.tf 
```

``Isso criará o diretório e os dois arquivos dentro.``

**No main.tf o conteúdo a ser colocado é:**
```
# main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.31.0"
    }
  }
}

provider "aws" {
  alias  = "eu"
  region = "us-east-1"
}

data "aws_region" "current" {}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "AWS VPC"
  }
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "main" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = aws_vpc.main.cidr_block
  availability_zone = "${data.aws_region.current.name}a"
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }
}

resource "aws_route_table_association" "route_table_association" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_key_pair" "deployer" {
  key_name   = "ansible-ssh-key"
  public_key = # sua chave pública deve ficar aqui
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH traffic"
  vpc_id      = aws_vpc.main.id
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP traffic"
  vpc_id      = aws_vpc.main.id
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }
}

resource "aws_instance" "server" {
  count                       = var.instance_count # here we define with the variable instance_count how many servers we want to create (see variables.tf)
  ami                         = var.ami
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.deployer.key_name
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.main.id
  vpc_security_group_ids      = [aws_security_group.allow_ssh.id, aws_security_group.allow_http.id]

  tags = {
    Name = element(var.instance_tags, count.index)
  }
}
```
 ``Esse código define a infraestrutura que queremos, criando uma VPC, instâncias EC2, configura grupos de segurança para SSH e HTTP, e associa a chave SSH que criamos no passo dois.``

**(não esqueca de alterar essa linha: "public_key = # sua chave pública deve ficar aqui").** 

``A quantidade de instâncias e outras configurações vão ser controladas pelo outro arquivo que criamos, o variables.tf``
 
**No variables.tf o conteúdo a ser colocado é:**
```
# variables.tf

# com a variável instance_count nós definimos quantas instâncias vão ser criadas
variable "instance_count" {
  default = "3"
}

# nessa variável definimos o nome das VMs
variable "instance_tags" {
  type    = list(string)
  default = ["server01", "server02", "server03",]
}

# Aqui definimos a imagem da AWS que vamos utilizar, nesse caso é a do ubuntu
variable "ami" {
  type    = string
  default = "ami-0fc5d935ebf8bc3bc"
}

# Aqui o tipo da instância, de acordo com a AWS; t2.micro significa que não haverá custos de criação para esse tipo de instância
variable "instance_type" {
  type    = string
  default = "t2.micro"
}


# output.tf vai nos retornar esses valores na tela após a criação

output "server-data" {
  value = [for vm in aws_instance.server[*] : {
    ip_address = vm.public_ip
    public_dns = vm.public_dns
  }]
  description = "The public IP and DNS of the servers"
}
```

``O tipo de instância, a AMI utilizada, a quantidade de instâncias e os nomes, são definidos aqui.``

## 4. Utilizando o Terraform

``Após toda essa configuração, finalmente poderemos utilizar o Terraform, de fato.``

**O primeiro comando é o terraform init, que basicamente prepara o ambiente de trabalho do Terraform para que possamos começar a criar, modificar e gerenciar a infraestrutura.**

```
terraform init
```

**Em seguida, o terraform plan examina sua configuração do Terraform e cria um plano de execução que mostra o que será adicionado, alterado e/ou removido na infraestrutura.**
```
terraform plan
```
**Por fim, o comando principal é o terraform apply. Ele aplica o plano gerado pelo terraform plan, criando, modificando ou excluindo os recursos, de acordo com o que definimos no código Terraform.**
```
terraform apply
```

``O resultado final do terraform apply deve ser esse:``

Apply complete! Resources: 11 added, 0 changed, 0 destroyed.



Outputs:



server-data = [

  {

    "ip_address" = "54.234.230.11"

    "public_dns" = "ec2-54-234-230-11.compute-1.amazonaws.com"

  },

  {

    "ip_address" = "34.235.88.185"

    "public_dns" = "ec2-34-235-88-185.compute-1.amazonaws.com"

  },

  {

    "ip_address" = "107.20.106.203"

    "public_dns" = "ec2-107-20-106-203.compute-1.amazonaws.com"

  },

]

``A criação da infraestrutura foi um sucesso, e nos retornou os endereços IP de cada máquina, o que nos dá acessibilidade para a conexão remota``

## 5. Verificando a conexão SSH com as instâncias

``Para verificar se a conexão SSH está funcionando, utilizamos o comando ssh -i para entrar nas instâncias criadas, precisamos da chave privada que foi criada, e por fim, saber o usuário de cada máquina (por padrão, o usuário é o ubuntu).``

**O output que coletamos acima nos dá a informação que precisamos para fazer a conexão SSH com esse comando:**
```
ssh -i ansible-ssh-key.pem ubuntu@ec2-107-20-106-203.compute-1.amazonaws.com 
```

``Vamos obter sucesso se esse output aparecer: ubuntu@ip-10-0-40-221:~$``

## 6. Configurando o Ansible

``Verificada a conexão com as instâncias criadas, agora podemos partir para o próximo passo: automatizar processos com o Ansible.``

**Para isso, crie um diretório chamado ansible e dois arquivos dentro: hosts e configs.yml, dentro da pasta que contém os arquivos do terraform (por boas práticas):**
```
mkdir ansible && cd ansible && touch hosts configs.yml
```

**Dentro do arquivo hosts, adicione as configurações:**
```
[webservers]
ec2-54-234-230-11.compute-1.amazonaws.com
ec2-34-235-88-185.compute-1.amazonaws.com
ec2-107-20-106-203.compute-1.amazonaws.com
```

``Essas configurações indicam para o ansible as instâncias que ele precisa se conectar (o webservers pode ser trocado por qualquer outro nome que queira).``

**Dentro do arquivo configs.yml adicione as seguintes configurações:**
```
---
- name: test
  hosts: all
  gather_facts: true
  become: true
  handlers:
    - name: restart_sshd
      service:
        name: sshd
        state: restarted
  tasks:
    - name: atualizar o cache de pacotes
      apt:
        update_cache: yes
    - name: install
      package:
        state: latest
        name:
          - bash-completion
          - vim
          - nano
          - nginx
          - curl
          - htop
    - name: Run Grafana installation script
      script: /home/myhome/ubuntu_jammy/grafana.sh
```

``Esse arquivo dirá para o ansible executar as tasks descritas, em todos os hosts solicitados. A última task é um script que instala o grafana, salve no seu diretório home:``

```
#grafana.sh
#!/bin/bash

sudo apt-get install -y software-properties-common wget

sudo wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key

echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list

echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com beta main" | sudo tee -a /etc/apt/sources.list.d/grafana.list

sudo apt update -y

sudo apt install grafana -y
```

**Por fim, execute o ansible-playbook:**
```
ansible-playbook -i hosts configs.yml
```

``debug:``

```
PLAY [test] ************************************************************************************************************************************************************************************************

TASK [Gathering Facts] *************************************************************************************************************************************************************************************

ok: [ec2-54-234-230-11.compute-1.amazonaws.com]

ok: [ec2-34-235-88-185.compute-1.amazonaws.com]

ok: [ec2-107-20-106-203.compute-1.amazonaws.com]

TASK [atualizar o cache de pacotes] ************************************************************************************************************************************************************************

changed: [ec2-54-234-230-11.compute-1.amazonaws.com]

changed: [ec2-34-235-88-185.compute-1.amazonaws.com]

changed: [ec2-107-20-106-203.compute-1.amazonaws.com]

TASK [install] *********************************************************************************************************************************************************************************************

changed: [ec2-54-234-230-11.compute-1.amazonaws.com]

changed: [ec2-34-235-88-185.compute-1.amazonaws.com]

changed: [ec2-107-20-106-203.compute-1.amazonaws.com]

TASK [Run Grafana installation script] *********************************************************************************************************************************************************************

changed: [ec2-54-234-230-11.compute-1.amazonaws.com]

changed: [ec2-34-235-88-185.compute-1.amazonaws.com]

changed: [ec2-107-20-106-203.compute-1.amazonaws.com]

PLAY RECAP *************************************************************************************************************************************************************************************************

ec2-107-20-106-203.compute-1.amazonaws.com : ok=4    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   

ec2-34-235-88-185.compute-1.amazonaws.com : ok=4    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   

ec2-54-234-230-11.compute-1.amazonaws.com : ok=4    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

**Por fim, podemos entrar nas instâncias para ver o êxito:**
```
ssh -i ansible-ssh-key.pem ubuntu@ec2-107-20-106-203.compute-1.amazonaws.com
```
**Um dos programas instalados foi o nginx, para ver se realmente foi instalado, execute:**
```
sudo systemctl status nginx
```
 ``Alguns dados utilizados precisam ser alterados, para o êxito desse laboratório, não se esqueça.``




