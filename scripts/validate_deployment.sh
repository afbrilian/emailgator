#!/bin/bash

# EmailGator Deployment Validation Script
# Validates all required environment variables and service connectivity before deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track validation status
ERRORS=0
WARNINGS=0

echo "🔍 EmailGator Deployment Validation"
echo "===================================="
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to validate environment variable
check_env_var() {
    local var_name=$1
    local var_value=$2
    local required=${3:-true}
    
    if [ -z "$var_value" ]; then
        if [ "$required" = true ]; then
            echo -e "${RED}❌ $var_name is not set (required)${NC}"
            ((ERRORS++))
            return 1
        else
            echo -e "${YELLOW}⚠️  $var_name is not set (optional)${NC}"
            ((WARNINGS++))
            return 0
        fi
    else
        echo -e "${GREEN}✅ $var_name is set${NC}"
        return 0
    fi
}

# Function to check URL accessibility
check_url() {
    local url=$1
    local name=$2
    
    if curl -f -s --max-time 5 "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ $name is accessible ($url)${NC}"
        return 0
    else
        echo -e "${RED}❌ $name is not accessible ($url)${NC}"
        ((ERRORS++))
        return 1
    fi
}

# Function to check Fly.io app status
check_fly_app() {
    local app_name=$1
    
    if ! command_exists fly; then
        echo -e "${YELLOW}⚠️  Fly.io CLI not installed (skipping app check)${NC}"
        ((WARNINGS++))
        return 0
    fi
    
    if fly status --app "$app_name" > /dev/null 2>&1; then
        local status=$(fly status --app "$app_name" --json 2>/dev/null | jq -r '.Status' 2>/dev/null || echo "unknown")
        if [ "$status" = "running" ] || [ "$status" = "started" ]; then
            echo -e "${GREEN}✅ Fly.io app '$app_name' is running${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠️  Fly.io app '$app_name' status: $status${NC}"
            ((WARNINGS++))
            return 0
        fi
    else
        echo -e "${RED}❌ Fly.io app '$app_name' not found or not accessible${NC}"
        ((ERRORS++))
        return 1
    fi
}

echo "📋 Phase 1: Required Tools"
echo "-------------------------"

# Check for required tools
if command_exists terraform; then
    echo -e "${GREEN}✅ Terraform is installed${NC}"
else
    echo -e "${RED}❌ Terraform is not installed${NC}"
    ((ERRORS++))
fi

if command_exists fly; then
    echo -e "${GREEN}✅ Fly.io CLI is installed${NC}"
    FLY_VERSION=$(fly version 2>/dev/null | head -n1 || echo "unknown")
    echo "   Version: $FLY_VERSION"
else
    echo -e "${RED}❌ Fly.io CLI is not installed${NC}"
    ((ERRORS++))
fi

if command_exists curl; then
    echo -e "${GREEN}✅ curl is installed${NC}"
else
    echo -e "${RED}❌ curl is not installed${NC}"
    ((ERRORS++))
fi

echo ""
echo "🔐 Phase 2: Environment Variables"
echo "--------------------------------"

# Check required environment variables
check_env_var "DATABASE_URL" "${DATABASE_URL:-}" true
check_env_var "SECRET_KEY_BASE" "${SECRET_KEY_BASE:-}" true
check_env_var "GOOGLE_CLIENT_ID" "${GOOGLE_CLIENT_ID:-}" true
check_env_var "GOOGLE_CLIENT_SECRET" "${GOOGLE_CLIENT_SECRET:-}" true
check_env_var "OPENAI_API_KEY" "${OPENAI_API_KEY:-}" true
check_env_var "SIDECAR_TOKEN" "${SIDECAR_TOKEN:-}" true
check_env_var "SIDECAR_URL" "${SIDECAR_URL:-}" true
check_env_var "FRONTEND_URL" "${FRONTEND_URL:-}" true
check_env_var "PHX_HOST" "${PHX_HOST:-}" true

# Optional variables
check_env_var "SENTRY_DSN" "${SENTRY_DSN:-}" false

echo ""
echo "🌐 Phase 3: Service Connectivity"
echo "-------------------------------"

# Check if services are accessible
if [ -n "${SIDECAR_URL:-}" ]; then
    check_url "${SIDECAR_URL}/health" "Sidecar Health Endpoint"
fi

if [ -n "${FRONTEND_URL:-}" ]; then
    check_url "${FRONTEND_URL}" "Frontend"
fi

# Check Fly.io apps if CLI is available
if command_exists fly; then
    echo ""
    echo "🚀 Phase 4: Fly.io Apps"
    echo "-----------------------"
    
    check_fly_app "emailgator-api"
    check_fly_app "emailgator-sidecar"
    
    # Check if apps have secrets set
    echo ""
    echo "🔑 Phase 5: Fly.io Secrets"
    echo "-------------------------"
    
    if fly secrets list --app emailgator-api > /dev/null 2>&1; then
        SECRET_COUNT=$(fly secrets list --app emailgator-api 2>/dev/null | wc -l)
        if [ "$SECRET_COUNT" -gt 1 ]; then
            echo -e "${GREEN}✅ Backend API has secrets configured${NC}"
        else
            echo -e "${RED}❌ Backend API has no secrets configured${NC}"
            ((ERRORS++))
        fi
    else
        echo -e "${YELLOW}⚠️  Cannot check backend API secrets${NC}"
        ((WARNINGS++))
    fi
    
    if fly secrets list --app emailgator-sidecar > /dev/null 2>&1; then
        SECRET_COUNT=$(fly secrets list --app emailgator-sidecar 2>/dev/null | wc -l)
        if [ "$SECRET_COUNT" -gt 1 ]; then
            echo -e "${GREEN}✅ Sidecar has secrets configured${NC}"
        else
            echo -e "${RED}❌ Sidecar has no secrets configured${NC}"
            ((ERRORS++))
        fi
    else
        echo -e "${YELLOW}⚠️  Cannot check sidecar secrets${NC}"
        ((WARNINGS++))
    fi
fi

echo ""
echo "🗄️  Phase 6: Database Connection"
echo "-------------------------------"

if [ -n "${DATABASE_URL:-}" ]; then
    # Try to connect to database
    if command_exists psql; then
        if psql "$DATABASE_URL" -c "SELECT 1;" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Database connection successful${NC}"
        else
            echo -e "${RED}❌ Database connection failed${NC}"
            ((ERRORS++))
        fi
    else
        echo -e "${YELLOW}⚠️  psql not installed (skipping database connection test)${NC}"
        ((WARNINGS++))
    fi
else
    echo -e "${RED}❌ DATABASE_URL not set (cannot test connection)${NC}"
    ((ERRORS++))
fi

echo ""
echo "📊 Validation Summary"
echo "===================="
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed! Ready for deployment.${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Validation completed with $WARNINGS warning(s)${NC}"
    echo -e "${GREEN}Proceeding with deployment is recommended, but review warnings above.${NC}"
    exit 0
else
    echo -e "${RED}❌ Validation failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo -e "${RED}Please fix the errors above before deploying.${NC}"
    exit 1
fi

