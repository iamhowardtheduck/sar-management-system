#!/bin/bash

# SAR Sample Data Loader - Workshop Environment
# This script loads sample SAR data into your Elasticsearch cluster

set -e

# Configuration - Workshop Environment Defaults
ELASTICSEARCH_URL="${ELASTICSEARCH_URL:-http://kubernetes-vm:30920}"
ELASTICSEARCH_USERNAME="${ELASTICSEARCH_USERNAME:-fraud}"
ELASTICSEARCH_PASSWORD="${ELASTICSEARCH_PASSWORD:-hunter}"
ELASTICSEARCH_INDEX="${ELASTICSEARCH_INDEX:-sar-reports}"

echo "=== SAR Sample Data Loader - Workshop Environment ==="
echo "Elasticsearch URL: $ELASTICSEARCH_URL"
echo "Username: $ELASTICSEARCH_USERNAME"
echo "Index: $ELASTICSEARCH_INDEX"

# Check if Elasticsearch is accessible
echo "Checking Elasticsearch connectivity..."
if ! curl -s -u "$ELASTICSEARCH_USERNAME:$ELASTICSEARCH_PASSWORD" "$ELASTICSEARCH_URL/_cluster/health" > /dev/null; then
    echo "Error: Cannot connect to Elasticsearch at $ELASTICSEARCH_URL"
    echo "Please check your connection settings and credentials."
    echo "Current settings:"
    echo "  URL: $ELASTICSEARCH_URL"
    echo "  Username: $ELASTICSEARCH_USERNAME"
    echo "  Password: [hidden]"
    exit 1
fi

echo "✓ Connected to Elasticsearch successfully"

# Check cluster health
cluster_status=$(curl -s -u "$ELASTICSEARCH_USERNAME:$ELASTICSEARCH_PASSWORD" "$ELASTICSEARCH_URL/_cluster/health" | jq -r '.status')
echo "Cluster status: $cluster_status"

# Create index with mapping
echo "Creating index with mapping..."
curl -X PUT "$ELASTICSEARCH_URL/$ELASTICSEARCH_INDEX" \
  -H "Content-Type: application/json" \
  -u "$ELASTICSEARCH_USERNAME:$ELASTICSEARCH_PASSWORD" \
  -d @elasticsearch-mapping.json

if [ $? -eq 0 ]; then
    echo "✓ Index created successfully"
else
    echo "⚠ Index may already exist, continuing..."
fi

# Load sample data
echo "Loading sample SAR data..."

# Read the sample data file and insert each record
cat sample-sar-data.json | jq -c '.[]' | while read -r line; do
    # Generate a unique ID for each document
    doc_id=$(echo "$line" | jq -r '.suspect_last_name // .suspect_entity_name // "unknown"' | tr '[:upper:]' '[:lower:]')_$(date +%s)_$RANDOM
    
    curl -X POST "$ELASTICSEARCH_URL/$ELASTICSEARCH_INDEX/_doc/$doc_id" \
      -H "Content-Type: application/json" \
      -u "$ELASTICSEARCH_USERNAME:$ELASTICSEARCH_PASSWORD" \
      -d "$line" > /dev/null
    
    if [ $? -eq 0 ]; then
        echo "✓ Loaded document: $doc_id"
    else
        echo "✗ Failed to load document: $doc_id"
    fi
done

# Refresh the index to make data immediately searchable
echo "Refreshing index..."
curl -X POST "$ELASTICSEARCH_URL/$ELASTICSEARCH_INDEX/_refresh" \
  -u "$ELASTICSEARCH_USERNAME:$ELASTICSEARCH_PASSWORD" > /dev/null

# Check how many documents were loaded
echo "Verifying data load..."
doc_count=$(curl -s -X GET "$ELASTICSEARCH_URL/$ELASTICSEARCH_INDEX/_count" \
  -u "$ELASTICSEARCH_USERNAME:$ELASTICSEARCH_PASSWORD" | jq -r '.count')

echo ""
echo "=== Data Load Complete ==="
echo "Total documents in index: $doc_count"
echo "Index: $ELASTICSEARCH_INDEX"
echo "Cluster: $ELASTICSEARCH_URL"
echo ""
echo "You can now start your SAR application:"
echo "  cd /workspace/workshop/sar-system"
echo "  npm start"
echo ""
echo "Then access the web interface at: http://localhost:3000"
echo ""
echo "Workshop Environment Configuration:"
echo "  ✓ Elasticsearch URL: $ELASTICSEARCH_URL"
echo "  ✓ Username: $ELASTICSEARCH_USERNAME"
echo "  ✓ Index: $ELASTICSEARCH_INDEX"
