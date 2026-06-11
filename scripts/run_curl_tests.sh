#!/bin/bash
export PATH="/mingw64/bin:$PATH"

urls=(
    "https://badalpn-ng.test.defo.ie/echstat.php?format=json"
    "https://noaddr-ng.test.defo.ie/echstat.php?format=json"
    "https://v3-ng.test.defo.ie:15443/echstat.php?format=json"
    "https://many-ng.test.defo.ie/echstat.php?format=json"
    "https://curves2-ng.test.defo.ie/echstat.php?format=json"
    "https://v4-ng.test.defo.ie/echstat.php?format=json"
    "https://bv-ng.test.defo.ie/echstat.php?format=json"
    "https://v4-ng.test.defo.ie:15443/echstat.php?format=json"
    "https://min-ng.test.defo.ie:15443/echstat.php?format=json"
    "https://bk2-ng.test.defo.ie/echstat.php?format=json"
    "https://pthen2-ng.test.defo.ie:15443/echstat.php?format=json"
    "https://badalpn-ng.test.defo.ie:15443/echstat.php?format=json"
    "https://longalpn-ng.test.defo.ie/echstat.php?format=json"
    "https://withext-ng.test.defo.ie/echstat.php?format=json"
)

echo "Index,URL,Result" > curl_ech_results.csv

idx=0
for url in "${urls[@]}"; do
    output=$(/mingw64/bin/curl -s --cacert C:/Users/PRAJA/.gemini/antigravity-ide/scratch/cacert.pem --ech hard --doh-url https://cloudflare-dns.com/dns-query "$url" | grep -o '"SSL_ECH_STATUS"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    
    if [ -z "$output" ]; then
        output="failed/timeout"
    fi
    
    echo "$idx,$url,$output" >> curl_ech_results.csv
    echo "Tested $url -> $output"
    ((idx++))
done
