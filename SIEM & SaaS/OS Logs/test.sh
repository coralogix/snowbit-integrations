os_release_file="/etc/os-release"
os_id=$(cat "$os_release_file" | grep -E "^ID=" | awk -F'=' '{print $2}'| tr -d '"')

if [ "$os_id" = "ubuntu" ]; then
  os_codename=$(lsb_release -sc)
  echo "ubuntu - $os_codename"

elif [ "$os_id" = "rhel" ]; then
  echo "red hat"

elif [ "$os_id" = "amzn" ]; then
  amzn_version=$(cat "$os_release_file" | grep -E "^VERSION_ID=" | awk -F'=' '{print $2}' | tr -d '"')
  echo "amazon - version $amzn_version"
fi