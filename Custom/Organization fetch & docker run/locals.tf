locals {
  user-pass = replace(var.PrivateKey, "-", "")
  boto3_install = <<BOTO
sudo apt-get install software-properties-common -y
sudo apt-add-repository universe
sudo apt-get update
sudo apt-get install python3-pip -y
pip3 install boto3
BOTO

  aws = <<AWS
mkdir /root/.aws
echo "[default]" >> /root/.aws/config
echo "region = ${data.aws_region.current.name}" >> /root/.aws/config
AWS

}