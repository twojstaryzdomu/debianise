#! /usr/bin/env bash
set -euo pipefail

case "${INPUT_DEBUG}" in
yes|true)
  set -x
;;
esac

BUILD_PATH="${INPUT_PATH}"
[ -z "${BUILD_PATH}" ] || cd "${BUILD_PATH}"
BUILD_DEPENDS=""
case "${INPUT_INSTALL_BUILD_DEPENDS}" in
yes|true)
  BUILD_DEPENDS="$(grep -Po '(?<=Build-Depends:).*' debian/control \
    | egrep -o '[a-zA-Z][a-zA-Z0-9+-]+' | tr '\n' ' ')"
;;
esac
BUILD_DEPENDS="${BUILD_DEPENDS} ${INPUT_ADDITIONAL_BUILD_DEPENDS}"
CREATE_CHANGELOG="${INPUT_CREATE_CHANGELOG}"
PACKAGE="${INPUT_PACKAGE}"
PACKAGE="${PACKAGE//_/-}"
VERSION="${INPUT_VERSION}"

[ -z "${INPUT_ADDITIONAL_ARCHIVE}" ] || tar -xzvf "${INPUT_ADDITIONAL_ARCHIVE}"
[ -f debian/control ] || exit 1

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-suggests \
        build-essential debhelper devscripts dh-exec ${BUILD_DEPENDS}

case "${INPUT_INSTALL_BUILD_DEPENDS}" in
yes|true)
  dpkg-checkbuilddeps 2>&1 \
    | sed -E 's| \([^)]+\)||g' \
    | ( grep -Po 'dependencies: \K.*' || true ) \
    | xargs -r apt-get install -y
;;
esac

apt-get clean

case "${CREATE_CHANGELOG}" in
yes|true)
  [ -d debian ] || mkdir debian
  [ ! -f debian/changelog ] || rm debian/changelog

  git config --global --add safe.directory "$(pwd)"

  for ifs in \^ \~ \! \#; do
    git log --format=%b:%B | grep -Fq "${ifs}" || break;
  done

  ver_date_sha=$(git log \
  --format=tformat:%ad${ifs}%h${ifs}%aN${ifs}%aE${ifs}%f${ifs}%-aD${ifs}%D \
  --date=format:%Y%m%d --reverse \
  | while IFS=${ifs} read d s n e m t x; do
    tag=$(grep -Po 'tag: [a-zA-Z]*\K[0-9a-f.]+' <<< "${x}"; :)
    last_tag=${tag:-${last_tag:-0.0}}
    dch_ver=${tag:-${last_tag}~git${d}.${s}}
    if grep -q "(${dch_ver})" debian/changelog 2>/dev/null; then
      continue
    else
      NAME=${n} EMAIL=${e} dch ${first---create --package ${PACKAGE}} \
          ${first+-b} -v ${dch_ver} "${m//-/ }"
      sed -i '1s/UNRELEASED/unstable/g;0,/\(>  \).*/s//\1'"${t}"'/g' debian/changelog
      first=''
      [ -z "${VERSION}" ] || case "${dch_ver}" in
      "${VERSION}")
        echo "${dch_ver}${ifs}${d}${ifs}${s}"
        break
      ;;
      esac
    fi
  done)
  [ -z "${ver_date_sha}" ] || for var_name in DCH_VER GIT_DATE SHORT_SHA; do
    typeset -n v=${var_name}
    v=${ver_date_sha%%${ifs}*}
    ver_date_sha=${ver_date_sha#${v}${ifs}}
  done
;;
esac

DCH_VER="${DCH_VER:-$(head -1 debian/changelog | grep -Po '(?:[a-z-]+\s)\(\K.*(?=\))')}"
GIT_DATE="${GIT_DATE:-$(git log -1 --format=%ad --date=format:%Y%m%d)}"
DEB_RELEASE_NAME="${PACKAGE}_${DCH_VER}"
SHORT_SHA="${SHORT_SHA:-${GITHUB_SHA:0:7}}"
DEB_TAG_NAME="${DCH_VER//\~/.}"

cat debian/changelog

[ ! -f debian/watch ] \
  || sed -Ei 's|(https?://github.com/)\S+|\1'${GITHUB_REPOSITORY}'|g' debian/watch

dpkg-buildpackage -b -rfakeroot -us -uc

DEBS=$(grep -Poz '(?s)(?:\nPackage:\s*\K\N+|\nArchitecture:\K\s\N+\n)' debian/control \
| while read p a; do
  case "${a}" in any) a=${DEB_BUILD_ARCH:-$(dpkg-architecture -q DEB_BUILD_ARCH)};; esac
  deb=${p}_${DCH_VER}_${a}.deb
  echo "p = ${p}; a = ${a}; deb = ${deb}" 1>&2
  [ -f ../${deb} ] && mv ../${deb} . && echo ${BUILD_PATH:+${BUILD_PATH}/}${deb}
done)

[ -n "${INPUT_TAG_NAME}" ] \
  && TAG_NAME="${INPUT_TAG_NAME}" \
  || TAG_NAME="${DEB_TAG_NAME}"

[ -n "${INPUT_RELEASE_NAME}" ] \
  && RELEASE_NAME="${INPUT_RELEASE_NAME}" \
  || RELEASE_NAME="${DEB_RELEASE_NAME}"

echo "files<<__EOF__" >> $GITHUB_OUTPUT
echo "${DEBS}" >> $GITHUB_OUTPUT
echo "__EOF__" >> $GITHUB_OUTPUT
echo "release_name=${RELEASE_NAME}" >> $GITHUB_OUTPUT
echo "tag_name=${TAG_NAME}" >> $GITHUB_OUTPUT
