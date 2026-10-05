#!/bin/bash
# One-shot network probe: does any github.com IP answer, and does the API work?
# Hard timeouts everywhere so this can never wedge the terminal session again.
for ip in 140.82.113.3 140.82.114.3 140.82.116.3 140.82.112.3; do
  code=$(curl -s -o /dev/null -w '%{http_code}' -m 8 \
    --resolve "github.com:443:$ip" https://github.com/ 2>/dev/null)
  echo "github $ip -> ${code:-none}"
done
acode=$(curl -s -o /dev/null -w '%{http_code}' -m 8 https://api.github.com/ 2>/dev/null)
echo "api.github.com -> ${acode:-none}"