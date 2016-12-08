#!/bin/bash

echo -e "\e[32m*** Running basic check and setup for svn_takeout_script ***\e[0m"

required_gems=(logger uri json fileutils open3 sqlite3)

if [ -f config.json ]; then
  echo "INFO - Config file exists"
else
  echo "INFO - Created working copy of config file"
  cp -v config.json.skel config.json
fi

which ruby1 > /dev/null 2>&1
if [[ $? -eq 0 ]]; then
  echo "OK - Ruby exists in the system"
else
  echo -e "\e[31mPROBLEM - No Ruby interpreter found when calling from the shell\e[0m"
  exit 1
fi

for t in "${required_gems[@]}"; do
  ruby -W0 -r "$t" -e' ' > /dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    echo "OK - Ruby gem ${t} is installed (reachable by Ruby interpreter)"
  else
    echo -e "\e[31mPROBLEM - Ruby gem ${t} is NOT found: please try to intall manually by running\e[0m\n\n\t\e[34m$ gem install ${t}\e[0m\n"
  fi
done

