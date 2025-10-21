#!/bin/bash
# AWS Account Switcher for Wiz Technical Exercise
# This script helps you configure and switch between different AWS accounts/profiles

set -e

echo "=========================================="
echo "AWS Account Configuration Switcher"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_current_account() {
    echo "Current AWS Configuration:"
    echo "-----------------------------------"

    if aws sts get-caller-identity >/dev/null 2>&1; then
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
        REGION=$(aws configure get region || echo "not set")
        PROFILE=${AWS_PROFILE:-default}

        echo "  Account ID: $ACCOUNT_ID"
        echo "  User/Role: $USER_ARN"
        echo "  Region: $REGION"
        echo "  Profile: $PROFILE"
        echo -e "${GREEN}✅ AWS credentials are configured${NC}"
    else
        echo -e "${YELLOW}⚠️  No AWS credentials configured${NC}"
        return 1
    fi
    echo ""
}

list_profiles() {
    echo "Available AWS Profiles:"
    echo "-----------------------------------"

    if [ -f ~/.aws/credentials ]; then
        grep '^\[' ~/.aws/credentials | tr -d '[]' | nl
    else
        echo "  No profiles found in ~/.aws/credentials"
    fi
    echo ""

    if [ -f ~/.aws/config ]; then
        echo "Configured profiles in ~/.aws/config:"
        grep '^\[profile' ~/.aws/config | sed 's/\[profile //' | tr -d ']' | nl
    fi
    echo ""
}

configure_new_profile() {
    echo "Configure New AWS Profile"
    echo "-----------------------------------"
    echo ""

    read -p "Enter profile name (e.g., wiz-exercise): " PROFILE_NAME
    if [ -z "$PROFILE_NAME" ]; then
        echo "Profile name cannot be empty."
        return 1
    fi

    echo ""
    echo "You'll need:"
    echo "  1. AWS Access Key ID"
    echo "  2. AWS Secret Access Key"
    echo "  3. Default region (e.g., us-east-1)"
    echo ""

    aws configure --profile "$PROFILE_NAME"

    echo ""
    echo -e "${GREEN}✅ Profile '$PROFILE_NAME' configured${NC}"
    echo ""
    echo "To use this profile:"
    echo "  export AWS_PROFILE=$PROFILE_NAME"
    echo ""

    read -p "Switch to this profile now? (yes/no): " -r
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        export AWS_PROFILE=$PROFILE_NAME
        echo "export AWS_PROFILE=$PROFILE_NAME" >> .env
        echo -e "${GREEN}✅ Switched to profile: $PROFILE_NAME${NC}"
        show_current_account
    fi
}

switch_profile() {
    list_profiles

    read -p "Enter profile name to switch to: " PROFILE_NAME
    if [ -z "$PROFILE_NAME" ]; then
        echo "Profile name cannot be empty."
        return 1
    fi

    # Test if profile works
    if AWS_PROFILE=$PROFILE_NAME aws sts get-caller-identity >/dev/null 2>&1; then
        export AWS_PROFILE=$PROFILE_NAME

        # Update .env file
        if [ -f .env ]; then
            # Remove old AWS_PROFILE line
            grep -v "^export AWS_PROFILE=" .env > .env.tmp || true
            mv .env.tmp .env
        fi
        echo "export AWS_PROFILE=$PROFILE_NAME" >> .env

        # Update AWS account ID in .env
        NEW_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        if grep -q "^export AWS_ACCOUNT_ID=" .env 2>/dev/null; then
            sed -i "s/^export AWS_ACCOUNT_ID=.*/export AWS_ACCOUNT_ID=${NEW_ACCOUNT_ID}/" .env
        else
            echo "export AWS_ACCOUNT_ID=${NEW_ACCOUNT_ID}" >> .env
        fi

        echo -e "${GREEN}✅ Switched to profile: $PROFILE_NAME${NC}"
        echo ""
        show_current_account

        echo -e "${YELLOW}⚠️  IMPORTANT: Run the following command to apply changes:${NC}"
        echo "  source .env"
        echo ""
        echo "Then reconfigure terraform:"
        echo "  ./scripts/setup-prerequisites.sh"
    else
        echo -e "${YELLOW}❌ Failed to authenticate with profile: $PROFILE_NAME${NC}"
        echo "Please check your credentials."
        return 1
    fi
}

configure_default_credentials() {
    echo "Configure Default AWS Credentials"
    echo "-----------------------------------"
    echo ""
    echo "This will configure the 'default' profile."
    echo ""

    aws configure

    echo ""
    echo -e "${GREEN}✅ Default credentials configured${NC}"
    echo ""
    show_current_account
}

use_iam_role() {
    echo "Assume IAM Role"
    echo "-----------------------------------"
    echo ""

    read -p "Enter Role ARN to assume: " ROLE_ARN
    if [ -z "$ROLE_ARN" ]; then
        echo "Role ARN cannot be empty."
        return 1
    fi

    read -p "Enter session name (default: wiz-exercise-session): " SESSION_NAME
    SESSION_NAME=${SESSION_NAME:-wiz-exercise-session}

    echo ""
    echo "Assuming role: $ROLE_ARN"

    # Assume role and get temporary credentials
    CREDENTIALS=$(aws sts assume-role \
        --role-arn "$ROLE_ARN" \
        --role-session-name "$SESSION_NAME" \
        --query 'Credentials' \
        --output json)

    if [ $? -eq 0 ]; then
        ACCESS_KEY=$(echo $CREDENTIALS | jq -r '.AccessKeyId')
        SECRET_KEY=$(echo $CREDENTIALS | jq -r '.SecretAccessKey')
        SESSION_TOKEN=$(echo $CREDENTIALS | jq -r '.SessionToken')
        EXPIRATION=$(echo $CREDENTIALS | jq -r '.Expiration')

        echo ""
        echo -e "${GREEN}✅ Role assumed successfully${NC}"
        echo "Credentials expire at: $EXPIRATION"
        echo ""
        echo "Export these environment variables:"
        echo ""
        echo "export AWS_ACCESS_KEY_ID=$ACCESS_KEY"
        echo "export AWS_SECRET_ACCESS_KEY=$SECRET_KEY"
        echo "export AWS_SESSION_TOKEN=$SESSION_TOKEN"
        echo ""

        read -p "Apply these credentials now? (yes/no): " -r
        if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            export AWS_ACCESS_KEY_ID=$ACCESS_KEY
            export AWS_SECRET_ACCESS_KEY=$SECRET_KEY
            export AWS_SESSION_TOKEN=$SESSION_TOKEN

            # Update .env file
            cat > .env << EOF
# Temporary credentials from assumed role
export AWS_ACCESS_KEY_ID=$ACCESS_KEY
export AWS_SECRET_ACCESS_KEY=$SECRET_KEY
export AWS_SESSION_TOKEN=$SESSION_TOKEN
# Expires: $EXPIRATION
EOF
            echo -e "${GREEN}✅ Credentials applied and saved to .env${NC}"
            echo ""
            echo "Run: source .env"
            show_current_account
        fi
    else
        echo -e "${YELLOW}❌ Failed to assume role${NC}"
        return 1
    fi
}

# Main menu
while true; do
    echo ""
    echo "=========================================="
    echo "AWS Account Management Menu"
    echo "=========================================="
    echo ""
    echo "1. Show current AWS account"
    echo "2. List available AWS profiles"
    echo "3. Switch to existing profile"
    echo "4. Configure new profile"
    echo "5. Configure default credentials"
    echo "6. Assume IAM role"
    echo "7. Exit"
    echo ""
    read -p "Select an option (1-7): " choice

    case $choice in
        1)
            echo ""
            show_current_account
            ;;
        2)
            echo ""
            list_profiles
            ;;
        3)
            echo ""
            switch_profile
            ;;
        4)
            echo ""
            configure_new_profile
            ;;
        5)
            echo ""
            configure_default_credentials
            ;;
        6)
            echo ""
            use_iam_role
            ;;
        7)
            echo ""
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo ""
            echo "Invalid option. Please select 1-7."
            ;;
    esac
done
