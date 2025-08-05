#!/bin/bash

kubectl port-forward svc/test-web-service -n test-charts 3000:3000 > /dev/null 2>&1 &

echo "Web sample is now accessible at http://localhost:3000"