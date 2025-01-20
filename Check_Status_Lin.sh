#!/bin/bash
# For Automation, use: curl -s https://kobigad.com/scripts/Check_Status_Lin.txt | sed 's/\r$//' | bash -s -- [EU-1|US-1|US-2]
# CrowdStrike Sensor Deployment Check Script for Linux
#######################################################################
clear
# Configuration
CLOUD_REGION="US-1"  # Default value, can be overridden by command-line argument
USE_PROXY=false
PROXY_SERVER=""
PROXY_PORT=""
PROXY_USERNAME=""
PROXY_PASSWORD=""

# Function to print colored and underlined title
print_title() {
    echo -e "\n\033[36m$1\033[0m"
    echo -e "\033[36m${1//?/=}\033[0m"
}

# Function to print check result
print_check_result() {
    if [ "$2" = true ]; then
        echo -e "$1: \033[32mOK\033[0m"
    else
        echo -e "$1: \033[31mFAILED\033[0m"
        [ ! -z "$3" ] && echo -e "  \033[31m$3\033[0m"
    fi
}

# Function to check if the sensor is already installed
check_sensor_installation() {
    if ps -e | grep -q falcon-senso; then
        echo "true"
    else
        echo "false"
    fi
}

# Function to get CID
get_cid() {
    cid=$(/opt/CrowdStrike/falconctl -g --cid 2>/dev/null | grep -oP 'cid="\K[^"]+')
    echo "$cid"
}

# Function to get AID
get_aid() {
    aid=$(/opt/CrowdStrike/falconctl -g --aid 2>/dev/null | grep -oP 'aid="\K[^"]+')
    echo "$aid"
}

# Function to check TLS 1.2 support
test_tls12_support() {
    if openssl s_client -tls1_2 -connect example.com:443 </dev/null >/dev/null 2>&1; then
        echo "true"
    else
        echo "false"
    fi
}

# Function to check for required root CA certificates
test_root_ca_certificates() {
    # Initialize an array to hold all CNs
    declare -a CNs
    # Determine the system CA certificates file path
    if [ -f /etc/ssl/certs/ca-certificates.crt ]; then
        CA_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"
    elif [ -f /etc/pki/tls/certs/ca-bundle.crt ]; then
        CA_CERT_FILE="/etc/pki/tls/certs/ca-bundle.crt"
    elif [ -f /etc/ssl/ca-bundle.pem ]; then
        CA_CERT_FILE="/etc/ssl/ca-bundle.pem"
    else
        echo "Error: CA certificates file not found."
        return 1
    fi

    # Split the CA bundle into individual certificate files
    csplit -f cert_ -b "%03d.pem" "$CA_CERT_FILE" '/-----BEGIN CERTIFICATE-----/' '{*}' >/dev/null 2>&1

    # Extract CNs from certificates and store them in the CNs array
    for CERT_FILE in cert_*.pem; do
        CN=$(openssl x509 -in "$CERT_FILE" -noout -subject -nameopt RFC2253 2>/dev/null | sed -n 's/^subject *= *.*CN=\([^,]*\).*$/\1/p')
        if [ -n "$CN" ]; then
            CNs+=("$CN")
        fi
    done

    # Clean up temporary certificate files
    rm cert_*.pem

    # Define required certificates
    required_certs=(
        "DigiCert High Assurance EV Root CA"
        "DigiCert Assured ID Root CA"
    )
    missing_certs=()
    
    # Check for missing certificates
    for cert in "${required_certs[@]}"; do
        if ! printf '%s\n' "${CNs[@]}" | grep -q "^${cert}$"; then
            missing_certs+=("$cert")
        fi
    done
    
    echo "${missing_certs[@]}"
}

# Function to test connectivity and certificate issuer
test_connectivity_and_certificate() {
    local domain="$1"
    local connection_success=false
    local certificate_valid=false
    local issuer=""
    local message=""
    
    if curl -sS --tlsv1.2 "https://$domain" >/dev/null 2>&1; then
        connection_success=true
        message="Connection successful"
        
        issuer=$(openssl s_client -connect "$domain":443 </dev/null 2>/dev/null | openssl x509 -noout -issuer | sed 's/^issuer=//')
        if [[ $issuer == *"CrowdStrike"* ]]; then
            certificate_valid=true
            message+=". Certificate issuer is valid (CrowdStrike)."
        else
            message+=". Certificate issuer is not valid (expected CrowdStrike)."
        fi
    else
        message="Connection failed"
    fi
    
    echo "$connection_success|$certificate_valid|$issuer|$message"
}

# Main script execution
print_title "CrowdStrike Sensor Deployment Check Script for Linux"

# Parse command-line argument for CloudRegion
if [ $# -eq 1 ] && [[ "$1" =~ ^(EU-1|US-1|US-2)$ ]]; then
    CLOUD_REGION="$1"
fi

all_checks_pass=true

# Check if sensor is already installed
sensor_installed=$(check_sensor_installation)
print_check_result "Check if Sensor Installed" $sensor_installed
if [ "$sensor_installed" = true ]; then
    cid=$(get_cid)
    aid=$(get_aid)
    echo "CID: $cid"
    echo "AID: $aid"
else
    all_checks_pass=false
fi

# Check TLS 1.2 support
tls12_supported=$(test_tls12_support)
print_check_result "TLS 1.2 Support" $tls12_supported
[ "$tls12_supported" = false ] && all_checks_pass=false

# Check for required root CA certificates
missing_certs=$(test_root_ca_certificates)
if [ -z "$missing_certs" ]; then
    print_check_result "Required Root CA Certificates" true
else
    print_check_result "Required Root CA Certificates" false "Missing certificates: $missing_certs"
    all_checks_pass=false
fi

# Test connectivity and certificates for region-specific domains
echo -n "Test Connectivity for Cloud Region: "
echo -e "\033[32m$CLOUD_REGION\033[0m"

declare -A region_domains=(
    ["EU-1"]="ts01-lanner-lion.cloudsink.net lfodown01-lanner-lion.cloudsink.net"
    ["US-1"]="ts01-b.cloudsink.net lfodown01-b.cloudsink.net"
    ["US-2"]="ts01-gyr-maverick.cloudsink.net lfodown01-gyr-maverick.cloudsink.net"
)

for domain in ${region_domains[$CLOUD_REGION]}; do
    IFS='|' read -r connection_success certificate_valid issuer message <<< $(test_connectivity_and_certificate "$domain")
    print_check_result "Connection to $domain" $connection_success "$message"
    if [ "$connection_success" = true ]; then
        print_check_result "Certificate for $domain" $certificate_valid "Issuer: $issuer"
    fi
    [ "$connection_success" = false ] || [ "$certificate_valid" = false ] && all_checks_pass=false
done

if [ "$all_checks_pass" = true ]; then
    echo -e "\n\033[32mAll checks passed successfully.\033[0m"
else
    echo -e "\n\033[31mSome checks failed.\033[0m"
fi

print_title "Cloud Sensor Deployment Check Script completed."