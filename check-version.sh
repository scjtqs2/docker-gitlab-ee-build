#!/bin/bash

# 旧数据源 packages.gitlab.com 的搜索页已被 GitLab 下线（HTTP 404，2026 年起）。
# 改用 gitlab.com 上 omnibus-gitlab 仓库的 tags API：正式发布打 <版本>+ee.0 标签，
# rc/pre 等预发布标签名中带 -rc/-pre 等后缀，会被下面的严格正则自然排除。
# 把 + 换成 - 后与本仓库既有 tag 命名一致（如 19.5.3-ee.0）。

rm -f latest

for page in $(seq 1 5); do
    curl -sf --max-time 30 "https://gitlab.com/api/v4/projects/gitlab-org%2Fomnibus-gitlab/repository/tags?per_page=100&page=${page}" \
        | grep -o '"name":"[0-9][^"]*"' \
        | sed 's/.*"name":"//;s/"$//' \
        | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\+ee\.0$' \
        | sed 's/+/-/' >> latest || true
done
sort -uV latest -o latest
