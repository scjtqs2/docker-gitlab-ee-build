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
# 构建缺失的标签镜像
for LATEST in "${no_match_tags[@]}"; do
    echo "Processing tag: ${LATEST}"
    echo ${LATEST} >> version
    echo "PACKAGECLOUD_REPO=gitlab-ee" > RELEASE
    echo "RELEASE_PACKAGE=gitlab-ee" >> RELEASE
    echo "RELEASE_VERSION=${LATEST}" >> RELEASE
    echo "DOWNLOAD_URL_amd64=https://packages.gitlab.com/gitlab/gitlab-ee/packages/ubuntu/jammy/gitlab-ee_${LATEST}_amd64.deb/download.deb" >> RELEASE
    echo "DOWNLOAD_URL_arm64=https://packages.gitlab.com/gitlab/gitlab-ee/packages/ubuntu/jammy/gitlab-ee_${LATEST}_arm64.deb/download.deb" >> RELEASE
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
