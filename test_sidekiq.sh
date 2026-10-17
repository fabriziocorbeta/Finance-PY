#!/bin/bash

# Start server in production mode
RAILS_ENV=production SIDEKIQ_WEB_USERNAME=admin SIDEKIQ_WEB_PASSWORD=secret bin/rails s -p 3000 &
SERVER_PID=$!

# Wait for server to start
sleep 5
echo "Testing server at localhost:3000..."

echo "1. Testing old default credentials (should be 401)"
curl -s -o /dev/null -w "%{http_code}" -u sure:sure http://localhost:3000/sidekiq

echo -e "\n2. Testing correct environment credentials (should be 200 or 302)"
curl -s -o /dev/null -w "%{http_code}" -u admin:secret http://localhost:3000/sidekiq

echo -e "\n3. Testing rate limit (15 requests)"
for i in {1..15}; do
  curl -s -o /dev/null -w "%{http_code} " -u admin:wrong http://localhost:3000/sidekiq
done

# Kill server
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null
