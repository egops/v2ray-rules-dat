#!/usr/bin/env bash
# Local build mirroring .github/workflows/run.yml (no release/upload).
# 不用 pipefail：流水线里 `diff` 有差异时返回 1，与 CI 分步执行不同，pipefail 会导致脚本误失败
set -eu
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

export CHINA_DOMAINS_URL="https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/accelerated-domains.china.conf"
export GOOGLE_DOMAINS_URL="https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/google.china.conf"
export APPLE_DOMAINS_URL="https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/apple.china.conf"
export EASYLISTCHINA_EASYLIST_REJECT_URL="https://easylist-downloads.adblockplus.org/easylistchina+easylist.txt"
export PETERLOWE_REJECT_URL="https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=1&mimetype=plaintext"
export ADGUARD_DNS_REJECT_URL="https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt"
export ADGUARD_HOSTLIST_FILTER_1_URL="https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt"
export AWAVENUE_ADS_RULE_URL="https://raw.githubusercontent.com/TG-Twilight/AWAvenue-Ads-Rule/main/AWAvenue-Ads-Rule.txt"
export DANPOLLOCK_REJECT_URL="https://someonewhocares.org/hosts/hosts"
export CUSTOM_DIRECT="https://raw.githubusercontent.com/Loyalsoldier/domain-list-custom/release/cn.txt"
export CUSTOM_PROXY="https://raw.githubusercontent.com/Loyalsoldier/domain-list-custom/release/geolocation-!cn.txt"
export WIN_SPY="https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt"
export WIN_UPDATE="https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/update.txt"
export WIN_EXTRA="https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/extra.txt"

echo "==> geoip"
curl -sSL -o geoip.dat "https://github.com/Loyalsoldier/geoip/raw/release/geoip.dat"
curl -sSL -o geoip.dat.sha256sum "https://github.com/Loyalsoldier/geoip/raw/release/geoip.dat.sha256sum"

echo "==> GFWList"
cd gfwlist2dnsmasq
chmod +x ./gfwlist2dnsmasq.sh
./gfwlist2dnsmasq.sh -l -o ./temp-gfwlist.txt
cd "$ROOT"

echo "==> temp-direct"
curl -sSL "$CHINA_DOMAINS_URL" | perl -ne '/^server=\/([^\/]+)\// && print "$1\n"' > temp-direct.txt
curl -sSL "${CUSTOM_DIRECT}" | perl -ne '/^(domain):([^:]+)(\n$|:@.+)/ && print "$2\n"' >> temp-direct.txt

echo "==> temp-proxy"
cat ./gfwlist2dnsmasq/temp-gfwlist.txt | perl -ne '/^((?=^.{3,255})[a-zA-Z0-9][-_a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-_a-zA-Z0-9]{0,62})+)/ && print "$1\n"' > temp-proxy.txt
curl -sSL "$GOOGLE_DOMAINS_URL" | perl -ne '/^server=\/([^\/]+)\// && print "$1\n"' >> temp-proxy.txt
curl -sSL "$APPLE_DOMAINS_URL" | perl -ne '/^server=\/([^\/]+)\// && print "$1\n"' >> temp-proxy.txt
curl -sSL "${CUSTOM_PROXY}" | grep -Ev ":@cn" | perl -ne '/^(domain):([^:]+)(\n$|:@.+)/ && print "$2\n"' >> temp-proxy.txt

echo "==> temp-reject"
curl -sSL "$EASYLISTCHINA_EASYLIST_REJECT_URL" | perl -ne '/^\|\|([-_0-9a-zA-Z]+(\.[-_0-9a-zA-Z]+){1,64})\^$/ && print "$1\n"' | perl -ne 'print if not /^[0-9]{1,3}(\.[0-9]{1,3}){3}$/' > temp-reject.txt
curl -sSL "$ADGUARD_DNS_REJECT_URL" | perl -ne '/^\|\|([-_0-9a-zA-Z]+(\.[-_0-9a-zA-Z]+){1,64})\^$/ && print "$1\n"' | perl -ne 'print if not /^[0-9]{1,3}(\.[0-9]{1,3}){3}$/' >> temp-reject.txt
curl -sSL "$ADGUARD_HOSTLIST_FILTER_1_URL" | perl -ne '/^\|\|([-_0-9a-zA-Z]+(\.[-_0-9a-zA-Z]+){1,64})\^$/ && print "$1\n"' | perl -ne 'print if not /^[0-9]{1,3}(\.[0-9]{1,3}){3}$/' >> temp-reject.txt
curl -sSL "$AWAVENUE_ADS_RULE_URL" | perl -ne '/^\|\|([-_0-9a-zA-Z]+(\.[-_0-9a-zA-Z]+){1,64})\^$/ && print "$1\n"' | perl -ne 'print if not /^[0-9]{1,3}(\.[0-9]{1,3}){3}$/' >> temp-reject.txt
curl -sSL "$PETERLOWE_REJECT_URL" | perl -ne '/^127\.0\.0\.1\s([-_0-9a-zA-Z]+(\.[-_0-9a-zA-Z]+){1,64})$/ && print "$1\n"' >> temp-reject.txt
curl -sSL "$DANPOLLOCK_REJECT_URL" | perl -ne '/^127\.0\.0\.1\s([-_0-9a-zA-Z]+(\.[-_0-9a-zA-Z]+){1,64})/ && print "$1\n"' | sed '1d' >> temp-reject.txt

echo "==> reserve"
curl -sSL "${CUSTOM_DIRECT}" | perl -ne '/^((full|regexp|keyword):[^:]+)(\n$|:@.+)/ && print "$1\n"' | sort --ignore-case -u > direct-reserve.txt
curl -sSL "${CUSTOM_PROXY}" | grep -Ev ":@cn" | perl -ne '/^((full|regexp|keyword):[^:]+)(\n$|:@.+)/ && print "$1\n"' | sort --ignore-case -u > proxy-reserve.txt

echo "==> merge hidden"
cat proxy.txt >> temp-proxy.txt
cat direct.txt >> temp-direct.txt
cat reject.txt >> temp-reject.txt

echo "==> sort redundant"
cat temp-proxy.txt | sort --ignore-case -u > proxy-list-with-redundant
cat temp-direct.txt | sort --ignore-case -u > direct-list-with-redundant
cat temp-reject.txt | sort --ignore-case -u > reject-list-with-redundant

chmod +x findRedundantDomain.py
./findRedundantDomain.py ./direct-list-with-redundant ./direct-list-deleted-unsort
./findRedundantDomain.py ./proxy-list-with-redundant ./proxy-list-deleted-unsort
./findRedundantDomain.py ./reject-list-with-redundant ./reject-list-deleted-unsort
[ ! -f "direct-list-deleted-unsort" ] && touch direct-list-deleted-unsort
[ ! -f "proxy-list-deleted-unsort" ] && touch proxy-list-deleted-unsort
[ ! -f "reject-list-deleted-unsort" ] && touch reject-list-deleted-unsort
sort ./direct-list-deleted-unsort > ./direct-list-deleted-sort
sort ./proxy-list-deleted-unsort > ./proxy-list-deleted-sort
sort ./reject-list-deleted-unsort > ./reject-list-deleted-sort
diff ./direct-list-deleted-sort ./direct-list-with-redundant | awk '/^>/{print $2}' > ./direct-list-without-redundant
diff ./proxy-list-deleted-sort ./proxy-list-with-redundant | awk '/^>/{print $2}' > ./proxy-list-without-redundant
diff ./reject-list-deleted-sort ./reject-list-with-redundant | awk '/^>/{print $2}' > ./reject-list-without-redundant

echo "==> need-to-remove"
diff ./direct-need-to-remove.txt ./direct-list-without-redundant | awk '/^>/{print $2}' > temp-cn.txt
diff ./proxy-need-to-remove.txt ./proxy-list-without-redundant | awk '/^>/{print $2}' > temp-geolocation-\!cn.txt
diff ./reject-need-to-remove.txt ./reject-list-without-redundant | awk '/^>/{print $2}' > temp-category-ads-all.txt

echo "==> write community/data"
cat temp-cn.txt | sort --ignore-case -u | perl -ne '/^((?=^.{1,255})[a-zA-Z0-9][-_a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-_a-zA-Z0-9]{0,62})*)/ && print "$1\n"' > ./community/data/cn
cat temp-cn.txt | sort --ignore-case -u | perl -ne 'print if not /^((?=^.{3,255})[a-zA-Z0-9][-_a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-_a-zA-Z0-9]{0,62})+)/' > direct-tld-list.txt
cat temp-geolocation-\!cn.txt | sort --ignore-case -u | perl -ne '/^((?=^.{1,255})[a-zA-Z0-9][-_a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-_a-zA-Z0-9]{0,62})*)/ && print "$1\n"' > ./community/data/geolocation-\!cn
cat temp-geolocation-\!cn.txt | sort --ignore-case -u | perl -ne 'print if not /^((?=^.{3,255})[a-zA-Z0-9][-_a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-_a-zA-Z0-9]{0,62})+)/' > proxy-tld-list.txt
cat temp-category-ads-all.txt | sort --ignore-case -u | perl -ne '/^((?=^.{1,255})[a-zA-Z0-9][-_a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-_a-zA-Z0-9]{0,62})*)/ && print "$1\n"' > ./community/data/category-ads-all
cat temp-category-ads-all.txt | sort --ignore-case -u | perl -ne 'print if not /^((?=^.{3,255})[a-zA-Z0-9][-_a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-_a-zA-Z0-9]{0,62})+)/' > reject-tld-list.txt

[ -f "direct-reserve.txt" ] && cat direct-reserve.txt >> ./community/data/cn
[ -f "proxy-reserve.txt" ] && cat proxy-reserve.txt >> ./community/data/geolocation-\!cn
[ -f "reject-reserve.txt" ] && cat reject-reserve.txt >> ./community/data/category-ads-all
cp ./community/data/cn direct-list.txt
cp ./community/data/geolocation-\!cn proxy-list.txt
cp ./community/data/category-ads-all reject-list.txt

echo "==> extra lists"
curl -sSL "$CHINA_DOMAINS_URL" | perl -ne '/^server=\/([^\/]+)\// && print "$1\n"' > ./community/data/china-list
curl -sSL "$CHINA_DOMAINS_URL" | perl -ne '/^server=\/([^\/]+)\// && print "$1\n"' > china-list.txt
curl -sSL "$GOOGLE_DOMAINS_URL" | perl -ne '/^server=\/([^\/]+)\// && print "full:$1\n"' > ./community/data/google-cn
curl -sSL "$GOOGLE_DOMAINS_URL" | perl -ne '/^server=\/([^\/]+)\// && print "full:$1\n"' > google-cn.txt
curl -sSL "$APPLE_DOMAINS_URL" | perl -ne '/^server=\/([^\/]+)\// && print "full:$1\n"' > ./community/data/apple-cn
curl -sSL "$APPLE_DOMAINS_URL" | perl -ne '/^server=\/([^\/]+)\// && print "full:$1\n"' > apple-cn.txt
cat ./gfwlist2dnsmasq/temp-gfwlist.txt | perl -ne '/^((?=^.{3,255})[a-zA-Z0-9][-_a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-_a-zA-Z0-9]{0,62})+)/ && print "$1\n"' >> ./community/data/gfw
cat ./community/data/gfw | sort --ignore-case -u > gfw.txt
cat ./community/data/greatfire | sort --ignore-case -u > greatfire.txt
curl -sSL "$WIN_SPY" | grep "0.0.0.0" | awk '{print $2}' > ./community/data/win-spy
curl -sSL "$WIN_SPY" | grep "0.0.0.0" | awk '{print $2}' > win-spy.txt
curl -sSL "$WIN_UPDATE" | grep "0.0.0.0" | awk '{print $2}' > ./community/data/win-update
curl -sSL "$WIN_UPDATE" | grep "0.0.0.0" | awk '{print $2}' > win-update.txt
curl -sSL "$WIN_EXTRA" | grep "0.0.0.0" | awk '{print $2}' > ./community/data/win-extra
curl -sSL "$WIN_EXTRA" | grep "0.0.0.0" | awk '{print $2}' > win-extra.txt

echo "==> go build geosite"
cd custom && go run ./ --datapath=../community/data
cd "$ROOT"

echo "==> publish dir"
rm -rf publish
mkdir -p publish
install -m 644 ./geoip.dat ./publish/geoip.dat
install -m 644 ./geoip.dat.sha256sum ./publish/geoip.dat.sha256sum
install -m 644 ./custom/publish/geosite.dat ./publish/geosite.dat
install -m 644 proxy-tld-list.txt direct-tld-list.txt reject-tld-list.txt proxy-list.txt direct-list.txt reject-list.txt ./publish/
install -m 644 china-list.txt apple-cn.txt google-cn.txt gfw.txt greatfire.txt win-spy.txt win-update.txt win-extra.txt ./publish/

echo "==> DONE"
ls -lh ./publish/geosite.dat ./publish/geoip.dat
shasum -a 256 ./publish/geosite.dat ./publish/geoip.dat
