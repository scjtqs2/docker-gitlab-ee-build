#!/bin/bash

# 定义一个数组来保存没有匹配的标签
no_match_tags=()
while read -r latest; do
    HAVE_TAG=false
    for tag in $(git tag); do
        if [ "${latest}" == "${tag}" ]; then
            HAVE_TAG=true
        fi
    done
    if ! ${HAVE_TAG}; then
#        git tag ${latest}
        echo ${latest}
        no_match_tags+=("${latest}")
    fi
done < latest

# LATEST=$(git tag | sort -rV | head -n 1)

# if [ -f ./latest ]; then
#     old= cat ./latest
# else
#     echo $LATEST > latest
#     old=1
# fi

sudo git remote set-url origin  https://scjtqs2:${TOKEN}@github.com/scjtqs2/docker-gitlab-ee-build.git
# 构建缺失的标签镜像（从新到旧；单次运行最多构建 MAX_BUILDS 个，避免超出 job 6 小时上限，
# 剩余缺的版本留给下一次定时任务继续补，直到追平）
MAX_BUILDS=${MAX_BUILDS:-10}
build_count=0
for ((idx=${#no_match_tags[@]}-1; idx>=0; idx--)); do
    LATEST="${no_match_tags[$idx]}"
    if [ "${build_count}" -ge "${MAX_BUILDS}" ]; then
        echo "Reached MAX_BUILDS=${MAX_BUILDS}, deferring remaining versions to next run"
        break
    fi
    echo "Processing tag: ${LATEST}"
    # 预检 deb 是否存在：GitLab 会轮替下架旧 patch 的 deb（404）。
    # 404 则跳过该版本（不打 tag，下轮再查）；其他非 200（如 5xx 网络抖动）保持原行为退出。
    deb_missing=false
    for arch in amd64 arm64; do
        code=$(curl -sIL -o /dev/null -w '%{http_code}' --max-time 30 "https://packages.gitlab.com/gitlab/gitlab-ee/packages/ubuntu/noble/gitlab-ee_${LATEST}_${arch}.deb/download.deb")
        if [ "${code}" = "404" ]; then deb_missing=true; fi
        if [ "${code}" != "200" ] && [ "${code}" != "404" ]; then echo "Unexpected HTTP ${code} for ${LATEST} ${arch}, abort"; exit 1; fi
    done
    if ${deb_missing}; then echo "SKIP ${LATEST}: noble deb 已从 packages.gitlab.com 下架"; continue; fi
    echo ${LATEST} >> version
    echo "PACKAGECLOUD_REPO=gitlab-ee" > RELEASE
    echo "RELEASE_PACKAGE=gitlab-ee" >> RELEASE
    echo "RELEASE_VERSION=${LATEST}" >> RELEASE
    echo "DOWNLOAD_URL_amd64=https://packages.gitlab.com/gitlab/gitlab-ee/packages/ubuntu/noble/gitlab-ee_${LATEST}_amd64.deb/download.deb" >> RELEASE
    echo "DOWNLOAD_URL_arm64=https://packages.gitlab.com/gitlab/gitlab-ee/packages/ubuntu/noble/gitlab-ee_${LATEST}_arm64.deb/download.deb" >> RELEASE
    docker buildx  build --platform  linux/arm64,linux/amd64  -t ${DOCKER_NAME}/gitlab-ee:${LATEST}  -f Dockerfile --push . || exit 1
    rm RELEASE
    sudo git add latest
    sudo git add version
    sudo git config --local user.email ${MAIL}
    sudo git config --local user.name ${MY_NAME}
    sudo git commit -a -m "build version ${LATEST}"
    sudo git tag ${LATEST}
    sudo git push --tags  https://scjtqs2:${TOKEN}@github.com/scjtqs2/docker-gitlab-ee-build.git
    sudo git push origin HEAD:${GITHUB_REF}
    build_count=$((build_count+1))
done

# if  test "$old" != "$LATEST" ; then
#     echo $LATEST > latest
#     git clone https://gitlab.com/gitlab-org/omnibus-gitlab.git
#     cd omnibus-gitlab/docker
#     echo "PACKAGECLOUD_REPO=gitlab-ee" > RELEASE
#     echo "RELEASE_PACKAGE=gitlab-ee" >> RELEASE
#     echo "RELEASE_VERSION=${LATEST}" >> RELEASE
#     echo "DOWNLOAD_URL=https://packages.gitlab.com/gitlab/gitlab-ee/packages/ubuntu/focal/gitlab-ee_${LATEST}_arm64.deb/download.deb" >> RELEASE
#     sed -i 's/\-recommends/\-recommends libatomic1/' Dockerfile
#     docker run --privileged --rm tonistiigi/binfmt --install all
#     docker buildx  build --platform linux/arm64 -t ${DOCKER_NAME}/gitlab-ee-arm64:${LATEST} -f Dockerfile ./
#     cd ../../
#     docker tag ${DOCKER_NAME}/gitlab-ee-arm64:${LATEST} ${DOCKER_NAME}/gitlab-ee-arm64:latest;
#     docker login --username ${DOCKER_NAME} --password ${DOCKER_PASSWORD}
#     docker push -a ${DOCKER_NAME}/gitlab-ee-arm64
#     git add latest
#     git config --local user.email ${MAIL}
#     git config --local user.name ${MY_NAME}
#     git commit -a -m "build version ${LATEST}"
# fi
