cd data
rm README.md
wget https://raw.githubusercontent.com/justjavac/Google-IPs/master/README.md
grep target README.md | grep -v www | awk -F '"' '{print $2}' > ip_list 
