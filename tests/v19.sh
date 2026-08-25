#!/bin/bash
set -Eeuo pipefail
umask 077

result=${TKL_TEST_RESULT:?TKL_TEST_RESULT is required}
app_password=${TKL_TEST_APP_PASS:?TKL_TEST_APP_PASS is required}
db_password=${TKL_TEST_DB_PASS:?TKL_TEST_DB_PASS is required}
webroot=/var/www/web2py
source_file=/usr/local/share/turnkey-web2py/source
cookie=$(mktemp /tmp/web2py-cookie.XXXXXXXX)
page=$(mktemp /tmp/web2py-page.XXXXXXXX)
headers=$(mktemp /tmp/web2py-headers.XXXXXXXX)
update=$(mktemp /tmp/web2py-update.XXXXXXXX)

cleanup() {
    find "$cookie" "$page" "$headers" "$update" -maxdepth 0 -delete
}
trap cleanup EXIT

for unit in apache2.service mariadb.service cron.service; do
    systemctl --quiet is-active "$unit"
    systemctl --quiet is-enabled "$unit"
done
apache2ctl configtest
grep -Fxq 'VERSION_CODENAME=trixie' /etc/os-release
grep -Eq '^turnkey-web2py-19\.0' /etc/turnkey_version

# shellcheck disable=SC1090
. "$source_file"
test "$version" = 3.3.3
test "$tag" = v3.3.3
test "$commit" = a729b848ff6b6471a2792cae8156bf087afc2456
test "$pydal_commit" = b515c362e83006e79f681ff6491e4a4ab8566acb
test "$rocket_commit" = 4154030489ebab15b96d1f90a6f288cf4f64dd23
test "$yatl_commit" = c6983a51909f76c48f4a40c93eea7f485321cd3f
git_safe=(git -c safe.directory="$webroot" -C "$webroot")
test "$("${git_safe[@]}" rev-parse HEAD)" = "$commit"
"${git_safe[@]}" diff --quiet
"${git_safe[@]}" diff --cached --quiet
test "$(git -C "$webroot/gluon/packages/pydal" rev-parse HEAD)" = \
    "$pydal_commit"
test "$(git -C "$webroot/gluon/packages/rocket3" rev-parse HEAD)" = \
    "$rocket_commit"
test "$(git -C "$webroot/gluon/packages/yatl" rev-parse HEAD)" = \
    "$yatl_commit"
runtime_version=$(python3 -c \
    'import sys; sys.path.insert(0, sys.argv[1]); from gluon.version import VERSION; print(VERSION.split("-")[0])' \
    "$webroot")
test "$runtime_version" = "$version"
test "$(stat -c '%U:%G:%a' "$webroot/parameters_443.py")" = \
    'www-data:www-data:640'
test "$(stat -c '%U:%G:%a' "$webroot/.turnkey-db")" = \
    'root:www-data:640'

curl --fail --silent --show-error http://127.0.0.1/ >"$page"
grep -Fq 'You are successfully running web2py' "$page"
curl --insecure --fail --silent --show-error https://127.0.0.1/ >"$page"
grep -Fq 'You are successfully running web2py' "$page"

redirect=$(curl --silent --show-error --output /dev/null --write-out '%{http_code}|%{redirect_url}' \
    http://127.0.0.1/admin)
[[ $redirect == 307\|https://*/admin ]]
curl --insecure --fail --silent --show-error --cookie-jar "$cookie" \
    https://127.0.0.1/admin/default/index >"$page"
grep -Fq 'Login to the Administrative Interface' "$page"
curl --insecure --fail --silent --show-error --location \
    --cookie "$cookie" --cookie-jar "$cookie" \
    --data-urlencode "password=$app_password" \
    --data-urlencode 'send=/admin/default/site' \
    https://127.0.0.1/admin/default/index >"$page"
grep -Fq 'Installed applications' "$page"
grep -Fq 'welcome' "$page"

dal_result=$(runuser -u www-data -- python3 - "$webroot" <<'PY'
import sys

root = sys.argv[1]
sys.path.insert(0, root)
from gluon import DAL

with open(f"{root}/.turnkey-db", encoding="utf-8") as stream:
    uri = stream.read().strip().split("=", 1)[1]
db = DAL(uri, migrate=False)
rows = db.executesql("SELECT message FROM turnkey_status WHERE id = 1")
db.close()
assert rows == [("Database connectivity verified",)]
print(rows[0][0])
PY
)
test "$dal_result" = 'Database connectivity verified'
MYSQL_PWD=$db_password mariadb --user=root --batch --skip-column-names \
    web2py --execute='SELECT message FROM turnkey_status WHERE id = 1' |
    grep -Fxq 'Database connectivity verified'

web2py-update --check >"$update"
latest=$(sed -n 's/^latest=//p' "$update")
candidate=$(sed -n 's/^candidate=//p' "$update")
latest_tag=$(sed -n 's/^tag=//p' "$update")
status=$(sed -n 's/^status=//p' "$update")
[[ $latest =~ ^3\.[0-9]+\.[0-9]+$ ]]
[[ $candidate =~ ^[0-9a-f]{40}$ ]]
test "$latest_tag" = "v$latest"
grep -Fxq 'channel=official-web2py-3.x' "$update"
before=$("${git_safe[@]}" rev-parse HEAD)
apply_plan=$(web2py-update --apply --dry-run)
grep -Fq 'mode=apply-dry-run' <<<"$apply_plan"
grep -Fq "target=$latest" <<<"$apply_plan"
grep -Fq "candidate=$candidate" <<<"$apply_plan"
grep -Fq "tag=$latest_tag" <<<"$apply_plan"
grep -Fq 'verified=official-web2py-tag' <<<"$apply_plan"
test "$("${git_safe[@]}" rev-parse HEAD)" = "$before"
"${git_safe[@]}" diff --quiet

cat >"$result" <<EOF
package_source=official web2py $tag Git tag at $commit with pinned official submodules
installed_version=web2py $runtime_version on Python $(python3 -c 'import platform; print(platform.python_version())')
runtime_checks=normal init; Apache HTTP and HTTPS sample; firstboot administrator login; Web2py DAL and MariaDB readback
updater_command=web2py-update --check; web2py-update --apply --dry-run
updater_result=$status; target=$latest; candidate=$candidate
updater_channel=official supported Web2py 3.x Git tags
integrity_evidence=main commit $commit; pydal $pydal_commit; rocket3 $rocket_commit; yatl $yatl_commit
EOF
