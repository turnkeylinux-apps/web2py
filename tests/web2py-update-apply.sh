#!/bin/bash
set -Eeuo pipefail

scratch_parent=${WEB2PY_TEST_SCRATCH_ROOT:-/var/lib/turnkey-web2py-test}
install -d -m 0755 "$scratch_parent"
scratch=$(mktemp -d "$scratch_parent/apply.XXXXXXXX")
chmod 0755 "$scratch"

cleanup() {
    find "$scratch" -depth -delete
}
trap cleanup EXIT

git_config=(-c user.name=fixture -c user.email=fixture@example.invalid)

make_submodule() {
    local name=$1
    local work="$scratch/${name}-work"
    local remote="$scratch/${name}.git"

    git init --quiet "$work"
    printf 'initial\n' >"$work/revision"
    git -C "$work" add revision
    git "${git_config[@]}" -C "$work" commit --quiet -m initial
    git -C "$work" rev-parse HEAD >"$scratch/${name}-initial"
    printf 'updated\n' >"$work/revision"
    git -C "$work" add revision
    git "${git_config[@]}" -C "$work" commit --quiet -m updated
    git -C "$work" rev-parse HEAD >"$scratch/${name}-updated"
    git clone --quiet --bare "$work" "$remote"
}

for module in pydal rocket3 yatl; do
    make_submodule "$module"
done

upstream_work="$scratch/web2py-work"
upstream="$scratch/web2py.git"
git init --quiet "$upstream_work"
install -d "$upstream_work/gluon/packages" "$upstream_work/handlers"
printf 'VERSION = "3.3.3"\n' >"$upstream_work/gluon/version.py"
printf 'fixture\n' >"$upstream_work/handlers/wsgihandler.py"
printf '/.turnkey-db\n/wsgihandler.py\n' >"$upstream_work/.gitignore"
for module in pydal rocket3 yatl; do
    git -c protocol.file.allow=always -C "$upstream_work" submodule add \
        --quiet "$scratch/${module}.git" "gluon/packages/$module"
    git -C "$upstream_work/gluon/packages/$module" checkout --quiet \
        "$(<"$scratch/${module}-initial")"
done
git -C "$upstream_work" add .
git "${git_config[@]}" -C "$upstream_work" commit --quiet -m initial
git -C "$upstream_work" tag v3.3.3
initial_commit=$(git -C "$upstream_work" rev-parse HEAD)

printf 'VERSION = "3.3.4"\n' >"$upstream_work/gluon/version.py"
for module in pydal rocket3 yatl; do
    git -C "$upstream_work/gluon/packages/$module" checkout --quiet \
        "$(<"$scratch/${module}-updated")"
done
git -C "$upstream_work" add .
git "${git_config[@]}" -C "$upstream_work" commit --quiet -m updated
git -C "$upstream_work" tag v3.3.4
updated_commit=$(git -C "$upstream_work" rev-parse HEAD)
git clone --quiet --bare "$upstream_work" "$upstream"

safe_remote_env=(
    GIT_CONFIG_COUNT=4
    GIT_CONFIG_KEY_0=safe.directory
    GIT_CONFIG_VALUE_0="$upstream"
    GIT_CONFIG_KEY_1=safe.directory
    GIT_CONFIG_VALUE_1="$scratch/pydal.git"
    GIT_CONFIG_KEY_2=safe.directory
    GIT_CONFIG_VALUE_2="$scratch/rocket3.git"
    GIT_CONFIG_KEY_3=safe.directory
    GIT_CONFIG_VALUE_3="$scratch/yatl.git"
)
webroot="$scratch/installed"
install -d -o www-data -g www-data "$webroot"
runuser -u www-data -- env GIT_ALLOW_PROTOCOL=file "${safe_remote_env[@]}" \
    git clone --quiet --branch v3.3.3 --recurse-submodules \
    "$upstream" "$webroot"
install -o root -g www-data -m 0640 /dev/null "$webroot/.turnkey-db"
source_file="$scratch/source"
cat >"$source_file" <<EOF
version=3.3.3
tag=v3.3.3
commit=$initial_commit
pydal_commit=$(<"$scratch/pydal-initial")
rocket_commit=$(<"$scratch/rocket3-initial")
yatl_commit=$(<"$scratch/yatl-initial")
remote=$upstream
EOF

shim_dir="$scratch/bin"
service_state="$scratch/apache.state"
service_log="$scratch/apache.log"
install -d "$shim_dir"
cat >"$shim_dir/systemctl" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>'$service_log'
case "\$1" in
    stop) printf 'stopped\n' >'$service_state' ;;
    start) printf 'active\n' >'$service_state' ;;
    *) exit 2 ;;
esac
EOF
chmod 0755 "$shim_dir/systemctl"
printf 'active\n' >"$service_state"

updater="$scratch/web2py-update"
sed -e "s|^WEBROOT=.*|WEBROOT=$webroot|" \
    -e "s|^SOURCE=.*|SOURCE=$source_file|" \
    -e "s|^REMOTE=.*|REMOTE=$upstream|" \
    overlay/usr/local/sbin/web2py-update >"$updater"
chmod 0755 "$updater"
env PATH="$shim_dir:$PATH" GIT_ALLOW_PROTOCOL=file "${safe_remote_env[@]}" \
    "$updater" --apply

# shellcheck disable=SC1090
. "$source_file"
test "$version" = 3.3.4
test "$tag" = v3.3.4
test "$commit" = "$updated_commit"
for module in pydal rocket3 yatl; do
    expected=$(<"$scratch/${module}-updated")
    case $module in
        pydal) recorded=$pydal_commit ;;
        rocket3) recorded=$rocket_commit ;;
        yatl) recorded=$yatl_commit ;;
    esac
    test "$recorded" = "$expected"
    test "$(runuser -u www-data -- git -C \
        "$webroot/gluon/packages/$module" rev-parse HEAD)" = "$expected"
    runuser -u www-data -- git -C "$webroot/gluon/packages/$module" \
        diff --quiet
    runuser -u www-data -- git -C "$webroot/gluon/packages/$module" \
        diff --cached --quiet
done
test "$(runuser -u www-data -- git -C "$webroot" rev-parse HEAD)" = \
    "$updated_commit"
runuser -u www-data -- git -C "$webroot" diff --quiet
runuser -u www-data -- git -C "$webroot" diff --cached --quiet
test "$(<"$service_state")" = active
test "$(<"$service_log")" = $'stop apache2.service\nstart apache2.service'
