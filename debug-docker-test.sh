#!/bin/bash

# Quick Docker Test Debugging Script
set -e

echo "🔍 Debug Docker Integration Test"
echo "=================================="

# 1. Check if containers are running locally
echo "Checking if Docker containers are available..."
if docker compose -f docker-compose.test.yml ps 2>/dev/null | grep -q "Up"; then
    echo "✅ Containers are running"
    
    # 2. Test network connectivity from host
    echo "Testing network connectivity from host..."
    
    # Try to ping the Java bridge container
    if docker exec rew-java-bridge ping -c 1 192.168.100.11 >/dev/null 2>&1; then
        echo "✅ Java bridge can reach Pi receiver"
    else
        echo "❌ Java bridge cannot reach Pi receiver"
    fi
    
    # 3. Check Pi receiver HTTP endpoints
    echo "Testing Pi receiver HTTP endpoints..."
    if curl -s http://localhost:8081/health | grep -q "healthy"; then
        echo "✅ Pi receiver 1 HTTP endpoint works"
    else
        echo "❌ Pi receiver 1 HTTP endpoint fails"
    fi
    
    # 4. Check if test runner can access services
    echo "Testing from inside test runner container..."
    docker exec rew-test-runner bash -c '
        echo "Testing from inside test runner..."
        ping -c 1 192.168.100.10 && echo "✅ Can ping Java bridge"
        ping -c 1 192.168.100.11 && echo "✅ Can ping Pi receiver 1"
        ping -c 1 192.168.100.12 && echo "✅ Can ping Pi receiver 2"
        curl -s http://192.168.100.11:8080/health && echo "✅ Can access Pi receiver 1 HTTP"
    ' || echo "❌ Test runner container has issues"
    
else
    echo "❌ No containers running. Starting them now..."
    
    # Start containers in background
    docker compose -f docker-compose.test.yml up -d
    
    echo "⏳ Waiting for containers to start..."
    sleep 10
    
    echo "Containers status:"
    docker compose -f docker-compose.test.yml ps
    
    # Check logs
    echo "Java bridge logs:"
    docker logs rew-java-bridge | tail -5
    
    echo "Pi receiver logs:"
    docker logs rew-pi-1 | tail -5
    
    echo "Test runner logs:"
    docker logs rew-test-runner | tail -10
fi

echo "=================================="
echo "💡 To manually run the test runner:"
echo "   docker exec -it rew-test-runner /app/run-integration-tests.sh"
echo
echo "💡 To see live logs:"
echo "   docker compose -f docker-compose.test.yml logs -f"
echo
echo "💡 To stop containers:"
echo "   docker compose -f docker-compose.test.yml down"